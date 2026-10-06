import base64
import subprocess
import time
import unittest
import urllib3
from datetime import datetime, timedelta, timezone

from opensearchpy import OpenSearch

from k8s_utils import K8sUtils

PD_NS = "ping-cloud"
PD_POD = "pingdirectory-0"
PD_POD_1 = "pingdirectory-1"
PD_CONTAINER = "pingdirectory"
REPLICATION_LOG = "/opt/pingidentity/server/logs/replication"
OPENSEARCH_NS = "elastic-stack-logging"
OPENSEARCH_SVC = "opensearch-cluster-headless"
OPENSEARCH_PORT = 9200
OPENSEARCH_INDEX = "pd-replication-*"
SAMPLE_SIZE = 20
# Pipeline lag into OpenSearch is commonly 20-130s; poll rather than a single shot.
PARITY_POLL_INTERVAL_SECONDS = 15
PARITY_MAX_ATTEMPTS = 4
# Clock skew allowance when time-boxing parity lookups. Logstash stamps docs with
# @timestamp at parse time, which can trail the PD log line timestamp; the file log
# timestamp and OS app_timestamp are both UTC so a modest skew window suffices.
# Kept small (2 min): a large window lets a CI retry attempt match the previous
# attempt's docs, since PD msgIDs are static per message type.
PARITY_SKEW_MINUTES = 2


def _log(msg):
    print(f"  {msg}", flush=True)


