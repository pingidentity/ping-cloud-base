import json
import os
import re
import unittest

from k8s_utils import K8sUtils


EXPECTED_FIELDS = {
    "timestamp": str,
    "client": str,
    "user": str,
    "method": str,
    "url": str,
    "httpVersion": (int, float),
    "responseCode": str,
    "bodySentBytes": int,
    "referrer": str,
    "userAgent": str,
    "httpForwardedFor": str,
}

# nginx error log format: "2026/05/21 18:00:00 [warn] 1#1: ..."
# These are the only non-JSON lines expected on stdout; everything else must parse as JSON.
_NGINX_ERROR_LOG_RE = re.compile(r"^\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} \[")


def _is_nginx_error_line(line: str) -> bool:
    return bool(_NGINX_ERROR_LOG_RE.match(line))


def _get_access_log_lines(k8s: K8sUtils, namespace: str, pod_name: str) -> list[str]:
    """Return non-blank, non-error-log lines from the pingdelegator container."""
    raw_lines = k8s.get_latest_pod_logs(
        pod_name=pod_name,
        container_name="pingdelegator",
        pod_namespace=namespace,
        log_lines=200,
    )
    return [
        line
        for raw in raw_lines
        if (line := raw.strip()) and not _is_nginx_error_line(line)
    ]


class TestPingDelegatorAccessLogJsonFormat(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.k8s = K8sUtils()
        cls.namespace = os.environ.get("PING_CLOUD_NAMESPACE")
        if not cls.namespace:
            raise RuntimeError("PING_CLOUD_NAMESPACE environment variable is not set")

        pod_names = cls.k8s.get_deployment_pod_names("role=pingdelegator", cls.namespace)
        if not pod_names:
            raise RuntimeError(f"No pingdelegator pods found in namespace {cls.namespace}")

        cls.pod_names = pod_names

        # Parse access log entries from all pods for field/type tests
        cls.json_log_entries = []
        for pod_name in pod_names:
            for line in _get_access_log_lines(cls.k8s, cls.namespace, pod_name):
                try:
                    cls.json_log_entries.append(json.loads(line))
                except json.JSONDecodeError:
                    pass

        if not cls.json_log_entries:
            raise RuntimeError(
                "No JSON access log entries found in pingdelegator pod logs. "
                "Ensure the pod has received at least some traffic (health probes are sufficient)."
            )

    def test_access_log_lines_are_valid_json(self):
        """Every non-blank, non-error-log stdout line must parse as valid JSON."""
        parse_failures = []
        for pod_name in self.pod_names:
            for line in _get_access_log_lines(self.k8s, self.namespace, pod_name):
                try:
                    json.loads(line)
                except json.JSONDecodeError as e:
                    parse_failures.append(f"{pod_name}: {e} | line: {line[:120]}")

        self.assertEqual(
            parse_failures, [],
            f"Found {len(parse_failures)} access log lines that are not valid JSON:\n"
            + "\n".join(parse_failures),
        )

    def test_access_log_contains_expected_fields(self):
        entry = self.json_log_entries[0]
        missing = [field for field in EXPECTED_FIELDS if field not in entry]
        self.assertEqual(
            missing, [],
            f"Access log entry is missing expected fields: {missing}\nEntry: {entry}",
        )

    def test_access_log_field_types(self):
        errors = []
        for entry in self.json_log_entries:
            for field, expected_type in EXPECTED_FIELDS.items():
                if field not in entry:
                    continue
                value = entry[field]
                if not isinstance(value, expected_type):
                    errors.append(
                        f"Field '{field}': expected {expected_type}, got {type(value).__name__} (value={value!r})"
                    )
                    break  # one error per entry is enough
            if errors:
                break

        self.assertEqual(
            errors, [],
            f"Unexpected field types in access log entries:\n" + "\n".join(errors),
        )

    def test_access_log_no_extra_top_level_fields(self):
        extra_fields_found = []
        for entry in self.json_log_entries:
            unexpected = [k for k in entry if k not in EXPECTED_FIELDS]
            if unexpected:
                extra_fields_found.append(f"Unexpected fields {unexpected} in entry: {entry}")
                break

        self.assertEqual(
            extra_fields_found, [],
            "Access log entries contain unexpected top-level fields:\n"
            + "\n".join(extra_fields_found),
        )

    def test_http_version_is_numeric(self):
        for entry in self.json_log_entries:
            if "httpVersion" not in entry:
                continue
            self.assertIsInstance(
                entry["httpVersion"],
                (int, float),
                f"httpVersion should be numeric, got {type(entry['httpVersion']).__name__}: {entry['httpVersion']!r}",
            )

    def test_response_code_is_string(self):
        for entry in self.json_log_entries:
            if "responseCode" not in entry:
                continue
            self.assertIsInstance(
                entry["responseCode"],
                str,
                f"responseCode should be a string, got {type(entry['responseCode']).__name__}: {entry['responseCode']!r}",
            )

    def test_body_sent_bytes_is_integer(self):
        for entry in self.json_log_entries:
            if "bodySentBytes" not in entry:
                continue
            self.assertIsInstance(
                entry["bodySentBytes"],
                int,
                f"bodySentBytes should be an integer, got {type(entry['bodySentBytes']).__name__}: {entry['bodySentBytes']!r}",
            )


if __name__ == "__main__":
    unittest.main()
