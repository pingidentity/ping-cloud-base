import unittest

import requests

from health_common import Categories, TestHealthBase, get_variable_value


class TestPingFederateHealth(TestHealthBase):
    deployment_name = "healthcheck-pingfederate"
    pingfederate = "pingFederate"
    pod_name_pattern = "healthcheck-pingfederate-.+"
    admin_configmap_name = "pingfederate-admin-environment-variables"
    admin_service_name_env_var = "K8S_SERVICE_NAME_PINGFEDERATE_ADMIN"
    admin_port_env_var = "PF_ADMIN_PORT"

    def setUp(self) -> None:
        self.ping_cloud_ns = next((ns for ns in self.get_namespace_names() if ns.startswith(self.ping_cloud)), self.ping_cloud)
        self.pod_names = self.get_namespaced_pod_names(self.ping_cloud_ns, r"pingfederate-(?:|admin-)\d+")

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
        expected_test_patterns = [f"{pod_name} can connect to datastore pingdirectory" for pod_name in self.pod_names]
        if self.assertTrue(len(expected_test_patterns) > 0):
            for expected_test in expected_test_patterns:
                with self.subTest(expected_test):
                    self.assertRegex(
                        test_results,
                        expected_test,
                        f"No '{expected_test}' checks found in health check results",
                    )

    def test_admin_api_url_uses_service_name_in_primary_region(self):
        admin_env_vars = self.get_configmap_values(
            self.ping_cloud, self.admin_configmap_name
        )
        admin_service_name = admin_env_vars.get(self.admin_service_name_env_var)
        admin_port = admin_env_vars.get(self.admin_port_env_var)
        expected = f"{admin_service_name}.{self.ping_cloud}:{admin_port}"

        variables = self.run_python_script_in_pod(
            self.health, self.pod_name_pattern, "/app/PFVariables.py"
        )
        pf_admin_api_host = get_variable_value(variables, "pf_admin_api_host=")

        self.assertEqual(expected, pf_admin_api_host)
