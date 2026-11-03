import unittest, requests, re

from health_common import Categories, TestHealthBase


class TestClusterHealth(TestHealthBase):
    deployment_name = "healthcheck-cluster-health"
    cluster_health = "clusterHealth"

    def setUp(self):
        self.test_results = self.get_test_results(
            self.cluster_health, Categories.cluster_members
        )

    def test_cluster_health_deployment_exists(self):
        self.deployment_exists()

    def test_health_check_has_cluster_health_results(self):
        res = requests.get(self.healthcheck_endpoint, verify=False)
        self.assertTrue(
            self.cluster_health in res.json()["health"].keys(),
            "No cluster health in health check results",
        )

    # Kept in p1as-eng-base: StatefulSets are not deployed as part of the beluga-tools microservice CI/CD pipeline.
    def test_health_check_has_stateful_set_results(self):
        res = [key for key in self.test_results if "statefulset" in key]
        self.assertTrue(
            len(res) > 0, "No statefulset checks found in health check results"
        )

    # Kept in p1as-eng-base: StatefulSets are not deployed as part of the beluga-tools microservice CI/CD pipeline.
    def test_health_check_has_statefulset_pods_ready_results(self):
        pattern = re.compile("All pods in statefulset [a-z-a-z]+ are Ready")
        self.assertTrue(any(pattern.match(test_name) for test_name in self.test_results.keys()))

    def test_cluster_health_results_published(self):
        """
        Verifies that the cluster-health pod publishes its results to the healthcheck
        service, and that the published product has the expected summary fields and counts
        """
        res = requests.get(self.healthcheck_endpoint, verify=False)
        result = res.json()["health"][self.cluster_health]
        for key in [
            "healthStatus",
            "passedChecks",
            "failedChecks",
            "degradedChecks",
            "tests",
            "lastModified",
        ]:
            self.assertIn(key, result, f"{key} missing from {self.cluster_health} result")
        for key in ["passedChecks", "failedChecks", "degradedChecks"]:
            self.assertIsInstance(result[key], int, f"{key} was not an integer")
            self.assertGreaterEqual(result[key], 0, f"{key} was negative")
        self.assertTrue(
            0 <= float(result["healthStatus"]) <= 100,
            "healthStatus was not between 0-100",
        )

    def test_cluster_health_environment_section(self):
        """
        Verifies that publishing cluster-health results leaves the environment summary
        in the healthcheck response with allowed values
        """
        allowed_env_types = ["dev", "test", "stage", "prod", "customer-hub"]
        allowed_statuses = ["healthy", "degraded", "unhealthy", "initializing"]
        res = requests.get(self.healthcheck_endpoint, verify=False)
        environment = res.json()["health"]["environment"]
        self.assertIn(
            environment["envType"],
            allowed_env_types,
            f"envType was not one of {allowed_env_types}",
        )
        self.assertIn(
            environment["healthStatus"],
            allowed_statuses,
            f"healthStatus was not one of {allowed_statuses}",
        )
        self.assertTrue(
            0 <= float(environment["healthScore"]) <= 100,
            "healthScore was not between 0-100",
        )


if __name__ == "__main__":
    unittest.main()
