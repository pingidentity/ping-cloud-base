import unittest
from dataclasses import dataclass
import os

import requests
import urllib3

from k8s_utils import K8sUtils

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


@dataclass
class Categories:
    pod_status = "podStatus"
    synthetic = "synthetic"
    data = "data"
    connectivity = "connectivity"
    cluster_members = "clusterMembers"


class TestHealthBase(unittest.TestCase):
    deployment_name = ""
    ping_cloud = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
    health = "health"
    k8s = None
    healthcheck_endpoint = ""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.k8s = K8sUtils()
        cls.healthcheck_endpoint = cls.k8s.get_endpoint("healthcheck")
        # Handle cases where the tests are still retrying by killing the pods and running the check
        cls.k8s.kill_pods(label=f"role={cls.deployment_name}", namespace=cls.health)
        cls.k8s.wait_for_pod_running(label=f"role={cls.deployment_name}", namespace=cls.health)
        cls.wait_for_healthcheck_sent(label=f"role={cls.deployment_name}", namespace=cls.health)

    @classmethod
    def wait_for_healthcheck_sent(cls, label: str, namespace: str):
        pod_names = cls.k8s.get_deployment_pod_names(label=label, namespace=namespace)
        for pod_name in pod_names:
            cls.k8s.wait_for_pod_log(pod_name=pod_name, namespace=namespace, log_message=".xml sent to http://healthcheck.ping-cloud")

    def get_test_results(self, suite: str, category: str) -> {}:
        """
        Request test results from the healthcheck service and get a dictionary of the test names and PASS/FAIL result
        :param suite: Test suite
        :param category: Category within the test suite
        :return: Test results dictionary in the format {"test name": "PASS/FAIL", ...}
        """
        response = requests.get(self.healthcheck_endpoint, verify=False)
        return response.json()["health"][suite]["tests"][category]

    def deployment_exists(self):
        deployments = self.k8s.app_client.list_namespaced_deployment("health")
        deployment_name = next(
            (
                deployment.metadata.name
                for deployment in deployments.items
                if deployment.metadata.name == self.deployment_name
            ),
            "",
        )
        self.assertEqual(
            self.deployment_name,
            deployment_name,
            f"Deployment '{self.deployment_name}' not found in cluster",
        )
