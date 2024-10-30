import subprocess
import time
import requests
from kubernetes import client, config
import urllib3
import unittest
from k8s_utils import K8sUtils

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
config.load_kube_config()

class PrometheusPortForward:
    process = None

    @staticmethod
    def start():
        if PrometheusPortForward.process:
            PrometheusPortForward.stop()
        PrometheusPortForward.process = subprocess.Popen(
            ["kubectl", "port-forward", "svc/prometheus", "9090:9090", "-n", "prometheus"],
            stdout=subprocess.PIPE
        )
        for _ in range(10):
            if PrometheusPortForward.process.poll() is None:
                time.sleep(10)
                continue
            else:
                break
        return PrometheusPortForward.process

    @staticmethod
    def stop():
        if PrometheusPortForward.process:
            PrometheusPortForward.process.terminate()
            PrometheusPortForward.process = None

def query_metric(metric_name, prometheus_url):
    try:
        response = requests.get(f"{prometheus_url}?query={metric_name}", verify=False)
        if response.status_code == 200:
            result = response.json()['data']['result']
            return float(result[0]['value'][1]) if result else None
    except requests.exceptions.ConnectionError as e:
        print(f"Error querying Prometheus: {e}")
    return None

class TestFluentBitMetrics(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.k8s_utils = K8sUtils()
        cls.namespace = "elastic-stack-logging"
        cls.prometheus_url = "http://localhost:9090/api/v1/query"

    def check_all_fluentbit_pods_ready(self):
        pods_ready = self.k8s_utils.wait_for_pod_ready("k8s-app=fluent-bit", self.namespace)
        self.assertTrue(pods_ready, "Not all Fluent Bit pods are ready.")
        pod_names = self.k8s_utils.get_deployment_pod_names("k8s-app=fluent-bit", self.namespace)
        
        for pod_name in pod_names:
            pod = self.k8s_utils.core_client.read_namespaced_pod(name=pod_name, namespace=self.namespace)
            container_statuses = pod.status.container_statuses
            self.assertIsNotNone(container_statuses, f"Pod '{pod_name}' has no container statuses.")
            for container_status in container_statuses:
                self.assertEqual(container_status.ready, True, f"Pod '{pod_name}' is not ready.")
            print(f"Pod {pod_name} is ready")
        print("All Fluent Bit pods are up and running.")

    def test_fluentbit_pods_health(self):
        self.check_all_fluentbit_pods_ready()

    def test_check_fluentbit_metrics(self):
        self.check_all_fluentbit_pods_ready()
        PrometheusPortForward.start()

        attempt = 0
        max_attempts = 10
        while attempt < max_attempts:
            input_records = query_metric("fluentbit_input_records_total", self.prometheus_url)
            output_records = query_metric("fluentbit_output_proc_records_total", self.prometheus_url)

            if input_records is None or output_records is None:
                print("Metrics not found or connection issue. Restarting port-forward and retrying...")
                PrometheusPortForward.start()
            elif input_records > 0 and output_records > 0:
                print(f"Attempt {attempt+1}: Metrics found.")
                print(f"fluentbit_input_records_total: {input_records}")
                print(f"fluentbit_output_proc_records_total: {output_records}")
                break
            else:
                print(f"Attempt {attempt+1}: Metrics issue: input={input_records}, output={output_records}")

            attempt += 1
            time.sleep(10)

        self.assertLess(attempt, max_attempts, "Metrics check failed after max attempts.")
        PrometheusPortForward.stop()

if __name__ == '__main__':
    unittest.main()
