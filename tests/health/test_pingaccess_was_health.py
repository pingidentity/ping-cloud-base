import requests, unittest, os

from health_common import TestHealthBase


class TestPingAccessWASHealth(TestHealthBase):
    deployment_name = "healthcheck-pingaccess-was"
    label = f"role={deployment_name}"
    pingaccess_was = "pingAccessWas"
    admin_configmap_name = "pingaccess-was-admin-environment-variables"
    admin_service_name_env_var = "K8S_SERVICE_NAME_PINGACCESS_WAS_ADMIN"
    admin_port_env_var = "PA_ADMIN_PORT"

    def test_pingaccess_was_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_pingaccess_was_results(self):
        res = requests.get(self.healthcheck_endpoint, verify=False)
        self.assertTrue(
            self.pingaccess_was in res.json()["health"].keys(),
            f"No {self.pingaccess_was} in health check results",
        )

    def test_pingaccess_was_health_results_published(self):
        """
        Verifies that the pingaccess-was-health pod publishes its results to the healthcheck
        service, and that the published product has the expected summary fields and counts
        """
        res = requests.get(self.healthcheck_endpoint, verify=False)
        result = res.json()["health"][self.pingaccess_was]
        for key in [
            "healthStatus",
            "passedChecks",
            "failedChecks",
            "degradedChecks",
            "tests",
            "lastModified",
        ]:
            self.assertIn(
                key, result, f"{key} missing from {self.pingaccess_was} result"
            )
        for key in ["passedChecks", "failedChecks", "degradedChecks"]:
            self.assertIsInstance(result[key], int, f"{key} was not an integer")
            self.assertGreaterEqual(result[key], 0, f"{key} was negative")
        self.assertTrue(
            0 <= float(result["healthStatus"]) <= 100,
            "healthStatus was not between 0-100",
        )

    def test_admin_api_url_uses_service_name_in_primary_region(self):
        self.assert_admin_api_url_uses_service_name(
            "/app/PAWASVariables.py", "pa_was_admin_api_host"
        )
