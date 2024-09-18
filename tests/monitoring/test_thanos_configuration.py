import unittest
import boto3
import os
import logging
import re
from datetime import datetime, timedelta
from k8s_utils import K8sUtils

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class TestThanos(unittest.TestCase):
    def setUp(self):
        self.k8s_utils = K8sUtils()
        self.namespace = "prometheus"
        self.cluster_name = os.environ["CLUSTER_NAME"]
    
    def test_thanos_pods_running_and_ready(self):
        labels = {
            "app.kubernetes.io/component=storegateway": 17,  
            "app.kubernetes.io/component=compactor": 2,
            "app.kubernetes.io/component=receive": None
        }

        for label, time_limit in labels.items():
            with self.subTest(pod_component=label):
                logging.info(f"Checking if pods with label {label} are in the Ready state.")
                
                pods_ready = self.k8s_utils.wait_for_pod_ready(label, self.namespace)
                self.assertTrue(pods_ready, f"Pods with label '{label}' are not ready.")
                logging.info(f"Pods with label '{label}' are ready.")

                pod_names = self.k8s_utils.get_deployment_pod_names(label, self.namespace)

                for pod_name in pod_names:
                    with self.subTest(pod_name=pod_name):
                        pod = self.k8s_utils.core_client.read_namespaced_pod(name=pod_name, namespace=self.namespace)
                        container_statuses = pod.status.container_statuses

                        self.assertIsNotNone(container_statuses, f"Pod '{pod_name}' has no container statuses or is not fully initialized.")
                        
                        for container_status in container_statuses:
                            self.assertEqual(container_status.restart_count, 0, 
                                             f"Pod '{pod_name}' has restarted {container_status.restart_count} times.")
                            logging.info(f"Pod '{pod_name}' has no restarts.")

                if time_limit:
                    self._check_logs_for_sync_pattern(pod_names, time_limit)

    def _check_logs_for_sync_pattern(self, pod_names, time_limit):
        pattern = re.compile(r"successfully synchronized block metadata")
        time_threshold = datetime.utcnow() - timedelta(minutes=time_limit)

        for pod_name in pod_names:
            with self.subTest(log_check=pod_name):
                logging.info(f"Fetching logs for pod '{pod_name}' in namespace '{self.namespace}'")
                logs = self.k8s_utils.get_latest_pod_logs(pod_name, None, self.namespace, 100)
                self.assertIsNotNone(logs, f"Logs for pod '{pod_name}' are empty")

                found_pattern = False
                for log in logs:
                    if pattern.search(log):  # First, check if the log contains the pattern
                        match = re.search(r'ts=(\d+-\d+-\d+T\d+:\d+:\d+.\d+)', log)
                        if match:
                            log_time_str = match.group(1)[:26] + 'Z'  # Normalize timestamp
                            log_time = datetime.strptime(log_time_str, '%Y-%m-%dT%H:%M:%S.%fZ')
                            if log_time >= time_threshold:
                                found_pattern = True
                                break

                self.assertTrue(found_pattern, f"Pattern not found in logs for pod '{pod_name}' within last {time_limit} minutes.")
                logging.info(f"Successfully synchronized block metadata pattern found in logs for pod '{pod_name}' within last {time_limit} minutes.")


if __name__ == "__main__":
    unittest.main()