class TestPDReplicationLogs(unittest.TestCase):
    """
    Verifies that PingDirectory replication events are:
      1. Written to the file-based Replication Repair Logger
      2. Routed by Logstash into the pd-replication-* OpenSearch index

    Trigger strategy (no pod restarts — a full restart takes minutes and is the
    slowest, flakiest step in this suite):
      Run the external-initialization cycle on dc=example,dc=com:
        pre-external-initialization -> initialize (pd-0 -> pd-1) -> post-external-initialization
      This runtime-only sequence generates a rich replication event family on pd-0:
        - NOTICE generation-ID reset (error-path) events
        - INFORMATION replica disconnect / "will be reinitialized" events
        - NOTICE export start/complete + reconnect events
        - INFORMATION "replicas have been reinitialized" events
      The cycle must run to completion: between pre- and post-external-initialization
      replication for the domain is suspended.
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

        # Time-box origin for parity lookups. PD message IDs are static per message
        # type (e.g. "Starting export..." always carries the same msgID), so OS docs
        # from previous runs share IDs with this run's events. Every parity lookup
        # must therefore be constrained to docs ingested at/after this test started.
        cls.test_start_utc = datetime.now(timezone.utc) - timedelta(minutes=PARITY_SKEW_MINUTES)
        cls.test_start_str = cls.test_start_utc.strftime("%Y-%m-%dT%H:%M:%S.%fZ")

        pd_0_host = f"pingdirectory-0.pingdirectory.{PD_NS}.svc.cluster.local"
        pd_1_host = f"pingdirectory-1.pingdirectory.{PD_NS}.svc.cluster.local"

        # Use the container's tool properties (localhost:1636) for topology-wide
        # commands — passing --hostname/--port conflicts with the properties file.
        _log("Running dsreplication pre-external-initialization for dc=example,dc=com...")
        output = cls.k8s.exec_command(
            PD_NS, PD_POD,
            ["dsreplication", "pre-external-initialization",
             "--baseDN", "dc=example,dc=com",
             "--no-prompt"],
            container_name=PD_CONTAINER,
        )
        _log(f"dsreplication pre-external-initialization output:\n{output}")
        if "pre-external-initialization.log" not in output:
            raise RuntimeError(
                f"dsreplication pre-external-initialization did not succeed:\n{output}"
            )

        _log(f"Running dsreplication initialize ({PD_POD} -> {PD_POD_1}) for dc=example,dc=com...")
        output = cls.k8s.exec_command(
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
        _log(f"dsreplication initialize output:\n{output}")
        if "initialize.log" not in output:
            raise RuntimeError(f"dsreplication initialize did not succeed:\n{output}")

        _log("Running dsreplication post-external-initialization for dc=example,dc=com...")
        output = cls.k8s.exec_command(
            PD_NS, PD_POD,
            ["dsreplication", "post-external-initialization",
             "--baseDN", "dc=example,dc=com",
             "--no-prompt"],
            container_name=PD_CONTAINER,
        )
        _log(f"dsreplication post-external-initialization output:\n{output}")
        if "post-external-initialization.log" not in output:
            raise RuntimeError(
                f"dsreplication post-external-initialization did not succeed:\n{output}"
            )

        # No flat ingest sleep here: the parity test polls OpenSearch with retries
        # (PARITY_MAX_ATTEMPTS x PARITY_POLL_INTERVAL_SECONDS), which absorbs the
        # pipeline lag without a fixed wait.

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

        For each file log entry we extract its msgID — a per-instance integer that PD
        assigns to every log message and includes in both the file log and the JSON
        stdout. We query OpenSearch for a document with that same messageID and
        category=REPLICATION.

        msgIDs are static per message type, so OpenSearch accumulates documents sharing
        the same messageID across runs (verified: 35+ docs share one ID). A lookup by
        messageID alone would match a stale document and pass even if this run's event
        was never ingested. Every lookup is therefore time-boxed to documents ingested
        at or after this test started (with a small clock-skew allowance).

        If msgID is not parseable from a line it is counted as missing, since we have no
        reliable way to correlate it to an OpenSearch document.
        """
        self.assertGreater(
            len(self.new_entries.strip()),
            0,
            "No replication entries to check — file log trigger did not produce entries.",
        )

        # Parse msgID + instanceName from each sampled file-log line up front.
        # Lines without a parseable msgID are counted as missing immediately —
        # there is no reliable way to correlate them to an OS document.
        checked = 0
        missing = []
        expected = []
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

            if msg_id is None or not msg_id.isdigit() or instance_name is None:
                missing.append(f"(no msgID/instanceName parseable) {line}")
                print(f"  [MISSING] FILE : {line}")
                print(f"  [MISSING] OS   : no match found (no msgID/instanceName in line)")
                print()
                continue

            expected.append((line, int(msg_id), instance_name))

        # Batch lookup: one query fetches every candidate doc for this run's
        # window instead of one query per line, then we match (msgID,
        # instanceName) pairs locally. Both keys matter: msgIDs are static per
        # message TYPE (both replicas emit the same IDs), so matching on msgID
        # alone would let one instance's doc satisfy the other's file line.
        def query_window():
            response = self.opensearch_client.search(
                index=OPENSEARCH_INDEX,
                body={
                    "size": len(expected) * 5,
                    "query": {"bool": {"must": [
                        {"term": {"category.keyword": "REPLICATION"}},
                        {"range": {"app_timestamp": {"gte": self.test_start_str}}},
                    ]}},
                },
            )
            found = {}
            for hit in response["hits"]["hits"]:
                src = hit["_source"]
                found.setdefault((src.get("messageID"), src.get("instanceName")), src)
            return found

        # Poll: pipeline lag is commonly 20-130s (see test_logstash_splits_merged_docuemnts),
        # so re-query up to PARITY_MAX_ATTEMPTS times with PARITY_POLL_INTERVAL_SECONDS
        # between attempts until every expected (msgID, instanceName) pair has a match.
        found = {}
        for attempt in range(1, PARITY_MAX_ATTEMPTS + 1):
            found = query_window()
            still_missing = [(line, msg_id, inst) for (line, msg_id, inst) in expected
                             if (msg_id, inst) not in found]
            if not still_missing:
                break
            _log(f"Parity attempt {attempt}/{PARITY_MAX_ATTEMPTS}: "
                 f"{len(expected) - len(still_missing)}/{len(expected)} msgIDs matched; "
                 f"retrying in {PARITY_POLL_INTERVAL_SECONDS}s...")
            time.sleep(PARITY_POLL_INTERVAL_SECONDS)

        matched_ids = set()
        for line, msg_id, instance_name in expected:
            src = found.get((msg_id, instance_name))
            if src is not None:
                matched_ids.add(msg_id)
                print(f"  [MATCH] FILE : {line}")
                print(f"  [MATCH] OS   : {src}")
            else:
                missing.append(f"msgID={msg_id} | {line}")
                print(f"  [MISSING] FILE : {line}")
                print(f"  [MISSING] OS   : no match found for msgID={msg_id} instanceName={instance_name} after {self.test_start_str}")
            print()

        _log(f"Parity check: {checked - len(missing)}/{checked} entries found in {OPENSEARCH_INDEX}")
        self.assertEqual(
            missing, [],
            f"Replication parity FAILED — {len(missing)}/{checked} entries not found in "
            f"{OPENSEARCH_INDEX}:\n" + "\n".join(missing),
        )


if __name__ == "__main__":
    unittest.main()
