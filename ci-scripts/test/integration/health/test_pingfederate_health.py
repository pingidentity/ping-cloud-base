import requests

from health_common import Categories, TestHealthBase


class TestPingFederateHealth(TestHealthBase):
    deployment_name = "healthcheck-pingfederate"
    pingfederate = "pingFederate"

    def test_pingfederate_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_pingfederate_results(self):
        res = requests.get(self.endpoint, verify=False)
        self.assertTrue(
            self.pingfederate in res.json()["health"].keys(),
            f"No {self.pingfederate} in health check results",
        )

    def test_health_check_has_registered_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.pod_status)
        res = [key for key in test_results if "registered" in key]
        self.assertTrue(
            len(res) > 0, "No 'registered with PF Admin' checks found in health check results"
        )

    def test_health_check_has_responsive_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.connectivity)
        res = [key for key in test_results if "responds" in key]
        self.assertTrue(
            len(res) > 0, "No 'responds to requests' checks found in health check results"
        )
