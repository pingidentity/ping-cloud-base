import unittest
import re
from kubernetes import client, config


class TestLogstashSplitConfig(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        config.load_kube_config()
        cls.namespace = "elastic-stack-logging"
        cls.core = client.CoreV1Api()
        cls.apps = client.AppsV1Api()

    def test_fluentbit_routing_outputs(self):
        cms = self.core.list_namespaced_config_map(namespace=self.namespace).items
        cm = next(
            (item for item in cms if "fluent-bit-pipeline-outputs" in (item.metadata.name or "")),
            None
        )
        self.assertIsNotNone(
            cm,
            "ConfigMap containing 'fluent-bit-pipeline-outputs' was not found"
        )
        conf = (cm.data or {}).get("pipeline-outputs.conf", "")
        self.assertTrue(conf, "pipeline-outputs.conf is missing in fluent-bit-pipeline-outputs ConfigMap")

        # S3 logs should be routed to dedicated S3 endpoint.
        self.assertIn("Alias               s3_app_out", conf)
        self.assertIn("Host                logstash-elastic-s3.elastic-stack-logging", conf)
        self.assertIn("Port                8081", conf)

        # Main and customer should continue to route to existing logstash service.
        self.assertIn("Alias               logstash_elk_out", conf)
        self.assertIn("Host                logstash-elastic.elastic-stack-logging", conf)
        self.assertIn("Port                8080", conf)
        self.assertIn("Alias               logstash_customer_out", conf)
        self.assertIn("Port                8084", conf)

    def test_pipeline_config_presence_per_sts(self):
        main_cm = self.core.read_namespaced_config_map(name="pipeline", namespace=self.namespace)
        s3_cm = self.core.read_namespaced_config_map(name="pipeline-s3", namespace=self.namespace)

        main_pipelines = (main_cm.data or {}).get("pipelines.yml", "")
        s3_pipelines = (s3_cm.data or {}).get("pipelines.yml", "")
        self.assertTrue(main_pipelines, "pipelines.yml missing in ConfigMap 'pipeline'")
        self.assertTrue(s3_pipelines, "pipelines.yml missing in ConfigMap 'pipeline-s3'")

        # Validate exact pipeline IDs per STS configmap.
        main_ids = set(re.findall(r"pipeline\.id:\s*([a-zA-Z0-9_-]+)", main_pipelines))
        s3_ids = set(re.findall(r"pipeline\.id:\s*([a-zA-Z0-9_-]+)", s3_pipelines))
        self.assertSetEqual(main_ids, {"main", "customer", "dlq"})
        self.assertSetEqual(s3_ids, {"s3"})

        # Validate corresponding STS mounts /usr/share/logstash/config/pipelines.yml with right ConfigMap.
        main_sts = self.apps.read_namespaced_stateful_set(name="logstash-elastic", namespace=self.namespace)
        s3_sts = self.apps.read_namespaced_stateful_set(name="logstash-elastic-s3", namespace=self.namespace)

        def mounted_configmap(sts, volume_name):
            volumes = sts.spec.template.spec.volumes or []
            for vol in volumes:
                if vol.name == volume_name and vol.config_map:
                    return vol.config_map.name
            return None

        self.assertEqual(mounted_configmap(main_sts, "logstash-pipelines"), "pipeline")
        self.assertEqual(mounted_configmap(s3_sts, "logstash-pipelines-s3"), "pipeline-s3")

    def test_no_opensearch_bootstrap_on_s3(self):
        pods = self.core.list_namespaced_pod(namespace=self.namespace).items
        s3_pods = [p for p in pods if p.metadata.name.startswith("logstash-elastic-s3")]
        main_pods = [p for p in pods if p.metadata.name.startswith("logstash-elastic-") and not p.metadata.name.startswith("logstash-elastic-s3")]

        self.assertTrue(s3_pods, "No logstash-elastic-s3 pods found")
        self.assertTrue(main_pods, "No logstash-elastic pods found")

        for pod in s3_pods:
            init_statuses = pod.status.init_container_statuses or []
            init_names = [i.name for i in init_statuses]
            self.assertNotIn(
                "opensearch-bootstrap",
                init_names,
                f"opensearch-bootstrap should not exist on {pod.metadata.name}"
            )

        # Keep main contract explicit: opensearch-bootstrap should exist on main logstash pods.
        for pod in main_pods:
            init_statuses = pod.status.init_container_statuses or []
            init_names = [i.name for i in init_statuses]
            self.assertIn(
                "opensearch-bootstrap",
                init_names,
                f"opensearch-bootstrap should exist on {pod.metadata.name}"
            )

    def test_service_port_contract(self):
        main_svc = self.core.read_namespaced_service(name="logstash-elastic", namespace=self.namespace)
        s3_svc = self.core.read_namespaced_service(name="logstash-elastic-s3", namespace=self.namespace)

        main_ports = {p.port for p in (main_svc.spec.ports or [])}
        s3_ports = {p.port for p in (s3_svc.spec.ports or [])}

        # Main service should expose main/customer related ports.
        self.assertIn(8080, main_ports)
        self.assertIn(8084, main_ports)
        self.assertIn(9198, main_ports)
        self.assertIn(9600, main_ports)
        self.assertNotIn(8081, main_ports)

        # S3 service should expose only S3 input and shared metrics/rest ports.
        self.assertIn(8081, s3_ports)
        self.assertIn(9198, s3_ports)
        self.assertIn(9600, s3_ports)
        self.assertNotIn(8080, s3_ports)
        self.assertNotIn(8084, s3_ports)


if __name__ == "__main__":
    unittest.main()
