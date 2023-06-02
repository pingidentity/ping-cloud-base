import requests

from health_common import Categories, TestHealthBase, get_variable_value


class TestPingAccessHealth(TestHealthBase):
    deployment_name = "healthcheck-pingaccess"
    pingaccess = "pingAccess"
    pod_name_pattern = "healthcheck-pingaccess-[0-9a-zA-Z]{4,}-.+"
    admin_configmap_name = "pingaccess-admin-environment-variables"
    admin_service_name_env_var = "K8S_SERVICE_NAME_PINGACCESS_ADMIN"
    admin_port_env_var = "PA_ADMIN_PORT"

    def test_region_env_vars_in_pod(self):
        env_vars = self.get_pod_env_vars(self.health, self.pod_name_pattern)
        for expected_ev in ["REGION=", "TENANT_DOMAIN="]:
            with self.subTest(env_var=expected_ev):
                self.assertTrue(
                    any(env_var.startswith(expected_ev) for env_var in env_vars)
                )

    def test_pingaccess_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_pingaccess_results(self):
        res = requests.get(self.endpoint, verify=False)
        self.assertTrue(
            self.pingaccess in res.json()["health"].keys(),
            f"No {self.pingaccess} in health check results",
        )

    def test_health_check_has_registered_results(self):
        test_results = self.get_test_results(self.pingaccess, Categories.pod_status)
        res = [key for key in test_results if "registered" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'registered with PA Admin' checks found in health check results",
        )

    def test_health_check_has_responsive_results(self):
        test_results = self.get_test_results(self.pingaccess, Categories.connectivity)
        res = [key for key in test_results if "responds" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'responds to requests' checks found in health check results",
        )

    def test_health_check_has_create_object_results(self):
        test_results = self.get_test_results(self.pingaccess, Categories.connectivity)
        res = [key for key in test_results if "create an object" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'create an object' checks found in health check results",
        )

    def test_health_check_has_proxy_results(self):
        test_results = self.get_test_results(self.pingaccess, Categories.connectivity)
        res = [key for key in test_results if "proxy an unauthenticated request" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'proxy an unauthenticated request' checks found in health check results",
        )

    def test_admin_api_url_uses_service_name_in_primary_region(self):
        admin_env_vars = self.get_configmap_values(
            self.ping_cloud, self.admin_configmap_name
        )
        admin_service_name = admin_env_vars.get(self.admin_service_name_env_var)
        admin_port = admin_env_vars.get(self.admin_port_env_var)
        expected = f"{admin_service_name}.{self.ping_cloud}:{admin_port}"

        variables = self.run_python_script_in_pod(
            self.health, self.pod_name_pattern, "/app/PAVariables.py"
        )
        pa_admin_api_host = get_variable_value(variables, "pa_admin_api_host=")

        self.assertEqual(expected, pa_admin_api_host)
