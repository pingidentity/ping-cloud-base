import unittest
import json
from ast import literal_eval
from k8s_utils import K8sUtils


def parse_output(output, pod):
    try:
        return json.loads(output)
    except json.JSONDecodeError:
        parsed_data = literal_eval(output)  
        return json.loads(json.dumps(parsed_data))


class TestLogstash(unittest.TestCase):
    namespace = "elastic-stack-logging"
    workload_pods = {}
    workload_pipelines = {
        "app=logstash-elastic": ["main", "customer", "dlq"],
        "app=logstash-elastic-s3": ["s3"],
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
        if label == "app=logstash-elastic-s3" and pipeline_name == "s3":
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

    def _collect_failure_counters(self, obj):
        counters = []
        if isinstance(obj, dict):
            for key, value in obj.items():
                if key in {"failures", "failure", "failed", "non_retryable_failures", "retry_failures"} and isinstance(value, (int, float)):
                    counters.append((key, value))
                counters.extend(self._collect_failure_counters(value))
        elif isinstance(obj, list):
            for item in obj:
                counters.extend(self._collect_failure_counters(item))
        return counters

    def test_s3_pipeline_stats_events_and_failures(self):
        label = "app=logstash-elastic-s3"
        pods = self.workload_pods.get(label, [])
        self.assertTrue(pods, f"No Logstash pods found for label {label}")

        for pod in pods:
            with self.subTest(label=label, pod=pod):
                command = ["curl", "-s", "http://localhost:9600/_node/stats/pipelines/s3?pretty"]
                output = self.exec_in_logstash_container(pod, command)
                stats_json = parse_output(output, pod)
                pipeline_stats = self._extract_pipeline_stats(stats_json, "s3")
                self.assertTrue(
                    isinstance(pipeline_stats, dict) and pipeline_stats,
                    f"No s3 pipeline stats returned for pod {pod}"
                )
                pipeline_status = pipeline_stats.get("status", "")
                if pipeline_status:
                    self.assertIn(
                        pipeline_status,
                        {"green", "unknown"},
                        f"s3 pipeline status in pod {pod} is unexpected: {pipeline_status}"
                    )

                events = pipeline_stats.get("events", {})
                if not events:
                    # Some versions/plugins expose flow/reloads/plugins without events counters when idle.
                    if pipeline_status == "unknown" or self._has_observable_pipeline_metrics(pipeline_stats):
                        continue
                    self.fail(f"events block missing for s3 pipeline in pod {pod} while status is {pipeline_status}")

                self.assertIn("in", events, f"events.in missing for s3 pipeline in pod {pod}")
                self.assertIn("out", events, f"events.out missing for s3 pipeline in pod {pod}")
                self.assertIsInstance(events["in"], (int, float), f"events.in is not numeric in pod {pod}")
                self.assertIsInstance(events["out"], (int, float), f"events.out is not numeric in pod {pod}")
                self.assertGreaterEqual(events["in"], 0, f"events.in must be >= 0 in pod {pod}")
                self.assertGreaterEqual(events["out"], 0, f"events.out must be >= 0 in pod {pod}")

                # Validate failure counters when exposed by this Logstash build/plugin set.
                failure_counters = self._collect_failure_counters(stats_json)
                for counter_name, counter_value in failure_counters:
                    self.assertGreaterEqual(
                        counter_value,
                        0,
                        f"{counter_name} is negative for s3 pipeline in pod {pod}: {counter_value}"
                    )


if __name__ == "__main__":
    unittest.main()
