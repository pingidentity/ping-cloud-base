import json
import os
import unittest

from k8s_utils import K8sUtils


# Required fields and their expected types for each log_name group.
# Derived from the log4j2 JSONLayout config (timestamp/level/loggerName/message
# are emitted by the layout; log_name is the static KeyValuePair injected per appender).
EXPECTED_FIELDS = {
    "timestamp": str,
    "level": str,
    "loggerName": str,
    "message": str,
    "thread": str,
    "threadId": int,
    "threadPriority": int,
    "endOfBatch": bool,
    "loggerFqcn": str,
    "contextMap": dict,
    "instant": dict,
    "log_name": str,
}

VALID_LOG_NAMES = {"application", "application-api"}


def _get_json_log_lines(k8s: K8sUtils, namespace: str, pod_name: str) -> list[str]:
    """Return only JSON object lines from the pingcentral container logs.

    Shell hook lines (e.g. '80-post-start.sh: ...', 'PingCentral running...')
    are plain text — skip anything that does not start with '{'.
    """
    raw_lines = k8s.get_latest_pod_logs(
        pod_name=pod_name,
        container_name="pingcentral",
        pod_namespace=namespace,
        log_lines=200,
    )
    return [line for raw in raw_lines if (line := raw.strip()).startswith("{")]


class TestPingCentralLogJsonFormat(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.k8s = K8sUtils()
        cls.namespace = os.environ.get("PING_CLOUD_NAMESPACE")
        if not cls.namespace:
            raise RuntimeError("PING_CLOUD_NAMESPACE environment variable is not set")

        pod_names = cls.k8s.get_deployment_pod_names("role=pingcentral", cls.namespace)
        if not pod_names:
            raise RuntimeError(f"No pingcentral pods found in namespace {cls.namespace}")

        cls.pod_names = pod_names

        cls.json_log_entries = []
        for pod_name in pod_names:
            for line in _get_json_log_lines(cls.k8s, cls.namespace, pod_name):
                try:
                    cls.json_log_entries.append(json.loads(line))
                except json.JSONDecodeError:
                    pass

        if not cls.json_log_entries:
            raise RuntimeError(
                "No JSON log entries found in pingcentral pod logs. "
                "Ensure the pod has started and produced at least some application logs."
            )

    def test_log_lines_are_valid_json(self):
        """Every line starting with '{' must parse as valid JSON."""
        parse_failures = []
        for pod_name in self.pod_names:
            for line in _get_json_log_lines(self.k8s, self.namespace, pod_name):
                try:
                    json.loads(line)
                except json.JSONDecodeError as e:
                    parse_failures.append(f"{pod_name}: {e} | line: {line[:120]}")

        self.assertEqual(
            parse_failures, [],
            f"Found {len(parse_failures)} log line(s) that are not valid JSON:\n"
            + "\n".join(parse_failures),
        )

    def test_application_log_name_present(self):
        """At least one log entry must have log_name=application."""
        matches = [e for e in self.json_log_entries if e.get("log_name") == "application"]
        self.assertGreater(
            len(matches), 0,
            "No log entries with log_name='application' found.",
        )

    def test_application_api_log_name_present(self):
        """At least one log entry must have log_name=application-api."""
        matches = [e for e in self.json_log_entries if e.get("log_name") == "application-api"]
        self.assertGreater(
            len(matches), 0,
            "No log entries with log_name='application-api' found.",
        )

    def test_no_unexpected_log_names(self):
        """log_name must be one of the two expected console appender values."""
        unexpected = {
            e["log_name"]
            for e in self.json_log_entries
            if "log_name" in e and e["log_name"] not in VALID_LOG_NAMES
        }
        self.assertEqual(
            unexpected, set(),
            f"Unexpected log_name value(s) found: {unexpected}. "
            f"Expected only: {VALID_LOG_NAMES}",
        )

    def test_required_fields_present(self):
        """Every JSON log entry must contain all required fields."""
        missing_report = []
        for entry in self.json_log_entries:
            missing = [f for f in EXPECTED_FIELDS if f not in entry]
            if missing:
                missing_report.append(
                    f"Missing fields {missing} in entry: {json.dumps(entry)[:200]}"
                )

        self.assertEqual(
            missing_report, [],
            f"Found {len(missing_report)} log entries missing required fields:\n"
            + "\n".join(missing_report[:5]),
        )

    def test_field_types(self):
        """Each field in every log entry must have the expected type."""
        errors = []
        for entry in self.json_log_entries:
            for field, expected_type in EXPECTED_FIELDS.items():
                if field not in entry:
                    continue
                value = entry[field]
                if not isinstance(value, expected_type):
                    errors.append(
                        f"Field '{field}': expected {expected_type.__name__}, "
                        f"got {type(value).__name__} (value={value!r}) in entry snippet: "
                        f"{json.dumps(entry)[:120]}"
                    )
            if errors:
                break

        self.assertEqual(
            errors, [],
            "Unexpected field types in log entries:\n" + "\n".join(errors),
        )

    def test_level_is_valid(self):
        """level must be one of the standard log4j2 levels."""
        valid_levels = {"TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"}
        invalid = [
            e for e in self.json_log_entries
            if e.get("level") not in valid_levels
        ]
        self.assertEqual(
            invalid, [],
            f"Found {len(invalid)} entries with unexpected 'level' values: "
            + str({e.get("level") for e in invalid}),
        )


if __name__ == "__main__":
    unittest.main()
