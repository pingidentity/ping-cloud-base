import json
import unittest
import kubernetes as k8s


#HTTPS field logs
EXPECTED_UPSTREAM_FIELDS = {
    "timestamp": str,
    "remote_addr": str,
    "host": str,
    "remote_user": str,
    "request": str,
    "status": int,
    "body_bytes_sent": int,
    "http_referer": str,
    "http_user_agent": str,
    "request_length": str,
    "upstream_addr": str,
    "upstream_response_length": str,
    "upstream_response_time": str,
    "upstream_status": str,
    "req_id": str,
    "request_time": str,
    "proxy_upstream_name": str,
    "proxy_alternative_upstream_name": str,
}


#TCP field logs
EXPECTED_STREAM_FIELDS = {
    "timestamp": str,
    "remote_addr": str,
    "protocol": str,
    "status": int,
    "bytes_sent": int,
    "bytes_received": int,
    "session_time": str,
    "upstream_addr": str,
}

_DEPLOYMENTS = {
    "ingress-nginx-public":  {"namespace": "ingress-nginx-public",  "label": "app.kubernetes.io/name=ingress-nginx-public"},
    "ingress-nginx-private": {"namespace": "ingress-nginx-private", "label": "app.kubernetes.io/name=ingress-nginx-private"},
}
_LOG_LINES = 200


def _get_controller_pods(k8s_client: k8s.client.CoreV1Api, namespace: str, label_selector: str) -> list:
    pods = k8s_client.list_namespaced_pod(
        namespace=namespace,
        label_selector=label_selector,
    )
    return [p.metadata.name for p in pods.items if p.status.phase == "Running"]


def _get_pod_log_lines(k8s_client: k8s.client.CoreV1Api, namespace: str, pod_name: str) -> list[str]:
    resp = k8s_client.read_namespaced_pod_log(
        name=pod_name,
        namespace=namespace,
        container="controller",
        tail_lines=_LOG_LINES,
        _preload_content=False,
    )
    raw = resp.data.decode("utf-8", errors="replace")
    result = []
    for line in raw.splitlines():
        # Skip startup banner, Go klog lines, and nginx error lines
        if not line.startswith("{"):
            continue
        result.append(line)
    return result


def _parse_json_lines(lines: list[str]) -> tuple[list[dict], list[str]]:
    """Return (parsed_entries, failed_lines)."""
    parsed, failed = [], []
    for line in lines:
        try:
            parsed.append(json.loads(line))
        except json.JSONDecodeError:
            failed.append(line)
    return parsed, failed


_UPSTREAM_REQUIRED_KEYS = frozenset({"timestamp", "remote_addr", "host", "request", "status", "body_bytes_sent", "req_id"})
_STREAM_REQUIRED_KEYS   = frozenset({"timestamp", "remote_addr", "protocol", "status", "bytes_sent", "bytes_received", "session_time"})


def _is_upstream_entry(entry: dict) -> bool:
    return _UPSTREAM_REQUIRED_KEYS.issubset(entry)


def _is_stream_entry(entry: dict) -> bool:
    return _STREAM_REQUIRED_KEYS.issubset(entry)


