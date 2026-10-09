import base64
import subprocess
import time
import unittest
import urllib3
import uuid

from opensearchpy import OpenSearch

from k8s_utils import K8sUtils

OPENSEARCH_NS = "elastic-stack-logging"
OPENSEARCH_SVC = "opensearch-cluster-headless"
OPENSEARCH_PORT = 9200
FAILURES_INDEX = "json-parse-failures-*"
INGEST_WAIT_SECONDS = 90

# Prefix of every payload this suite injects into container stdout, named for
# this suite (test_json_parse_failures.py) rather than a ticket so the probes
# are identifiable in OpenSearch and in any pod's raw stdout. Other tests that
# scrape app stdout (e.g. tests/pingdelegator/test_access_log_json_format.py)
# must ignore lines carrying this prefix: the probes are deliberately
# malformed or non-access-log synthetic entries, not app output.
MARKER_PREFIX = "test-json-parse-failures-probe-"

# One target per Logstash pipeline branch that parses JSON from container
# stdout.
#
#   pdg          09: guard -> json -> ALWAYS pdg-access
#   pf           07: guard -> json -> pf-%{log_name} if log_name present
#   pd           05: guard -> json -> pd-http-detailed-access (http-operation renames logType)
#   pa           04: guard -> json -> pa-pingaccess for log_name pingaccess
#   self-service 10: guard -> json -> self-service-%{type}
#
# Not targetable:
#   pingdatasync has no json filter at all
#   the ingress controller is not injectable
#
# Every target gets the same three payloads: valid JSON (must parse and land
# in the app's service index), malformed JSON (must be tagged _jsonparsefailure
# and diverted to json-parse-failures-* by the output-side tag check), and
# plain text (must not reach the json filter where a guard exists).
TARGETS = [
    {
        "name": "pdg",
        "namespace": "ping-cloud",
        "label": "role=pingdelegator",
        "container": "pingdelegator",
        "index": "pdg-access-",
        "extra_fields": "",
        "guarded": True,
    },
    {
        "name": "pf",
        "namespace": "ping-cloud",
        "label": "role=pingfederate-engine",
        "container": "pingfederate",
        "index": "pf-server-",
        "extra_fields": '"log_name": "server", ',
        "guarded": True,
    },
    {
        "name": "pd",
        "namespace": "ping-cloud",
        "label": "role=pingdirectory",
        "container": "pingdirectory",
        "index": "pd-http-detailed-access-",
        "extra_fields": '"logType": "http-operation", ',
        "guarded": True,
    },
    {
        "name": "pa",
        "namespace": "ping-cloud",
        "label": "role=pingaccess-engine",
        "container": "pingaccess",
        "index": "pa-pingaccess-",
        "extra_fields": '"log_name": "pingaccess", ',
        "guarded": True,
    },
    {
        "name": "self-service",
        "namespace": "ping-cloud",
        "label": "role=p1as-self-service",
        "container": "p1as-self-service",
        "index": "self-service-application-",
        "extra_fields": '"type": "application", ',
        "guarded": True,
    },
]


def _log(msg):
    print(f"  {msg}", flush=True)


