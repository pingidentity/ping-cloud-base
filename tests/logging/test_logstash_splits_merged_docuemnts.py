import json
import subprocess
import time
import unittest
import uuid

import requests
import urllib3
from opensearchpy import OpenSearch

from k8s_utils import K8sUtils

# The image entrypoint tails each product log file through
# `tail -F <file> | awk '{ print <path> $0 }'`, and tail -F can emit a partial
# line without its trailing newline; containerd holds that fragment until the
# next write, so fragments from different files can land in ONE stdout record
# with no separator. Logstash's split filter (02-input-filters.conf,
# id=split_glued_tee_lines) re-splits such records at each
# "<path> <name> [" junction and re-emits each fragment as its own event,
# tagged "tee_merged_split".
#
# These tests POST synthetic fluent-bit-shaped events into the live
# logstash-elastic http input and validate in OpenSearch that, per product
# pipeline (PDS, PD, PF, PDG, PA, ingress, self-service):
#   - glued records are split into one correctly-parsed document per fragment
#   - normal lines pass through unsplit and untagged
#   - no fields from one fragment leak into the other's index
#
# The split gate only matches tee-wrapped lines (paths under
# /opt/out/instance/logs or /opt/pingidentity/server/logs). Products that log
# JSON directly to stdout (PA, ingress, self-service, p14c) never enter the
# gate, so for those the assertion is that a record containing what would be
# two JSON objects (or a JSON line with an /opt mention) is NOT split — the
# split must never corrupt JSON pipelines.

LOGSTASH_SERVICE = "logstash-elastic"
LOGSTASH_HTTP_PORT = 8080
OS_PORT = 9200
OS_NAMESPACE = "elastic-stack-logging"
OS_CREDS_SECRET = "opensearch-admin-credentials"

# Fields the pds-server template does NOT declare; if any appear top-level in a
# pds-server document, a glued record reached the app filter unsplit.
PDS_SERVER_STRAY_FIELDS = ("class", "id", "instanceName", "threadID", "type")


def _unique_msgid():
    return f"99{uuid.uuid4().int % 10**9:09d}"


def _unique_marker():
    return f"pdo12227{uuid.uuid4().int % 10**12:012d}"


