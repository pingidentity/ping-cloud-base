import requests, unittest, os

from health_common import TestHealthBase


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPingAccessHealth(TestHealthBase):
    deployment_name = "healthcheck-pingaccess"
    label = f"role={deployment_name}"
    pingaccess = "pingAccess"
    admin_configmap_name = "pingaccess-admin-environment-variables"
    admin_service_name_env_var = "K8S_SERVICE_NAME_PINGACCESS_ADMIN"
    admin_port_env_var = "PA_ADMIN_PORT"

    def test_pingaccess_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_pingaccess_results(self):
        res = requests.get(self.healthcheck_endpoint, verify=False)
        self.assertTrue(
            self.pingaccess in res.json()["health"].keys(),
            f"No {self.pingaccess} in health check results",
        )

    def test_pingaccess_health_results_published(self):
        """
        Verifies that the pingaccess-health pod publishes its results to the healthcheck
        service, and that the published product has the expected summary fields and counts
        """
        res = requests.get(self.healthcheck_endpoint, verify=False)
        result = res.json()["health"][self.pingaccess]
        for key in [
            "healthStatus",
            "passedChecks",
            "failedChecks",
            "degradedChecks",
            "tests",
            "lastModified",
        ]:
            self.assertIn(key, result, f"{key} missing from {self.pingaccess} result")
        for key in ["passedChecks", "failedChecks", "degradedChecks"]:
            self.assertIsInstance(result[key], int, f"{key} was not an integer")
            self.assertGreaterEqual(result[key], 0, f"{key} was negative")
        self.assertTrue(
            0 <= float(result["healthStatus"]) <= 100,
            "healthStatus was not between 0-100",
        )

    def test_admin_api_url_uses_service_name_in_primary_region(self):
        self.assert_admin_api_url_uses_service_name(
            "/app/PAVariables.py", "pa_admin_api_host"
        )
