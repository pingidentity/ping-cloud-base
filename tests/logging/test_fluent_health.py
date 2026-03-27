import subprocess
import time
import requests
import urllib3
import unittest
import re
from k8s_utils import K8sUtils

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class PrometheusPortForward:
    process = None

    @staticmethod
    def start():
        if PrometheusPortForward.process:
            PrometheusPortForward.stop()
        PrometheusPortForward.process = subprocess.Popen(
            ["kubectl", "port-forward", "svc/prometheus-headless", "9090:9090", "-n", "prometheus"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        time.sleep(3)

    @staticmethod
    def stop():
        if PrometheusPortForward.process:
            PrometheusPortForward.process.terminate()


def query_metric(metric_name, prometheus_url):
    try:
        response = requests.get(f"{prometheus_url}?query={metric_name}", verify=False)
        if response.status_code == 200:
            result = response.json().get('data', {}).get('result', [])
            if not result:
                print(f"No data returned for metric {metric_name}")
                return None
            total = sum(float(item['value'][1]) for item in result)
            return total
        else:
            print(f"Error querying Prometheus: {response.status_code}, {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"Error querying Prometheus: {e}")
    return None


def query_result(metric_query, prometheus_url):
    try:
        response = requests.get(f"{prometheus_url}?query={metric_query}", verify=False)
        if response.status_code == 200:
            return response.json().get('data', {}).get('result', [])
        print(f"Error querying Prometheus: {response.status_code}, {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"Error querying Prometheus: {e}")
    return []


class TestFluentBitMetrics(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kube_utils = K8sUtils()
        cls.namespace = "elastic-stack-logging"
        cls.prometheus_url = "http://localhost:9090/api/v1/query"
        cls.core_configmap_name = None
        cls.outputs_configmap_name = None
        cls.daemonset_name = "fluent-bit"

        configmaps = cls.kube_utils.core_client.list_namespaced_config_map(cls.namespace).items
        for cm in configmaps:
            if "fluent-bit-pipeline-core" in cm.metadata.name:
                cls.core_configmap_name = cm.metadata.name
            if "fluent-bit-pipeline-outputs" in cm.metadata.name:
                cls.outputs_configmap_name = cm.metadata.name
        if not cls.core_configmap_name:
            raise RuntimeError("Fluent Bit ConfigMap not found in the namespace!")
        if not cls.outputs_configmap_name:
            raise RuntimeError("Fluent Bit pipeline outputs ConfigMap not found in the namespace!")

        print(f"Detected Fluent Bit Core ConfigMap: {cls.core_configmap_name}")
        print(f"Detected Fluent Bit Outputs ConfigMap: {cls.outputs_configmap_name}")

        label = "k8s-app=fluent-bit"
        pod_ready = cls.kube_utils.wait_for_pod_ready(label, cls.namespace)
        if not pod_ready:
            raise RuntimeError("No Fluent Bit pods are ready.")
        print("Atleast one Fluent Bit pod is running and Ready.")

    def update_configmap(self):
        configmap_data = self.kube_utils.get_configmap_values(self.namespace, self.core_configmap_name)
        if "[OUTPUT]\n    Name                stdout" in configmap_data.get("elk.conf", ""):           #to skip stdout update if already present
            print("stdout already present in the ConfigMap. Skipping update.")
            return

        updated_data = (
            configmap_data["pipeline-core.conf"]
            + "\n[OUTPUT]\n    Name                stdout\n    Match               elk.kube.general.*\n"
        )

        self.kube_utils.core_client.patch_namespaced_config_map(
            name=self.core_configmap_name,
            namespace=self.namespace,
            body={"data": {"pipeline-core.conf": updated_data}},
        )
        print(f"Updated ConfigMap: {self.core_configmap_name}")

    def _parse_output_routes(self):
        configmap_data = self.kube_utils.get_configmap_values(self.namespace, self.outputs_configmap_name)
        outputs_conf = configmap_data.get("pipeline-outputs.conf", "")
        if not outputs_conf:
            return {}

        routes = {}
        # Parse blocks for each output and extract alias/host/port.
        blocks = re.findall(r"\[OUTPUT\](.*?)(?=\n\[OUTPUT\]|\Z)", outputs_conf, flags=re.S)
        for block in blocks:
            alias_match = re.search(r"^\s*Alias\s+([^\s]+)", block, flags=re.M)
            host_match = re.search(r"^\s*Host\s+([^\s]+)", block, flags=re.M)
            port_match = re.search(r"^\s*Port\s+([0-9]+)", block, flags=re.M)
            if alias_match and host_match and port_match:
                routes[alias_match.group(1)] = {
                    "host": host_match.group(1),
                    "port": int(port_match.group(1))
                }
        return routes

    def _assert_k8s_service_route_reachable(self, host, port):
        host_parts = host.split(".")
        self.assertGreaterEqual(
            len(host_parts), 2,
            f"Output host must include service and namespace, got: {host}"
        )
        service_name = host_parts[0]
        namespace = host_parts[1]

        svc = self.kube_utils.core_client.read_namespaced_service(name=service_name, namespace=namespace)
        self.assertIsNotNone(svc, f"Service not found for route host {host}")

        # ExternalName is acceptable for routing contract.
        if svc.spec.type == "ExternalName":
            self.assertTrue(svc.spec.external_name, f"ExternalName service {namespace}/{service_name} has no externalName")
            return

        service_ports = svc.spec.ports or []
        self.assertTrue(
            any(p.port == port for p in service_ports),
            f"Service {namespace}/{service_name} does not expose port {port}"
        )

        eps = self.kube_utils.core_client.read_namespaced_endpoints(name=service_name, namespace=namespace)
        subsets = eps.subsets or []
        has_ready_address = any((subset.addresses or []) for subset in subsets)
        self.assertTrue(has_ready_address, f"Service {namespace}/{service_name} has no ready endpoints")

    def test_fluentbit_output_endpoint_reachability(self):
        routes = self._parse_output_routes()
        expected_aliases = {"s3_app_out", "logstash_elk_out", "logstash_customer_out"}
        self.assertTrue(expected_aliases.issubset(set(routes.keys())), f"Missing expected output aliases: {expected_aliases - set(routes.keys())}")

        for alias in expected_aliases:
            route = routes[alias]
            self._assert_k8s_service_route_reachable(route["host"], route["port"])

    def test_per_output_delivery_metric(self):
        PrometheusPortForward.start()
        try:
            expected_aliases = ["s3_app_out", "logstash_elk_out", "logstash_customer_out"]
            for alias in expected_aliases:
                found = False
                # Fluent Bit metric labels vary by deployment; try several likely label keys.
                for label_key in ["alias", "name", "output", "instance"]:
                    query = f'fluentbit_output_proc_records_total{{{label_key}=~".*{alias}.*"}}'
                    result = query_result(query, self.prometheus_url)
                    if result:
                        found = True
                        break
                self.assertTrue(found, f"No fluentbit_output_proc_records_total series found for output alias {alias}")
        finally:
            PrometheusPortForward.stop()

    def restart_daemonset(self):
        label = "k8s-app=fluent-bit"
        self.kube_utils.kill_pods(label, self.namespace)
        pod_ready = self.kube_utils.wait_for_pod_ready(label, self.namespace)
        if not pod_ready:
            raise RuntimeError("No Fluent Bit pods are ready after restart.")
        print(f"Restarted DaemonSet by deleting pods with label: {label}")

    def test_check_fluentbit_metrics(self):
        PrometheusPortForward.start()
        try:
            self.update_configmap()
            self.restart_daemonset()

            attempt = 0
            max_attempts = 10
            while attempt < max_attempts:
                input_records = query_metric("fluentbit_input_records_total", self.prometheus_url)
                output_records = query_metric("fluentbit_output_proc_records_total", self.prometheus_url)
                if input_records is None or output_records is None:
                    print(f"Attempt {attempt + 1}: Metrics not found or connection issue. Retrying...")
                elif input_records > 0 and output_records > 0:
                    print(f"Attempt {attempt + 1}: Metrics found.")
                    print(f"fluentbit_input_records_total: {input_records}")
                    print(f"fluentbit_output_proc_records_total: {output_records}")
                    break
                else:
                    print(f"Attempt {attempt + 1}: Metrics issue: input={input_records}, output={output_records}")
                attempt += 1
                time.sleep(10)
            else:
                self.fail("Metrics check failed after max attempts.")
        finally:
            PrometheusPortForward.stop()


if __name__ == "__main__":
    unittest.main()
