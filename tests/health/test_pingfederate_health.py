import unittest, requests, os

from health_common import Categories, TestHealthBase


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPingFederateHealth(TestHealthBase):
    deployment_name = "healthcheck-pingfederate"
    label = f"role={deployment_name}"
    pingfederate = "pingFederate"
    admin_configmap_name = "pingfederate-admin-environment-variables"
    admin_service_name_env_var = "K8S_SERVICE_NAME_PINGFEDERATE_ADMIN"
    admin_port_env_var = "PF_ADMIN_PORT"

    def setUp(self) -> None:
        self.ping_cloud_ns = next(
            (
                ns
                for ns in self.k8s.get_namespace_names()
                if ns.startswith(self.ping_cloud)
            ),
            self.ping_cloud,
        )
        self.pod_names = self.k8s.get_deployment_pod_names(
            "role=pingfederate-engine", self.ping_cloud_ns
        )

    def test_pingfederate_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_pingfederate_results(self):
        res = requests.get(self.healthcheck_endpoint, verify=False)
        self.assertTrue(
            self.pingfederate in res.json()["health"].keys(),
            f"No {self.pingfederate} in health check results",
        )

    def test_health_check_has_registered_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.pod_status)
        res = [key for key in test_results if "registered" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'registered with PF Admin' checks found in health check results",
        )

    def test_health_check_has_responsive_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.connectivity)
        res = [key for key in test_results if "responds" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'responds to requests' checks found in health check results",
        )

    @unittest.skip("Skipping until check is re-enabled, ref: PDO-5511")
    def test_health_check_has_certificate_results(self):
        self.assertIn(
            "No certificates are expiring within 30 days",
            self.get_test_results(self.pingfederate, Categories.pod_status).keys(),
        )

    @unittest.skip("Skipping until check is re-enabled, ref: PDO-5015, PDO-5026")
    def test_health_check_has_authenticate_a_user_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.connectivity)
        test_name = "Can authenticate a user"
        self.assertTrue(
            test_name in test_results,
            f"No '{test_name}' checks found in health check results",
        )

    @unittest.skip("Skipping until check is re-enabled, ref: PDO-5015, PDO-5026")
    def test_health_check_has_create_an_object_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.connectivity)
        test_name = "Can create an object in PF Admin"
        self.assertTrue(
            test_name in test_results,
            f"No '{test_name}' checks found in health check results",
        )

    def test_health_check_has_pingdirectory_connection_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.connectivity)
        test_results = " ".join(test_results.keys())
        expected_test_patterns = [
            f"{pod_name} can connect to datastore pingdirectory"
            for pod_name in self.pod_names
        ]
        if self.assertTrue(len(expected_test_patterns) > 0):
            for expected_test in expected_test_patterns:
                with self.subTest(expected_test):
                    self.assertRegex(
                        test_results,
                        expected_test,
                        f"No '{expected_test}' checks found in health check results",
                    )

    def test_admin_api_url_uses_service_name_in_primary_region(self):
        self.assert_admin_api_url_uses_service_name(
            "/app/PFVariables.py", "pf_admin_api_host"
        )
