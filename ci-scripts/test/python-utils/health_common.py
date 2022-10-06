from dataclasses import dataclass

import requests

from k8s_utils import K8sUtils


@dataclass
class Categories:
    pod_status = "podStatus"
    synthetic = "synthetic"
    data = "data"
    connectivity = "connectivity"
    cluster_members = "clusterMembers"


class TestHealthBase(K8sUtils):
    job_name = ""

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