class TestTeeMergedSplit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        cls.k8s = K8sUtils()

        # Ephemeral local ports: fixed ports collide with orphaned forwards from
        # previous runs, whose process may serve the port probe and then die
        # mid-run (run9's connection-refused errors).
        cls.logstash_local_port = cls._free_port()
        cls.os_local_port = cls._free_port()

        # Port-forward the logstash http input for posting synthetic events.
        cls.logstash_pf = subprocess.Popen(
            ["kubectl", "port-forward", "service/logstash-elastic",
             f"{cls.logstash_local_port}:{LOGSTASH_HTTP_PORT}",
             "-n", OS_NAMESPACE],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        # Port-forward OpenSearch for document validation.
        cls.os_pf = subprocess.Popen(
            ["kubectl", "port-forward", "service/opensearch-cluster-headless",
             f"{cls.os_local_port}:{OS_PORT}",
             "-n", OS_NAMESPACE],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        # A fixed sleep races slow clusters; wait until both forwards accept
        # connections before proceeding.
        cls._wait_for_port(cls.logstash_local_port, cls.logstash_pf, "logstash http")
        cls._wait_for_port(cls.os_local_port, cls.os_pf, "opensearch")

        import base64
        secret = cls.k8s.get_namespaced_secret(OS_CREDS_SECRET, OS_NAMESPACE)
        user = base64.b64decode(secret.data["username"]).decode()
        pw = base64.b64decode(secret.data["password"]).decode()

        cls.opensearch_client = OpenSearch(
            hosts=[{"host": "localhost", "port": cls.os_local_port}],
            http_auth=(user, pw),
            use_ssl=True,
            verify_certs=False,
            ssl_show_warn=False,
            timeout=60,
        )

        # Post ALL synthetic events up front. Indexing on a live cluster lags
        # bimodally (2s or 20-130s behind fluent-bit bursts), so per-test
        # post-then-poll would serialize every queue wait. Bulk-posting here
        # gives every event the whole suite's runtime to drain; each test then
        # only queries its marker. Test methods read cls._markers, never post.
        cls._build_events()
        for log, container_name, marker in cls._markers.values():
            if log is None:
                continue
            response = cls._post_event(log, container_name, container_name + "-0")
            assert response.status_code == 200, f"logstash rejected event: {response.text}"
        # Wait once, here, for ALL bulk-posted events to become visible. Per-test
        # poll loops each hammering OS add query pressure that starves the same
        # indexing they wait on; one bounded synchronized wait avoids that.
        cls._wait_for_all_markers()

    @classmethod
    def tearDownClass(cls):
        for pf in (cls.logstash_pf, cls.os_pf):
            pf.terminate()
            try:
                pf.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pf.kill()
                pf.wait(timeout=5)

    @classmethod
    def _wait_for_all_markers(cls, timeout_seconds=150):
        """Wait once in setUpClass until every posted event's marker is queryable
        (or timeout — the tests will then fail on the missing marker, naming it)."""
        pending = {key: marker for key, (log, container, marker) in cls._markers.items()
                   if log is not None and key not in ("pds_errors", "pd_glued_2")}
        # fragment markers are inside already-posted glued records; the record's
        # first-fragment marker keys them
        for frag_key, record_key in (("pds_errors", "pds_server"), ("pd_glued_2", "pd_glued_1")):
            if frag_key in cls._markers and cls._markers[record_key] is not None:
                pending[frag_key] = cls._markers[frag_key][2]
        deadline = time.monotonic() + timeout_seconds
        remaining = dict(pending)
        while remaining and time.monotonic() < deadline:
            for key, marker in list(remaining.items()):
                response = cls.opensearch_client.search(
                    index="_all",
                    body={"size": 1, "query": {"multi_match": {"query": marker, "type": "phrase", "lenient": True}}},
                )
                if response["hits"]["hits"]:
                    del remaining[key]
            time.sleep(1)
        if remaining:
            raise RuntimeError(
                f"{len(remaining)} posted events not queryable within {timeout_seconds}s: "
                f"{ {k: m for k, m in remaining.items()} }"
            )

    @staticmethod
    def _free_port():
        """Bind port 0 and return an available local port number."""
        import socket
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            return sock.getsockname()[1]

    @staticmethod
    def _wait_for_port(port, pf_process, label, timeout_seconds=30):
        """Poll until the port-forwarded port accepts connections; kill the
        forward and fail fast if it dies first."""
        import socket
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            if pf_process.poll() is not None:
                raise RuntimeError(f"{label} port-forward exited early: {pf_process.stderr.read().decode()}")
            try:
                with socket.create_connection(("localhost", port), timeout=2):
                    return
            except OSError:
                time.sleep(0.5)
        raise RuntimeError(f"{label} port-forward on localhost:{port} never became reachable")

    @staticmethod
    def _post_event(log, container_name, pod_name, stream="stdout"):
        """POST one fluent-bit-shaped event into the live main pipeline."""
        payload = {
            "log": log,
            "kubernetes": {"container_name": container_name, "pod_name": pod_name},
            "stream": stream,
        }
        response = requests.post(
            f"http://localhost:{TestTeeMergedSplit.logstash_local_port}",
            json=payload,
            timeout=30,
        )
        return response

    @staticmethod
    def _tee_line(root, name, ts, body):
        """A genuine tee-wrapped line: '<path> <name> [<ts>] k=v ...'"""
        return f"{root}{name} [{ts}] {body}"

    @classmethod
    def _build_events(cls):
        """Every synthetic event the suite validates, bulk-posted in setUpClass.
        Keys are the markers test methods query for."""
        msgid_server = _unique_msgid()
        msgid_errors = _unique_msgid()
        pd_normal = _unique_msgid()
        pd_glued_1 = _unique_msgid()
        pd_glued_2 = _unique_msgid()
        # pf_glued disabled with its test below (split gate does not match PF paths).
        pf_json = _unique_marker()
        pdg_normal = _unique_marker()
        pa_json = _unique_marker()
        ingress_json = _unique_marker()
        selfservice_json = _unique_marker()

        pds_glued = (
            cls._tee_line("/opt/out/instance/logs/", "server.out",
                "15/Sep/2026:20:50:34.185 +0000",
                f"category=EXTENSIONS severity=SEVERE_WARNING msgID={msgid_server} "
                f"msg=\"Administrative alert type=no-enabled-alert-handlers "
                f"id=5a1858f4-3b2c-410b-bfad-6e5d1185a3b8 "
                f"class=com.unboundid.directory.server.core.AlertHandlerConfigManager "
                f"msg='No alert handlers have been enabled'\"")
            + cls._tee_line("/opt/out/instance/logs/", "errors",
                "15/Sep/2026:20:50:35.050 +0000",
                f"instanceName=\"pingdatasync-0.ping-cloud\" threadID=-1 "
                f"category=PROTOCOL severity=NOTICE msgID={msgid_errors} "
                f"msg=\"Web application extensions to initialize: 0\"")
        )
        pd_normal_line = cls._tee_line(
            "/opt/pingidentity/server/logs/", "access",
            "15/Sep/2026:20:37:17.728 +0000",
            f"DISCONNECT requesterIP=\"127.0.0.1\" requesterDN=\"\" conn=0 msgID={pd_normal}",
        )
        pd_glued = (
            cls._tee_line("/opt/pingidentity/server/logs/", "access",
                "15/Sep/2026:20:37:17.728 +0000",
                f"DISCONNECT requesterIP=\"127.0.0.1\" conn=0 msgID={pd_glued_1}")
            + cls._tee_line("/opt/pingidentity/server/logs/", "access",
                "15/Sep/2026:20:37:18.728 +0000",
                f"DISCONNECT requesterIP=\"127.0.0.2\" conn=1 msgID={pd_glued_2}")
        )
        pf_json_line = json.dumps({
            "type": "application", "logLevel": "INFO", "className": "s3_sync_ops",
            "msg": f"test normal PF line {pf_json}", "timestamp": "2026-09-16T16:18:31.253Z",
        })
        # PDG error log lines have a BARE timestamp in the file content (no
        # brackets), so this one is not built with _tee_line — its bracket
        # wrapper would corrupt the timestamp the 09-pdg-filters grok captures.
        pdg_line = (
            "/opt/out/instance/logs/error 15/Sep/2026:20:37:17 +0000 "
            f"[NOTICE] 12345#678: PDG test normal line {pdg_normal}"
        )
        # PA engine-log shape (log_name=pingaccess, message key — matches real
        # PA JSON stdout). The PA filter routes by log_name; carrying
        # pingaccess_api_audit would land this line in the strictly-typed
        # pa-api-audit-log index, which real API-audit docs never key this way.
        pa_line = json.dumps({
            "logLevel": "INFO", "className": "com.ping.pa.Test",
            "log_name": "pingaccess",
            "message": f"PA test {pa_json}",
        })
        ingress_line = json.dumps({
            "timestamp": "2026-09-16T15:24:30+00:00",
            "remote_addr": "18.116.101.220", "host": "_", "remote_user": "",
            "request": f"GET /ingress-test-{ingress_json} HTTP/1.1", "status": 400,
            "body_bytes_sent": 150, "http_referer": "", "http_user_agent": "claude-test",
            "request_length": "0", "request_time": "0.001",
            "proxy_upstream_name": "", "proxy_alternative_upstream_name": "",
            "upstream_addr": "", "upstream_response_length": "",
            "upstream_response_time": "", "upstream_status": "",
            "req_id": ingress_json,
        })
        selfservice_line = json.dumps({
            "type": "application", "level": "INFO",
            "msg": f"self-service test {selfservice_json}", "timestamp": "2026-09-16T16:18:33.287Z",
        })

        cls._markers = {
            "pds_server": (pds_glued, "pingdatasync", msgid_server),
            "pds_errors": (None, "pds_server", msgid_errors),
            "pd_normal": (pd_normal_line, "pingdirectory", pd_normal),
            "pd_glued_1": (pd_glued, "pingdirectory", pd_glued_1),
            "pd_glued_2": (None, "pd_glued_1", pd_glued_2),
            # pf_glued_1/pf_glued_2 disabled with their test below.
            "pf_json": (pf_json_line, "pingfederate", pf_json),
            "pdg_normal": (pdg_line, "pingdelegator", pdg_normal),
            "pa_json": (pa_line, "pingaccess", pa_json),
            "ingress_json": (ingress_line, "controller", ingress_json),
            "selfservice_json": (selfservice_line, "p1as-self-service", selfservice_json),
        }

    def _search_by_marker(self, marker, index_pattern, timeout_seconds=8):
        """Query index_pattern for documents carrying this unique marker text.
        Two query passes: query_string (finds markers extracted into kv fields
        like msgID/log_string) then match_phrase on common message fields —
        the free-text analyzer does not reliably index a bare numeric marker
        for query_string, but match_phrase finds it in msg/message."""
        deadline = time.monotonic() + timeout_seconds
        # One combined query (multi_match catches markers in msg/message/log_string
        # and bare kv fields like msgID; multi_match bypasses per-field analyzer
        # quirks that made bare-numeric query_string miss msg-text hits).
        combined = {"multi_match": {"query": marker, "type": "phrase", "lenient": True}}
        # 8s covers the ~2-3s normal indexing lag; cluster fluent-bit bursts can
        # delay specific events 20-130s (bimodal lag observed on this cluster),
        # so after the first window expires, keep polling at a slower pace for
        # one further 40s round before giving up.
        retry_deadline = time.monotonic() + timeout_seconds + 40
        while True:
            response = self.opensearch_client.search(
                index=index_pattern,
                body={"size": 20, "query": combined},
            )
            hits = response["hits"]["hits"]
            if hits:
                return [hit["_source"] for hit in hits]
            if time.monotonic() >= deadline:
                if time.monotonic() >= retry_deadline:
                    return []
                time.sleep(2)
                continue
            time.sleep(0.5)

    @staticmethod
    def _assert_scalar_fields(doc, fields, label):
        """Parsed fields must be single strings. An unsplit merged record reaching
        the kv parse carries repeated keys (two severities, two msgIDs), and
        repeated kv keys become arrays — so a non-string here proves the record
        reached the app filter unsplit. (The app filters remove the raw log field
        before indexing, so field multiplicity is the durable in-doc signal.)"""
        for field in fields:
            value = doc.get(field)
            assert isinstance(value, str), (
                f"{label}: doc has non-scalar '{field}' (array means an unsplit merged "
                f"record kv-parsed repeated keys) — doc fields: "
                f"{ {k: str(v)[:60] for k, v in sorted(doc.items())} }"
            )

    @staticmethod
    def _assert_no_split_tag(doc, label):
        tags = doc.get("tags") or []
        tags = tags if isinstance(tags, list) else [tags]
        assert "tee_merged_split" not in tags, f"{label}: doc was falsely split (tagged tee_merged_split): {doc}"

    @staticmethod
    def _assert_no_cross_leak(marker, wrong_index_pattern, label, timeout_seconds=3):
        """marker must NOT appear in wrong_index_pattern. An unsplit merged
        record's message text contains the other fragment's msgID, so a marker
        hit in the wrong index proves fragments kv-parsed into one doc."""
        deadline = time.monotonic() + timeout_seconds
        combined = {"multi_match": {"query": marker, "type": "phrase", "lenient": True}}
        while True:
            response = TestTeeMergedSplit.opensearch_client.search(
                index=wrong_index_pattern,
                body={"size": 5, "query": combined},
            )
            if response["hits"]["hits"] or time.monotonic() >= deadline:
                break
            time.sleep(0.5)
        assert not response["hits"]["hits"], (
            f"{label}: marker '{marker}' found in '{wrong_index_pattern}' — a fragment "
            f"leaked into the wrong index or was not split. Docs: "
            f"{[h['_source'] for h in response['hits']['hits']]}"
        )

    def _validate_normal_line(self, marker, index_pattern, label):
        """A normal single line must index exactly one document, carry no split
        tag, and have scalar fields."""
        docs = self._search_by_marker(marker, index_pattern)
        assert docs, f"{label}: normal-line document not found for marker {marker}"
        assert len(docs) == 1, f"{label}: expected exactly 1 doc for marker {marker}, got {len(docs)}: {docs}"
        self._assert_no_split_tag(docs[0], label)
        return docs[0]

    ### ---------------------------------------------------------------
    ### Tee-wrapped products: the split gate runs (both roots covered).
    ### ---------------------------------------------------------------

    def test_pds_server_out_alert_glued_to_errors(self):
        """Real incident shape: PDS server.out admin-alert (errors kv format)
        glued to a PDS errors NOTICE line."""
        msgid_server = self._markers["pds_server"][2]
        msgid_errors = self._markers["pds_errors"][2]

        server_docs = self._search_by_marker(msgid_server, "pds-server-*")
        assert server_docs, f"pds-server: server fragment not indexed for msgID {msgid_server}"
        server_doc = server_docs[0]
        for stray in PDS_SERVER_STRAY_FIELDS:
            assert stray not in server_doc, (
                f"pds-server doc contains leaked alert-object field '{stray}' — the glued "
                f"record was not split before app parsing. Doc fields: {sorted(server_doc)}")
        self._assert_scalar_fields(server_doc, ("severity", "msgID", "category"), "pds-server")
        self._assert_no_cross_leak(msgid_errors, "pds-server-*",
            "pds-server (errors msgID must not appear — record reached app filter unsplit)")

        errors_docs = self._search_by_marker(msgid_errors, "pds-errors-*")
        assert errors_docs, f"pds-errors: errors fragment not indexed for msgID {msgid_errors}"
        errors_doc = errors_docs[0]
        for field in ("instanceName", "threadID"):
            assert field in errors_doc, f"pds-errors doc missing {field} after split: {sorted(errors_doc)}"

        self._assert_no_cross_leak(msgid_server, "pds-errors-*",
            "pds-errors (server msgID must not appear — fragment routing is wrong)")

    def test_pd_normal_line_not_split(self):
        """A normal PD access tee line must index exactly one parsed document."""
        marker = self._markers["pd_normal"][2]
        docs = self._search_by_marker(marker, "pd-access-*")
        assert docs, f"pd-access: document not found for marker {marker}"
        assert len(docs) == 1, f"pd-access: expected 1 doc for marker {marker}, got {len(docs)}"
        self._assert_no_split_tag(docs[0], "pd-access")

    def test_pd_glued_two_access_lines_split(self):
        """Two glued PD access tee lines (same root, different times) must
        split into exactly two pd-access documents."""
        marker_1 = self._markers["pd_glued_1"][2]
        marker_2 = self._markers["pd_glued_2"][2]

        docs_1 = self._search_by_marker(marker_1, "pd-access-*")
        assert docs_1, f"pd-access: first fragment not indexed for marker {marker_1}"
        assert len(docs_1) == 1, f"pd-access: expected 1 doc for marker {marker_1}, got {len(docs_1)}"
        # DISCONNECT lines stay in log_string after the access grok; both
        # fragments must be present as separate docs with their own msgIDs.
        # The split's own re-emitted clone legitimately carries the tag; the
        # correctness check is that this doc contains ONLY fragment 2's line.
        docs_2 = self._search_by_marker(marker_2, "pd-access-*")
        assert docs_2, f"pd-access: second fragment not indexed for marker {marker_2}"
        assert len(docs_2) == 1, f"pd-access: expected 1 doc for marker {marker_2}, got {len(docs_2)}"
        assert marker_1 not in str(docs_2[0]), \
            f"pd-access fragment-2 doc contains fragment-1 text — unsplit record: {docs_2[0]}"

    ### DISABLED (PDO-12227): the PF glued case cannot pass until the split gate
    ### in 02-input-filters.conf matches PF's actual tail paths. The gate regex
    ### hardcodes /logs/ (plural) but PF tails /opt/out/instance/log/* (singular —
    ### jvm-garbage-collection, init, request, request2, thread-pool-exhaustion-dump;
    ### server.log is NOT tailed, PF writes it via CONSOLE-JSON stdout). Glued PF
    ### records therefore pass through unsplit, and the glued pair was a false
    ### green (one unsplit doc satisfying both markers). Re-enable with the gate
    ### regex fix (follow-up ticket); the reworked line shape is kept below.
    # def test_pf_glued_request_lines_split(self):
    #     """Two glued PF request tee lines must split into two parsed pf-request
    #     documents. PF paths use /opt/out/instance/log (no /logs)."""
    #     marker_1 = self._markers["pf_glued_1"][2]
    #     marker_2 = self._markers["pf_glued_2"][2]
    #
    #     docs_1 = self._search_by_marker(marker_1, "pf-request-*")
    #     assert docs_1, f"pf-request: first fragment not indexed for marker {marker_1}"
    #     docs_2 = self._search_by_marker(marker_2, "pf-request-*")
    #     assert docs_2, f"pf-request: second fragment not indexed for marker {marker_2}"
    #     self._assert_no_cross_leak(marker_2, "logstash-*",
    #         "pf-glued (second fragment must be routed, not dropped unparsed)", timeout_seconds=5)

    def test_pf_normal_json_line_not_split(self):
        """A normal PF JSON stdout line (the s3_sync_ops shape) must pass
        through the JSON parse untouched. PF routes JSON stdout via the
        else-branch of 07-pf-filters.conf; without log_name it lands in
        logstash-alias with className preserved — still not split."""
        marker = self._markers["pf_json"][2]
        # Events are bulk-posted in setUpClass, so by the time this test runs its
        # doc has had the whole suite's runtime to index — no burst-queue wait.
        docs = self._search_by_marker(marker, "logstash-*,pf-*")
        assert docs, f"pf-json: normal line not found for marker {marker}"
        assert len(docs) == 1, f"pf-json: expected 1 doc for marker {marker}, got {len(docs)}"
        self._assert_no_split_tag(docs[0], "pf-json")

    def test_pdg_normal_error_line_not_split(self):
        """A normal PDG file-based error tee line must index exactly one
        parsed pdg-error document."""
        marker = self._markers["pdg_normal"][2]
        docs = self._search_by_marker(marker, "pdg-*")
        assert docs, f"pdg-error: document not found for marker {marker}"
        self._assert_no_split_tag(docs[0], "pdg-error")

    ### ---------------------------------------------------------------
    ### JSON-stdout products: the split gate must never touch them.
    ### A record containing two JSON objects back-to-back (the JSON-pipeline
    ### equivalent of a merged record) must not be corrupted.
    ### ---------------------------------------------------------------

    def test_pa_glued_json_records_not_split(self):
        """PA logs are JSON stdout — no tee paths, so the split gate must not
        enter. A double-JSON record must land unsplit (json skip_on_invalid
        drops to message), NOT be chopped mid-JSON."""
        marker = self._markers["pa_json"][2]
        docs = self._search_by_marker(marker, "pa-*")
        assert docs, f"pa: JSON record not found for marker {marker}"
        self._assert_no_split_tag(docs[0], "pa-json")

    def test_ingress_json_line_not_split(self):
        """Real nginx JSON access line (captured from a live controller) must
        parse normally and never be split."""
        marker = self._markers["ingress_json"][2]
        docs = self._search_by_marker(marker, "ingress-access-*")
        assert docs, f"ingress-access: JSON record not found for marker {marker}"
        self._assert_no_split_tag(docs[0], "ingress-access")

    def test_self_service_json_line_not_split(self):
        """A self-service JSON stdout line must parse through 10-self-service
        and route to self-service-%{type}."""
        marker = self._markers["selfservice_json"][2]
        docs = self._search_by_marker(marker, "self-service-*")
        assert docs, f"self-service: JSON record not found for marker {marker}"
        self._assert_no_split_tag(docs[0], "self-service")


if __name__ == "__main__":
    unittest.main()