class TestJsonParseFailures(unittest.TestCase):
    """
    Verifies the JSON parse-failure handling in the main Logstash
    pipeline, for every app whose pipeline branch parses JSON from stdout:

      1. A valid JSON payload must be parsed and routed to its service index,
         never to json-parse-failures-*
      2. A malformed JSON payload must be tagged _jsonparsefailure and routed
         to json-parse-failures-*
      3. Plain text must not reach the json filter: the format guard rejects
         it before parsing, so it carries no _jsonparsefailure tag
      4. The json-parse-failures index must contain no entries other than the
         malformed payloads this suite intentionally injected

    Trigger strategy:
      kubectl exec cannot inject into the container log stream, but writing to
      /proc/1/fd/1 of the target container lands on real stdout where Fluent
      Bit picks it up.

      For apps whose filter assigns the service index only after a successful
      parse, a malformed payload reaches the output with no index and would
      fall to logstash-alias without exercising the redirect. The output-side
      routing checks the _jsonparsefailure tag BEFORE the else-fallback, so a
      malformed payload is diverted to json-parse-failures-* whether or not a
      filter assigned an index; the pdg target (which assigns pdg-access
      regardless of parse success) proves the redirect holds even then.

    Ordering:
      setUpClass injects all payloads before any test method runs, so the
      false-positive assertion (test 4) filters the suite's own docs out by
      marker rather than by ordering; unittest's alphabetical method order
      ("malformed" < "no_container_logs") is irrelevant.
    """

    marker = f"{MARKER_PREFIX}{uuid.uuid4().hex[:12]}"

    @classmethod
    def setUpClass(cls):
        cls.k8s = K8sUtils()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        cls.targets = {}
        for target in TARGETS:
            pods = cls.k8s.get_deployment_pod_names(target["label"], target["namespace"])
            if not pods:
                raise RuntimeError(
                    f"No pods found in namespace '{target['namespace']}' with "
                    f"label '{target['label']}' for target '{target['name']}'."
                )
            cls.targets[target["name"]] = {"pod": pods[0], **target}
            _log(f"Target {target['name']}: pod {pods[0]}")

        _log(f"Injecting test payloads with marker {cls.marker}...")
        for name, target in cls.targets.items():
            # Per-target marker fragment so each app's docs are uniquely
            # searchable (every target emits a "-valid"/"-malformed" suffix,
            # and a shared fragment would match other targets' docs).
            target["marker"] = f"{cls.marker}-{name}"
            # Valid JSON: must parse and land in the app's service index.
            # Carries the same top-level fields as a real pingdelegator access
            # log entry (per tests/pingdelegator/test_access_log_json_format.py)
            # so stdout-scraping tests see it as indistinguishable from real
            # traffic; only the userAgent marks it as this suite's probe.
            cls._emit(
                name,
                (
                    f'{{"timestamp": "{time.strftime("%Y-%m-%dT%H:%M:%S.000000")}", '
                    f'"client": "127.0.0.1", "user": "-", "method": "GET", "url": "/", '
                    f'"httpVersion": 2.0, "responseCode": "200", "bodySentBytes": 0, '
                    f'"referrer": "-", "userAgent": "{target["marker"]}-valid", '
                    f'"httpForwardedFor": "-"{", " + target["extra_fields"].rstrip(", ") if target["extra_fields"] else ""}}}'
                ),
            )
            # Malformed JSON: starts with '{' (passes the format guard) but is
            # not parseable — must be tagged and routed to json-parse-failures.
            cls._emit(name, f'{{"timestamp": "broken {target["marker"]}-malformed: deliberately unparseable JSON probe from test_json_parse_failures.py')
            # Plain text: no leading brace. Guarded branches must reject it
            # before the json filter runs; unguarded branches parse-fail it.
            cls._emit(name, f"plain text container output {target['marker']}-plaintext")

        _log(f"Waiting {INGEST_WAIT_SECONDS}s for ingestion...")
        time.sleep(INGEST_WAIT_SECONDS)

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
        if getattr(cls, "port_forward_process", None):
            cls.port_forward_process.terminate()

    @classmethod
    def _emit(cls, target_name, line):
        """Write a line to the target container's real stdout (PID 1's fd 1)."""
        target = cls.targets[target_name]
        cls.k8s.exec_command(
            target["namespace"], target["pod"],
            ["sh", "-c", f"echo '{line}' > /proc/1/fd/1"],
            container_name=target["container"],
        )

    def _find_by_marker(self, fragment):
        """Search all indices for docs containing the marker fragment.

        Where the fragment lands depends on how the record was processed:
        the raw 'log' field (guard rejected the line), 'message' (json{}
        parsed a message-bearing line and removed 'log'), or 'userAgent'
        (the access-log-shaped valid payload keeps its marker there).
        Search all three.
        """
        response = self.opensearch_client.search(
            index="*",
            body={
                "query": {
                    "bool": {
                        "should": [
                            {"match_phrase": {"log": fragment}},
                            {"match_phrase": {"message": fragment}},
                            {"match_phrase": {"userAgent": fragment}},
                        ],
                        "minimum_should_match": 1,
                    }
                },
                "size": 50,
                "_source": ["log", "message", "userAgent", "tags"],
            },
        )
        return response["hits"]["hits"]

    def test_no_container_logs_false_positive(self):
        """
        The json-parse-failures index must contain no entries other than, at
        most, the malformed payloads this suite injected.

        In steady state no document should ever land there: valid JSON parses,
        plain text never reaches the json filter (format guard), and no
        container should be emitting malformed JSON. Any doc in the index is a
        parse failure that needs investigation. Docs carrying the suite's
        test-json-parse-failures-probe- marker prefix (any run, including
        interrupted previous runs still inside the window) are the
        intentionally injected payloads and are tolerated; anything else
        fails. Scoped to the last 45 minutes so historical entries don't
        mask fresh ones.
        """
        response = self.opensearch_client.search(
            index=FAILURES_INDEX,
            body={
                "query": {
                    "bool": {
                        "filter": [{"range": {"@timestamp": {
                            "gte": "now-45m",
                        }}}],
                        "must_not": {"match_phrase": {"log": MARKER_PREFIX}},
                    }
                },
                "size": 1000,
                "_source": ["log", "kubernetes.container_name"],
            },
        )
        unexpected = []
        for hit in response["hits"]["hits"]:
            source = hit["_source"]
            container = source.get("kubernetes", {}).get("container_name", "?")
            log_field = (source.get("log") or "").replace("\n", "\\n")[:100]
            unexpected.append(f"[{container}] {log_field!r}")

        self.assertEqual(
            response["hits"]["total"]["value"], 0,
            f"{len(unexpected)} unexpected document(s) in json-parse-failures-*. "
            "Only this suite's injected malformed payload may appear there. "
            "Offenders:\n" + "\n".join(unexpected[:10]),
        )

    def test_valid_json_routes_to_service_index(self):
        """For each app, valid JSON must parse into its service index."""
        for name, target in self.targets.items():
            with self.subTest(app=name):
                hits = self._find_by_marker(f"{target['marker']}-valid")
                self.assertTrue(
                    hits,
                    f"[{name}] Valid JSON payload not found in OpenSearch at "
                    "all — check Fluentbit/Logstash are running.",
                )
                for hit in hits:
                    self.assertFalse(
                        hit["_index"].startswith("json-parse-failures"),
                        f"[{name}] Valid JSON was routed to the failures index "
                        f"(tags={hit['_source'].get('tags')}). Parse should "
                        "have succeeded.",
                    )
                    self.assertTrue(
                        hit["_index"].startswith(target["index"]),
                        f"[{name}] Valid JSON landed in unexpected index "
                        f"'{hit['_index']}'. "
                        f"Tags: {hit['_source'].get('tags')}",
                    )

    def test_malformed_json_lands_in_failures_index(self):
        """For each app, malformed JSON must reach json-parse-failures-*."""
        for name, target in self.targets.items():
            with self.subTest(app=name):
                hits = self._find_by_marker(f"{target['marker']}-malformed")
                self.assertTrue(
                    hits,
                    f"[{name}] Malformed JSON payload not found anywhere in "
                    "OpenSearch — it should be tagged and routed to "
                    "json-parse-failures-*.",
                )
                for hit in hits:
                    self.assertTrue(
                        hit["_index"].startswith("json-parse-failures"),
                        f"[{name}] Malformed JSON landed in '{hit['_index']}' "
                        "instead of json-parse-failures-*. "
                        f"tags={hit['_source'].get('tags')}",
                    )
                    tags = hit["_source"].get("tags") or []
                    self.assertIn(
                        "_jsonparsefailure", tags,
                        f"[{name}] Malformed JSON doc is in the failures index "
                        "but missing the _jsonparsefailure tag.",
                    )

    def test_plain_text_not_tagged(self):
        """
        Plain text must not reach the json filter: the format guard rejects
        it before parsing, so no _jsonparsefailure tag and the raw content
        stays in the log field.
        """
        for name, target in self.targets.items():
            with self.subTest(app=name):
                hits = self._find_by_marker(f"{target['marker']}-plaintext")
                self.assertTrue(
                    hits,
                    f"[{name}] Plain text payload not found in OpenSearch at "
                    "all — check Fluentbit/Logstash are running.",
                )
                for hit in hits:
                    tags = hit["_source"].get("tags") or []
                    self.assertNotIn(
                        "_jsonparsefailure", tags,
                        f"[{name}] Plain text was tagged _jsonparsefailure "
                        f"in '{hit['_index']}' — the format guard should "
                        "have rejected it before the json filter ran.",
                    )
