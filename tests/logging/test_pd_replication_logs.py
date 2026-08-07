import base64
import subprocess
import time
import unittest
import urllib3

from opensearchpy import OpenSearch

from k8s_utils import K8sUtils

PD_NS = "ping-cloud"
PD_POD = "pingdirectory-0"
PD_POD_1 = "pingdirectory-1"
PD_CONTAINER = "pingdirectory"
PD_LABEL_0 = "statefulset.kubernetes.io/pod-name=pingdirectory-0"
PD_LABEL_1 = "statefulset.kubernetes.io/pod-name=pingdirectory-1"
REPLICATION_LOG = "/opt/pingidentity/server/logs/replication"
OPENSEARCH_NS = "elastic-stack-logging"
OPENSEARCH_SVC = "opensearch-cluster-headless"
OPENSEARCH_PORT = 9200
OPENSEARCH_INDEX = "pd-replication-*"
SAMPLE_SIZE = 20
INGEST_WAIT_SECONDS = 60


def _log(msg):
    print(f"  {msg}", flush=True)


class TestPDReplicationLogs(unittest.TestCase):
    """
    Verifies that PingDirectory replication events are:
      1. Written to the file-based Replication Repair Logger
      2. Routed by Logstash into the pd-replication-* OpenSearch index

    Trigger strategy:
      - Delete pingdirectory-1 pod to generate INFORMATION disconnect/reconnect
        events on pingdirectory-0's replication log
      - Run dsreplication initialize (pd-0 -> pd-1) to generate NOTICE events
    """

    @classmethod
    def setUpClass(cls):
        cls.k8s = K8sUtils()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        _log("Enabling Replication Repair Logger on pd-0...")
        cls.k8s.exec_command(
            PD_NS, PD_POD,
            ["dsconfig", "set-log-publisher-prop",
             "--publisher-name", "Replication Repair Logger",
             "--set", "enabled:true", "--no-prompt"],
            container_name=PD_CONTAINER,
        )

        baseline = cls.k8s.exec_command(
            PD_NS, PD_POD,
            ["sh", "-c", f"wc -l < {REPLICATION_LOG} 2>/dev/null || echo 0"],
            container_name=PD_CONTAINER,
        )
        cls.log_line_before = int(baseline.strip() or 0)
        _log(f"Replication log baseline: {cls.log_line_before} lines")

        _log(f"Deleting {PD_POD_1} to trigger disconnect/reconnect events on {PD_POD}...")
        cls.k8s.kill_pods(label=PD_LABEL_1, namespace=PD_NS)

        _log(f"Waiting for {PD_POD_1} to be ready (timeout 240s)...")
        time.sleep(5)
        ready = cls.k8s.wait_for_all_pods_ready(label=PD_LABEL_1, namespace=PD_NS, timeout_seconds=240)
        _log(f"{PD_POD_1} ready: {ready}")

        pd_0_host = f"pingdirectory-0.pingdirectory.{PD_NS}.svc.cluster.local"
        pd_1_host = f"pingdirectory-1.pingdirectory.{PD_NS}.svc.cluster.local"
        _log(f"Running dsreplication initialize ({PD_POD} -> {PD_POD_1}) for dc=example,dc=com...")
        cls.k8s.exec_command(
            PD_NS, PD_POD,
            [
                "dsreplication", "initialize",
                "--hostSource", pd_0_host, "--portSource", "1636", "--useSSLSource",
                "--hostDestination", pd_1_host, "--portDestination", "1636", "--useSSLDestination",
                "--baseDN", "dc=example,dc=com",
                "--no-prompt",
            ],
            container_name=PD_CONTAINER,
        )

        _log(f"Waiting {INGEST_WAIT_SECONDS}s for Logstash to ingest entries into OpenSearch...")
        time.sleep(INGEST_WAIT_SECONDS)

        cls.new_entries = cls.k8s.exec_command(
            PD_NS, PD_POD,
            ["sh", "-c",
             f"tail -n +{cls.log_line_before + 1} {REPLICATION_LOG} 2>/dev/null"
             f" | grep 'category=REPLICATION'"
             f" | tail -{SAMPLE_SIZE}"],
            container_name=PD_CONTAINER,
        )
        entry_count = len([l for l in cls.new_entries.splitlines() if l.strip()])
        _log(f"New replication file log entries collected: {entry_count}")

        _log("Setting up OpenSearch port-forward and client...")
        cls.port_forward_process = subprocess.Popen(
            ["kubectl", "port-forward", f"service/{OPENSEARCH_SVC}",
             f"{OPENSEARCH_PORT}:{OPENSEARCH_PORT}", "-n", OPENSEARCH_NS],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        time.sleep(5)

        creds_secret = cls.k8s.get_namespaced_secret(
            "opensearch-admin-credentials", OPENSEARCH_NS
        )
        username = base64.b64decode(creds_secret.data["username"]).decode("utf-8")
        password = base64.b64decode(creds_secret.data["password"]).decode("utf-8")

        cls.opensearch_client = OpenSearch(
            hosts=[{"host": "localhost", "port": OPENSEARCH_PORT}],
            http_auth=(username, password),
            use_ssl=True,
            verify_certs=False,
            ssl_show_warn=False,
            timeout=240,
        )
        _log("OpenSearch client ready")

    @classmethod
    def tearDownClass(cls):
        cls.port_forward_process.terminate()
        _log("Restoring Replication Repair Logger to disabled...")
        cls.k8s.exec_command(
            PD_NS, PD_POD,
            ["dsconfig", "set-log-publisher-prop",
             "--publisher-name", "Replication Repair Logger",
             "--set", "enabled:false", "--no-prompt"],
            container_name=PD_CONTAINER,
        )

    def test_replication_entries_written_to_file_log(self):
        """New replication events must appear in the file-based Replication Repair Logger."""
        self.assertGreater(
            len(self.new_entries.strip()),
            0,
            "No new replication entries found in file log after triggering events. "
            "Check that the Replication Repair Logger is enabled.",
        )

    def test_replication_index_exists_in_opensearch(self):
        """The pd-replication-* index must exist in OpenSearch."""
        exists = self.opensearch_client.indices.exists(index=OPENSEARCH_INDEX)
        self.assertTrue(
            exists,
            f"Index {OPENSEARCH_INDEX} does not exist in OpenSearch. "
            "Logstash may not be routing REPLICATION category entries correctly.",
        )

    def test_replication_log_parity_in_opensearch(self):
        """
        Every sampled replication file log entry must have a matching doc in OpenSearch.

        The file-based Replication Repair Logger writes entries in PD's legacy key=value
        format (e.g. msgID=123 category=REPLICATION msg="..."). The Console JSON Error
        Logger writes the same events as JSON to stdout, which Logstash picks up and routes
        to the pd-replication-* index in OpenSearch.

        For each file log entry we extract its msgID — a per-instance monotonic integer
        that PD assigns to every log message and includes in both the file log and the JSON
        stdout. We then query OpenSearch for a document with that same messageID and
        category=REPLICATION. A match confirms the event made it end-to-end from PD stdout
        through Logstash into OpenSearch.

        If msgID is not parseable from a line it is counted as missing, since we have no
        reliable way to correlate it to an OpenSearch document.
        """
        self.assertGreater(
            len(self.new_entries.strip()),
            0,
            "No replication entries to check — file log trigger did not produce entries.",
        )

        missing = []
        checked = 0

        for line in self.new_entries.splitlines():
            line = line.strip()
            if not line:
                continue
            checked += 1

            msg_id = None
            instance_name = None
            for part in line.split():
                if part.startswith("msgID="):
                    msg_id = part.split("=", 1)[1]
                if part.startswith("instanceName="):
                    instance_name = part.split("=", 1)[1].strip('"')

            if msg_id is None:
                missing.append(f"(no msgID parseable) {line}")
                print(f"  [MISSING] FILE : {line}")
                print(f"  [MISSING] OS   : no match found (no msgID in line)")
                print()
                continue

            must_clauses = [
                {"term": {"category.keyword": "REPLICATION"}},
                {"term": {"messageID": int(msg_id)}},
            ]
            if instance_name:
                must_clauses.append({"term": {"instanceName.keyword": instance_name}})

            response = self.opensearch_client.search(
                index=OPENSEARCH_INDEX,
                body={"query": {"bool": {"must": must_clauses}}, "size": 1},
            )

            hits = response["hits"]["hits"]
            if not hits:
                missing.append(f"msgID={msg_id} | {line}")
                print(f"  [MISSING] FILE : {line}")
                print(f"  [MISSING] OS   : no match found for msgID={msg_id} instanceName={instance_name}")
            else:
                src = hits[0]["_source"]
                print(f"  [MATCH] FILE : {line}")
                print(f"  [MATCH] OS   : {src}")
            print()

        _log(f"Parity check: {checked - len(missing)}/{checked} entries found in {OPENSEARCH_INDEX}")
        self.assertEqual(
            missing, [],
            f"Replication parity FAILED — {len(missing)}/{checked} entries not found in "
            f"{OPENSEARCH_INDEX}:\n" + "\n".join(missing),
        )


if __name__ == "__main__":
    unittest.main()