class TestIngressNginxJsonAccessLogs(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        k8s.config.load_kube_config()
        cls.k8s_client = k8s.client.CoreV1Api()

        cls.upstream_entries: list[dict] = []
        cls.stream_entries: list[dict] = []
        cls.failed_lines: list[str] = []
        total_lines = 0

        for _, cfg in _DEPLOYMENTS.items():
            ns = cfg["namespace"]
            for pod_name in _get_controller_pods(cls.k8s_client, ns, cfg["label"]):
                lines = _get_pod_log_lines(cls.k8s_client, ns, pod_name)
                parsed, failed = _parse_json_lines(lines)
                total_lines += len(lines)
                cls.failed_lines.extend(failed)
                for entry in parsed:
                    if _is_upstream_entry(entry):
                        cls.upstream_entries.append(entry)
                    elif _is_stream_entry(entry):
                        cls.stream_entries.append(entry)

        if total_lines == 0:
            raise RuntimeError(
                f"No log lines found for deployments {list(_DEPLOYMENTS.keys())}. "
                "Ensure ingress-nginx is deployed and has received traffic."
            )

        if not cls.upstream_entries and not cls.stream_entries:
            raise RuntimeError(
                "No JSON log entries found in any ingress-nginx controller pod. "
                "Ensure the controller has received traffic (health probes are sufficient)."
            )

    # -------------------------------------------------------------------------
    # All log lines must be valid JSON
    # -------------------------------------------------------------------------

    def test_all_log_lines_are_valid_json(self):
        self.assertEqual(
            self.failed_lines, [],
            "The following log lines could not be parsed as JSON:\n" + "\n".join(self.failed_lines),
        )

    # -------------------------------------------------------------------------
    # log-format-escape-json must be enabled (validated via configmap)
    # -------------------------------------------------------------------------

    def test_log_format_escape_json_enabled_private(self):
        ns = _DEPLOYMENTS["ingress-nginx-private"]["namespace"]
        self._assert_configmap_key(ns, "ingress-nginx", "log-format-escape-json", "true")

    def test_log_format_escape_json_enabled_public(self):
        ns = _DEPLOYMENTS["ingress-nginx-public"]["namespace"]
        self._assert_configmap_key(ns, "ingress-nginx", "log-format-escape-json", "true")


    # -------------------------------------------------------------------------
    # Upstream (HTTP) log format tests
    # -------------------------------------------------------------------------

    def test_upstream_log_contains_expected_fields(self):
        self.assertTrue(self.upstream_entries, "No upstream log entries found — nginx may not have received HTTP traffic")
        entry = self.upstream_entries[0]
        missing = [f for f in EXPECTED_UPSTREAM_FIELDS if f not in entry]
        self.assertEqual(
            missing, [],
            f"Upstream log entry missing expected fields: {missing}\nEntry: {entry}",
        )

    def test_upstream_log_no_extra_top_level_fields(self):
        self.assertTrue(self.upstream_entries, "No upstream log entries found — nginx may not have received HTTP traffic")
        failures = []
        for entry in self.upstream_entries:
            unexpected = [k for k in entry if k not in EXPECTED_UPSTREAM_FIELDS]
            if unexpected:
                failures.append(f"Unexpected fields {unexpected} in: {entry}")
        self.assertEqual(
            failures, [],
            "Upstream log entries contain unexpected top-level fields:\n" + "\n".join(failures),
        )

    def test_upstream_log_field_types(self):
        self.assertTrue(self.upstream_entries, "No upstream log entries found — nginx may not have received HTTP traffic")
        errors = []
        for entry in self.upstream_entries:
            for field, expected_type in EXPECTED_UPSTREAM_FIELDS.items():
                if field not in entry:
                    continue
                value = entry[field]
                if not isinstance(value, expected_type):
                    errors.append(
                        f"Field '{field}': expected {expected_type.__name__}, "
                        f"got {type(value).__name__} (value={value!r})"
                    )
        self.assertEqual(
            errors, [],
            "Unexpected field types in upstream log entries:\n" + "\n".join(errors),
        )

    def test_upstream_status_is_valid_http_code(self):
        for entry in self.upstream_entries:
            status = entry.get("status")
            if status is None:
                continue
            self.assertTrue(
                100 <= status <= 599,
                f"status {status} is not a valid HTTP status code (100-599)",
            )

    def test_upstream_body_bytes_sent_is_non_negative(self):
        for entry in self.upstream_entries:
            value = entry.get("body_bytes_sent")
            if value is None:
                continue
            self.assertGreaterEqual(value, 0, f"body_bytes_sent should be >= 0, got {value}")

    # -------------------------------------------------------------------------
    # Stream (TCP/LDAPS) log format tests
    # -------------------------------------------------------------------------

    def test_stream_log_contains_expected_fields(self):
        self.assertTrue(self.stream_entries, "No stream log entries found — nginx may not have received TCP traffic")
        entry = self.stream_entries[0]
        missing = [f for f in EXPECTED_STREAM_FIELDS if f not in entry]
        self.assertEqual(
            missing, [],
            f"Stream log entry missing expected fields: {missing}\nEntry: {entry}",
        )

    def test_stream_log_no_extra_top_level_fields(self):
        self.assertTrue(self.stream_entries, "No stream log entries found — nginx may not have received TCP traffic")
        failures = []
        for entry in self.stream_entries:
            unexpected = [k for k in entry if k not in EXPECTED_STREAM_FIELDS]
            if unexpected:
                failures.append(f"Unexpected fields {unexpected} in: {entry}")
        self.assertEqual(
            failures, [],
            "Stream log entries contain unexpected top-level fields:\n" + "\n".join(failures),
        )

    def test_stream_log_field_types(self):
        self.assertTrue(self.stream_entries, "No stream log entries found — nginx may not have received TCP traffic")
        errors = []
        for entry in self.stream_entries:
            for field, expected_type in EXPECTED_STREAM_FIELDS.items():
                if field not in entry:
                    continue
                value = entry[field]
                if not isinstance(value, expected_type):
                    errors.append(
                        f"Field '{field}': expected {expected_type.__name__}, "
                        f"got {type(value).__name__} (value={value!r})"
                    )
        self.assertEqual(
            errors, [],
            "Unexpected field types in stream log entries:\n" + "\n".join(errors),
        )

    def test_stream_bytes_sent_is_non_negative(self):
        for entry in self.stream_entries:
            value = entry.get("bytes_sent")
            if value is None:
                continue
            self.assertGreaterEqual(value, 0, f"bytes_sent should be >= 0, got {value}")

    def test_stream_bytes_received_is_non_negative(self):
        for entry in self.stream_entries:
            value = entry.get("bytes_received")
            if value is None:
                continue
            self.assertGreaterEqual(value, 0, f"bytes_received should be >= 0, got {value}")


    def _assert_configmap_key(self, namespace: str, configmap: str, key: str, expected_value: str):
        cm = self.k8s_client.read_namespaced_config_map(name=configmap, namespace=namespace)
        actual = (cm.data or {}).get(key)
        self.assertEqual(
            actual, expected_value,
            f"ConfigMap '{configmap}' key '{key}': expected '{expected_value}', got '{actual}'",
        )


if __name__ == "__main__":
    unittest.main()
