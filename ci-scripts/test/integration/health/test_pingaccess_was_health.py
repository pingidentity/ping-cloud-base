import requests

from health_common import Categories, TestHealthBase


class TestPingAccessWASHealth(TestHealthBase):
    deployment_name = "healthcheck-pingaccess-was"
    pingaccess_was = "pingAccessWas"

    def test_pingaccess_was_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_pingaccess_was_results(self):
        res = requests.get(self.endpoint, verify=False)
        self.assertTrue(
            self.pingaccess_was in res.json()["health"].keys(),
            f"No {self.pingaccess_was} in health check results",
        )

    def test_health_check_has_registered_results(self):
        test_results = self.get_test_results(self.pingaccess_was, Categories.pod_status)
        res = [key for key in test_results if "registered" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'registered with PA-WAS Admin' checks found in health check results",
        )

    def test_health_check_has_responsive_results(self):
        test_results = self.get_test_results(
            self.pingaccess_was, Categories.connectivity
        )
        res = [key for key in test_results if "responds" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'responds to requests' checks found in health check results",
        )
