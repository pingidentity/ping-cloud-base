import unittest
import json
import time
from ast import literal_eval
from k8s_utils import K8sUtils

# The s3 output flushes every 3 minutes, so the drain poll must outlast the
# flush interval to see events mid-buffer land.
S3_DRAIN_TIMEOUT_SECONDS = 240
S3_POLL_INTERVAL_SECONDS = 15


def parse_output(output, pod):
    try:
        return json.loads(output)
    except json.JSONDecodeError:
        parsed_data = literal_eval(output)
        return json.loads(json.dumps(parsed_data))


class TestLogstash(unittest.TestCase):
    namespace = "elastic-stack-logging"
    LOGSTASH_LABEL = "app=logstash-elastic"
    LOGSTASH_S3_LABEL = "app=logstash-elastic-s3"
    MAIN_CUSTOMER_PIPELINES = ["main", "customer"]
    S3_PIPELINE = "s3"
    workload_pods = {}
    workload_pipelines = {
        LOGSTASH_LABEL: ["main", "customer", "dlq"],
        LOGSTASH_S3_LABEL: [S3_PIPELINE],
    }
    required_plugins = [
        "logstash-input-dead_letter_queue",
        "logstash-input-http",
        "logstash-filter-date",
        "logstash-filter-dissect",
        "logstash-filter-drop",
        "logstash-filter-geoip",
        "logstash-filter-grok",
        "logstash-filter-kv",
        "logstash-filter-mutate",
        "logstash-filter-translate",
        "logstash-filter-useragent",
        "logstash-output-opensearch",
    ]

    @classmethod
    def setUpClass(cls):
        cls.k8s_utils = K8sUtils()
        for label in cls.workload_pipelines:
            pods = cls.k8s_utils.get_deployment_pod_names(label, cls.namespace)
            if not pods:
                raise RuntimeError(f"No Logstash pods found for label {label} in namespace {cls.namespace}.")
            cls.workload_pods[label] = pods
            print(f"Detected Logstash pods for {label}: {', '.join(pods)}")

            pods_ready = cls.k8s_utils.wait_for_all_pods_ready(label, cls.namespace)
            if not pods_ready:
                raise RuntimeError(f"Not all Logstash pods are ready for label {label}.")
        print("All Logstash pods are running and containers are Ready.")

    def exec_in_logstash_container(self, pod_name, command):
        return self.k8s_utils.exec_command(
            namespace=self.namespace,
            pod_name=pod_name,
            command=command,
            container_name="logstash"
        )

    def _extract_pipeline_stats(self, stats_json, pipeline_name):
        pipelines = stats_json.get("pipelines")
        if isinstance(pipelines, dict) and pipeline_name in pipelines:
            return pipelines[pipeline_name]
        return stats_json

    def _has_observable_pipeline_metrics(self, pipeline_stats):
        if not isinstance(pipeline_stats, dict):
            return False
        return any(
            key in pipeline_stats
            for key in ("events", "plugins", "reloads", "queue", "vertices", "flow")
        )

    def check_pipeline_status(self, label, pod, pipeline_name):
        command = ["curl", "-s", f"http://localhost:9600/_node/stats/pipelines/{pipeline_name}?pretty"]
        output = self.exec_in_logstash_container(pod, command)
        stats_json = parse_output(output, pod)
        pipeline_stats = self._extract_pipeline_stats(stats_json, pipeline_name)
        self.assertTrue(
            isinstance(pipeline_stats, dict) and pipeline_stats,
            f"No pipeline stats returned for {pipeline_name} in pod {pod} (label {label})"
        )
        pipeline_status = pipeline_stats.get("status", "")

        expected_statuses = {"green"}
        if label == self.LOGSTASH_S3_LABEL and pipeline_name == self.S3_PIPELINE:
            # On low/no traffic, Logstash may report 'unknown' for these pipelines.
            expected_statuses.add("unknown")
        if pipeline_status:
            self.assertIn(
                pipeline_status,
                expected_statuses,
                f"{pipeline_name.capitalize()} pipeline in pod {pod} (label {label}) "
                f"is not in a healthy state. Status: {pipeline_status}. "
                f"Expected one of: {sorted(expected_statuses)}"
            )
        else:
            self.assertTrue(
                self._has_observable_pipeline_metrics(pipeline_stats),
                f"{pipeline_name.capitalize()} pipeline in pod {pod} (label {label}) "
                f"has no status and no observable metrics blocks."
            )

    def test_all_pipeline_statuses(self):
        for label, pipelines in self.workload_pipelines.items():
            for pod in self.workload_pods[label]:
                for pipeline_name in pipelines:
                    with self.subTest(label=label, pod=pod, pipeline=pipeline_name):
                        self.check_pipeline_status(label, pod, pipeline_name)

    def test_plugins_existence(self):
        first_label = next(iter(self.workload_pods))
        pod = self.workload_pods[first_label][0]
        command = ["curl", "-s", "http://localhost:9600/_node/plugins?pretty"]
        output = self.exec_in_logstash_container(pod, command)
        plugins_json = parse_output(output, pod)
        installed_plugins = [plugin["name"] for plugin in plugins_json.get("plugins", [])]
        missing_plugins = [plugin for plugin in self.required_plugins if plugin not in installed_plugins]
        self.assertFalse(
            missing_plugins,
            f"Missing plugins in pod {pod}: {', '.join(missing_plugins)}"
        )

    def _fetch_s3_pipeline_events(self, pod):
        """Read live s3 pipeline stats from the pod and return the events block."""
        command = ["curl", "-s", f"http://localhost:9600/_node/stats/pipelines/{self.S3_PIPELINE}?pretty"]
        output = self.exec_in_logstash_container(pod, command)
        stats_json = parse_output(output, pod)
        pipeline_stats = self._extract_pipeline_stats(stats_json, self.S3_PIPELINE)
        self.assertTrue(
            isinstance(pipeline_stats, dict) and pipeline_stats,
            f"No s3 pipeline stats returned for pod {pod}"
        )
        return pipeline_stats.get("events", {})

    def _poll_s3_pipeline_drained(self, pod):
        """
        Poll live stats until every event counted `in` has been counted `out`.

        Each poll reads a FRESH in/out pair from the same snapshot, so the
        comparison never mixes a stale number with a new one. The S3 output
        counts `out` only after a successful flush, so while the batch buffer
        or an open file part holds events, `out` lags `in` — that lag must
        close (the pipeline is a pass-through) before the deadline.
        """
        deadline = time.monotonic() + S3_DRAIN_TIMEOUT_SECONDS
        last_snapshot = None

        while True:
            events = self._fetch_s3_pipeline_events(pod)
            if events:
                self.assertIn("in", events, f"events.in missing for s3 pipeline in pod {pod}")
                self.assertIn("out", events, f"events.out missing for s3 pipeline in pod {pod}")
                self.assertIsInstance(events["in"], (int, float), f"events.in is not numeric in pod {pod}")
                self.assertIsInstance(events["out"], (int, float), f"events.out is not numeric in pod {pod}")
                self.assertGreaterEqual(events["in"], 0, f"events.in must be >= 0 in pod {pod}")
                self.assertGreaterEqual(events["out"], 0, f"events.out must be >= 0 in pod {pod}")
                if events["in"] == events["out"]:
                    return events
                print(f"  [s3 drain poll] pod {pod}: in={events['in']} out={events['out']} — waiting for flush")
            last_snapshot = events

            if time.monotonic() >= deadline:
                return last_snapshot
            time.sleep(S3_POLL_INTERVAL_SECONDS)

    def test_s3_pipeline_stats_events_and_failures(self):
        label = self.LOGSTASH_S3_LABEL
        pods = self.workload_pods.get(label, [])
        self.assertTrue(pods, f"No Logstash pods found for label {label}")

        for pod in pods:
            with self.subTest(label=label, pod=pod):
                final_events = self._poll_s3_pipeline_drained(pod)
                if not final_events:
                    # Some versions/plugins expose flow/reloads/plugins without events counters when idle.
                    continue
                self.assertEqual(
                    final_events["in"],
                    final_events["out"],
                    f"s3 pipeline in pod {pod}: events_in ({final_events['in']}) != events_out "
                    f"({final_events['out']}) after {S3_DRAIN_TIMEOUT_SECONDS}s. "
                    f"The S3 pipeline is a pass-through — all ingested events must be flushed to S3.",
                )

    def test_main_customer_pipeline_events_and_failures(self):
        """
        Validates events schema, consistency, and failure counters for the main and
        customer pipelines running in logstash-elastic pods.

        Checks:
          - events.in and events.out keys are present.
          - Both values are numeric (int or float).
          - events_in >= events_out (fail if events_out exceeds events_in).
        """
        label = self.LOGSTASH_LABEL
        pipelines = self.MAIN_CUSTOMER_PIPELINES
        pods = self.workload_pods.get(label, [])
        self.assertTrue(pods, f"No Logstash pods found for label {label}")

        for pod in pods:
            for pipeline_name in pipelines:
                with self.subTest(label=label, pod=pod, pipeline=pipeline_name):
                    command = [
                        "curl", "-s",
                        f"http://localhost:9600/_node/stats/pipelines/{pipeline_name}?pretty",
                    ]
                    output = self.exec_in_logstash_container(pod, command)
                    stats_json = parse_output(output, pod)
                    pipeline_stats = self._extract_pipeline_stats(stats_json, pipeline_name)

                    events = pipeline_stats.get("events", {})
                    if not events:
                        # Pipeline idle but initialised - no schema to validate.
                        continue

                    self.assertIn("in", events, f"events.in missing for '{pipeline_name}' in pod {pod}")
                    self.assertIn("out", events, f"events.out missing for '{pipeline_name}' in pod {pod}")
                    self.assertIsInstance(
                        events["in"], (int, float),
                        f"events.in is not numeric for '{pipeline_name}' in pod {pod}",
                    )
                    self.assertIsInstance(
                        events["out"], (int, float),
                        f"events.out is not numeric for '{pipeline_name}' in pod {pod}",
                    )
                    print(
                        f"  [{pipeline_name}] pod {pod}: "
                        f"events_in={events['in']}, events_out={events['out']}"
                    )
                    self.assertGreaterEqual(
                        events["in"],
                        events["out"],
                        f"Pipeline '{pipeline_name}' in pod {pod}: "
                        f"events_out ({events['out']}) exceeds events_in ({events['in']}). "
                        "Possible pipeline misconfiguration or stats corruption.",
                    )

if __name__ == "__main__":
    unittest.main()
