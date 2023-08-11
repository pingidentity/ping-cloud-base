import requests, unittest, os

from health_common import Categories, TestHealthBase


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPingDirectoryHealth(TestHealthBase):
    deployment_name = "healthcheck-pingdirectory"
    label = f"role={deployment_name}"
    pingdirectory = "pingDirectory"
    configmap_name = "pingdirectory-environment-variables"
    prometheus_service_name = "prometheus"
    prometheus_namespace = "prometheus"
    prometheus_port = "9090"

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
            "class=pingdirectory-server", self.ping_cloud_ns
        )
        self.env_vars = self.k8s.get_configmap_values(
            self.ping_cloud, self.configmap_name
        )
        self.k8s_cluster_name = f"{self.env_vars.get('CLUSTER_NAME', '')}-{self.env_vars.get('TENANT_NAME')}-{self.env_vars.get('REGION')}"

    def prometheus_test_patterns_by_pod(self, query: str):
        # baseDN pattern (k8s-cluster-name pingdirectory-N example.com query)
        patterns = [
            rf"{self.k8s_cluster_name} {name} \w+\.*\w+ {query}"
            for name in self.pod_names
        ]
        # appintegrations pattern (k8s-cluster-name pingdirectory-N o_appintegrations_query)
        patterns += [
            f"{self.k8s_cluster_name} {name} o_appintegrations_{query}"
            for name in self.pod_names
        ]
        return patterns

    def test_pingdirectory_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_pingdirectory_results(self):
        res = requests.get(self.healthcheck_endpoint, verify=False)
        self.assertIn(
            self.pingdirectory,
            res.json()["health"].keys(),
            f"No {self.pingdirectory} in health check results",
        )

    def test_health_check_has_prometheus_ready_results(self):
        test_results = self.get_test_results(self.pingdirectory, Categories.data)
        expected = "Prometheus is ready"
        self.assertIn(
            expected,
            test_results.keys(),
            f"No '{expected}' checks found in health check results",
        )

    def test_health_check_has_replica_backlog_count_results(self):
        test_results = self.get_test_results(self.pingdirectory, Categories.data)
        test_results = " ".join(test_results.keys())
        expected_test_patterns = self.prometheus_test_patterns_by_pod("replica_backlog")
        for expected_test in expected_test_patterns:
            with self.subTest(expected_test):
                self.assertRegex(
                    test_results,
                    expected_test,
                    f"No '{expected_test}' checks found in health check results",
                )

    def test_health_check_has_failed_replayed_updates_results(self):
        test_results = self.get_test_results(self.pingdirectory, Categories.data)
        test_results = " ".join(test_results.keys())
        expected_test_patterns = self.prometheus_test_patterns_by_pod(
            "replica_failed_replayed_updates"
        )
        for expected_test in expected_test_patterns:
            with self.subTest(expected_test):
                self.assertRegex(
                    test_results,
                    expected_test,
                    f"No '{expected_test}' checks found in health check results",
                )

    def test_health_check_has_unresolved_naming_conflicts_results(self):
        test_results = self.get_test_results(self.pingdirectory, Categories.data)
        test_results = " ".join(test_results.keys())
        expected_test_patterns = self.prometheus_test_patterns_by_pod(
            "replica_unresolved_naming_conflicts"
        )
        for expected_test in expected_test_patterns:
            with self.subTest(expected_test):
                self.assertRegex(
                    test_results,
                    expected_test,
                    f"No '{expected_test}' checks found in health check results",
                )

    def test_prometheus_url_uses_service_name_in_primary_region(self):
        expected = f"{self.prometheus_service_name}.{self.prometheus_namespace}:{self.prometheus_port}"

        prometheus_service_endpoint = self.get_runtime_value_from_pod(
            self.health,
            self.label,
            "/app/PrometheusVariables.py",
            "prometheus_service_endpoint",
        )

        self.assertEqual(expected, prometheus_service_endpoint)
