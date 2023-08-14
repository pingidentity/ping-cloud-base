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

    def test_health_check_has_namespace_results(self):
        res = [key for key in self.test_results if "namespace" in key]
        self.assertTrue(
            len(res) > 0, "No namespace checks found in health check results"
        )

    def test_health_check_has_node_results(self):
        res = [key for key in self.test_results if "node" in key]
        self.assertTrue(len(res) > 0, "No node checks found in health check results")

    def test_health_check_has_stateful_set_results(self):
        res = [key for key in self.test_results if "statefulset" in key]
        self.assertTrue(
            len(res) > 0, "No statefulset checks found in health check results"
        )

    def test_health_check_has_unapproved_namespaces_results(self):
        self.assertIn("No unapproved namespaces are present", self.test_results.keys())

    def test_health_check_has_required_namespaces_results(self):
        self.assertIn("All required namespaces are present", self.test_results.keys())

    def test_health_check_has_pods_running_results(self):
        self.assertIn(
            "All pods in namespace health are running", self.test_results.keys()
        )

    def test_health_check_has_nodes_ready_results(self):
        self.assertIn("All nodes in cluster are Ready", self.test_results.keys())

    def test_health_check_has_node_disk_pressure_results(self):
        self.assertIn(
            "No nodes in cluster are experiencing Disk Pressure",
            self.test_results.keys(),
        )

    def test_health_check_has_node_memory_pressure_results(self):
        self.assertIn(
            "No nodes in cluster are experiencing Memory Pressure",
            self.test_results.keys(),
        )

    def test_health_check_has_node_pid_pressure_results(self):
        self.assertIn(
            "No nodes in cluster are experiencing PID Pressure",
            self.test_results.keys(),
        )

    def test_health_check_has_statefulset_pods_ready_results(self):
        pattern = re.compile("All pods in statefulset [a-z-a-z]+ are Ready")
        self.assertTrue(any(pattern.match(test_name) for test_name in self.test_results.keys()))



if __name__ == "__main__":
    unittest.main()
