import unittest
import subprocess
import time
import base64
import requests
import urllib3
from opensearchpy import OpenSearch
from k8s_utils import K8sUtils

class TestOpenSearchClusterHealth(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.k8s = K8sUtils()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        cls.port_forward_process = subprocess.Popen(
            ["kubectl", "port-forward", "service/opensearch-cluster-headless", "9200:9200",
             "-n", "elastic-stack-logging"], stdout=subprocess.PIPE
        )
        time.sleep(5)
        opensearch_creds_secret = cls.k8s.get_namespaced_secret(
            "opensearch-admin-credentials", "elastic-stack-logging"
        )
        username = base64.b64decode(opensearch_creds_secret.data['username']).decode('utf-8')
        password = base64.b64decode(opensearch_creds_secret.data['password']).decode('utf-8')
        print(username, password)
        response = requests.get(f"https://localhost:{9200}", verify=False, auth=(username, password))
        if response.status_code == 200:
            print("Port-forward established successfully.")
        else:
            raise Exception("Port-forward failed. Exiting test.")
        # Create OpenSearch client
        cls.opensearch_client = OpenSearch(
            hosts=[{'host': 'localhost', 'port': 9200}],
            http_auth=(username, password),
            use_ssl=True,
            verify_certs=False,
            ssl_show_warn=False,
            timeout=240
        )
        print("OpenSearch client created")

    @classmethod
    def tearDownClass(cls):
        # Terminate the port-forward process after the test suite runs
        cls.port_forward_process.terminate()

    def test_cluster_health_status(self):
        # Check the health status of the cluster
        health = self.opensearch_client.cluster.health()
        cluster_status = health.get('status', 'unknown')
        print(f"Cluster health status: {cluster_status}")
        # Fail the test if the cluster status is not green
        self.assertEqual(cluster_status, "green", f"Cluster status is not green: {cluster_status}")


    def test_logstash_pods_and_bootstrap_index(self):
        print("Checking if Logstash pods are running...")
        self.k8s.wait_for_pod_running(
            label="app=logstash-elastic", namespace="elastic-stack-logging")

        exists = self.opensearch_client.indices.exists(index="bootstrap-status")
        print(f"bootstrap-status index exists: {exists}")
        self.assertTrue(
            exists,
            "bootstrap-status index does not exist in OpenSearch while logstash pod is running"
        )

if __name__ == '__main__':
    unittest.main()
