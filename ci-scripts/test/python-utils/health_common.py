from dataclasses import dataclass
import os

import kubernetes as k8s
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


class TestHealthBase(K8sUtils):
    deployment_name = ""
    ping_cloud = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
    health = "health"

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # Handle cases where the tests are still retrying by killing the pods and running the check
        cls.kill_pods(label=f"role={cls.deployment_name}", namespace=cls.health)
        cls.wait_for_pod_running(label=f"role={cls.deployment_name}", namespace=cls.health)
        cls.wait_for_healthcheck_sent(label=f"role={cls.deployment_name}", namespace=cls.health)

    @classmethod
    def wait_for_healthcheck_sent(cls, label: str, namespace: str):
        pod_names = cls.get_deployment_pod_names(label=label, namespace=namespace)
        watch = k8s.watch.Watch()
        for pod_name in pod_names:
            for event in watch.stream(func=cls.core_client.read_namespaced_pod_log, namespace=namespace, name=pod_name):
                if event.endswith(f"sent to http://healthcheck.{cls.ping_cloud}:5000"):
                    watch.stop()
                    return

    def get_test_results(self, suite: str, category: str) -> {}:
        """
        Request test results from the healthcheck service and get a dictionary of the test names and PASS/FAIL result
        :param suite: Test suite
        :param category: Category within the test suite
        :return: Test results dictionary in the format {"test name": "PASS/FAIL", ...}
        """
        response = requests.get(self.endpoint, verify=False)
        return response.json()["health"][suite]["tests"][category]

    def deployment_exists(self):
        deployments = self.app_client.list_namespaced_deployment("health")
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
