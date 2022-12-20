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


class TestHealthBase(K8sUtils):
    job_name = ""
    ping_cloud = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.run_job(cls.job_name)

    def get_test_results(self, suite: str, category: str) -> {}:
        """
        Request test results from the healthcheck service and get a dictionary of the test names and PASS/FAIL result
        :param suite: Test suite
        :param category: Category within the test suite
        :return: Test results dictionary in the format {"test name": "PASS/FAIL", ...}
        """
        response = requests.get(self.endpoint, verify=False)
        return response.json()["health"][suite]["tests"][category]
