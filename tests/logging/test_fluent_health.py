import subprocess
import time
import requests
import urllib3
import unittest
from k8s_utils import K8sUtils

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class PrometheusPortForward:
    process = None

    @staticmethod
    def start():
        if PrometheusPortForward.process:
            PrometheusPortForward.stop()
        PrometheusPortForward.process = subprocess.Popen(
            ["kubectl", "port-forward", "svc/prometheus", "9090:9090", "-n", "prometheus"],
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


class TestFluentBitMetrics(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kube_utils = K8sUtils()
        cls.namespace = "elastic-stack-logging"
        cls.prometheus_url = "http://localhost:9090/api/v1/query"
        cls.configmap_name = None
        cls.daemonset_name = "fluent-bit"

        configmaps = cls.kube_utils.core_client.list_namespaced_config_map(cls.namespace).items
        for cm in configmaps:
            if "fluent-bit-pipeline-core" in cm.metadata.name:
                cls.configmap_name = cm.metadata.name
                break
        if not cls.configmap_name:
            raise RuntimeError("Fluent Bit ConfigMap not found in the namespace!")

        print(f"Detected ConfigMap: {cls.configmap_name}")

        label = "k8s-app=fluent-bit"
        pod_ready = cls.kube_utils.wait_for_pod_ready(label, cls.namespace)
        if not pod_ready:
            raise RuntimeError("No Fluent Bit pods are ready.")
        print("Atleast one Fluent Bit pod is running and Ready.")

    def update_configmap(self):
        configmap_data = self.kube_utils.get_configmap_values(self.namespace, self.configmap_name)
        if "[OUTPUT]\n    Name                stdout" in configmap_data.get("elk.conf", ""):           #to skip stdout update if already present
            print("stdout already present in the ConfigMap. Skipping update.")
            return

        updated_data = (
            configmap_data["pipeline-core.conf"]
            + "\n[OUTPUT]\n    Name                stdout\n    Match               elk.kube.general.*\n"
        )

        self.kube_utils.core_client.patch_namespaced_config_map(
            name=self.configmap_name,
            namespace=self.namespace,
            body={"data": {"pipeline-core.conf": updated_data}},
        )
        print(f"Updated ConfigMap: {self.configmap_name}")

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
