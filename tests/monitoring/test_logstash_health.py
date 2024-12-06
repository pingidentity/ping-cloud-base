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
    logstash_pods = []
    pipelines = ["main", "s3", "customer", "dlq"]
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
        label = "app=logstash-elastic"
        cls.logstash_pods = cls.k8s_utils.get_deployment_pod_names(label, cls.namespace)
        if not cls.logstash_pods:
            raise RuntimeError("No Logstash pods found in the namespace!")
        print(f"Detected Logstash pods: {', '.join(cls.logstash_pods)}")
        pods_ready = cls.k8s_utils.wait_for_all_pods_ready(label, cls.namespace)
        if not pods_ready:
            raise RuntimeError("Not all Logstash pods are ready.")
        print("All Logstash pods are running and containers are Ready.")

    def exec_in_logstash_container(self, pod_name, command):
        return self.k8s_utils.exec_command(
            namespace=self.namespace,
            pod_name=pod_name,
            command=command,
            container_name="logstash"
        )

    def check_pipeline_status(self, pod, pipeline_name):
        command = ["curl", "-s", f"http://localhost:9600/_node/stats/pipelines/{pipeline_name}?pretty"]
        output = self.exec_in_logstash_container(pod, command)
        stats_json = parse_output(output, pod)
        pipeline_status = stats_json.get("status", "")
        self.assertEqual(
            pipeline_status,
            "green",
            f"{pipeline_name.capitalize()} pipeline in pod {pod} is not in a healthy state. Status: {pipeline_status}"
        )

    def test_all_pipeline_statuses(self):
        for pod in self.logstash_pods:
            for pipeline_name in self.pipelines:
                with self.subTest(pod=pod, pipeline=pipeline_name):
                    self.check_pipeline_status(pod, pipeline_name)

    def test_plugins_existence(self):
        pod = self.logstash_pods[0]
        command = ["curl", "-s", "http://localhost:9600/_node/plugins?pretty"]
        output = self.exec_in_logstash_container(pod, command)
        plugins_json = parse_output(output, pod)
        installed_plugins = [plugin["name"] for plugin in plugins_json.get("plugins", [])]
        missing_plugins = [plugin for plugin in self.required_plugins if plugin not in installed_plugins]
        self.assertFalse(
            missing_plugins,
            f"Missing plugins in pod {pod}: {', '.join(missing_plugins)}"
        )


if __name__ == "__main__":
    unittest.main()
