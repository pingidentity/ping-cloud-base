import unittest

import kubernetes as k8s
import requests

from k8s_utils import K8sUtils


class TestClusterHealth(K8sUtils):
    job_name = "healthcheck-cluster-health"
    cluster_health = "cluster-health"
    cluster_members = "cluster-members"
    PASS = "PASS"
    FAIL = "FAIL"

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.run_job(cls.job_name)

    def create_namespace(self, name: str):
        self.core_client.create_namespace(
            k8s.client.V1Namespace(metadata=k8s.client.V1ObjectMeta(name=name))
        )

    def delete_namespace(self, name: str):
        self.core_client.delete_namespace(name=name)

    def get_test_results(self, suite: str, category: str) -> {}:
        """
        Request test results from the healthcheck service and get a dictionary of the test names and PASS/FAIL result
        :param suite: Test suite
        :param category: Category within the test suite
        :return: Test results dictionary in the format {"test name": "PASS/FAIL", ...}
        """
        response = requests.get(self.endpoint, verify=False)
        return response.json()["health"][suite]["tests"][category]

    def test_cluster_health_cron_job_exists(self):
        cron_jobs = self.batch_client.list_cron_job_for_all_namespaces()
        cron_job_name = next(
            (
                cron_job.metadata.name
                for cron_job in cron_jobs.items
                if cron_job.metadata.name == self.job_name
            ),
            "",
        )
        self.assertEqual(
            self.job_name,
            cron_job_name,
            f"Cron job '{self.job_name}' not found in cluster",
        )

    def test_health_check_has_cluster_health_results(self):
        res = requests.get(self.endpoint, verify=False)
        self.assertTrue(
            self.cluster_health in res.json()["health"].keys(),
            "No cluster health in health check results",
        )

    def test_health_check_has_namespace_results(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        res = [key for key in test_results if "namespace" in key]
        self.assertTrue(
            len(res) > 0, "No namespace checks found in health check results"
        )

    def test_health_check_has_node_results(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        res = [key for key in test_results if "node" in key]
        self.assertTrue(len(res) > 0, "No node checks found in health check results")

    def test_health_check_has_stateful_set_results(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        res = [key for key in test_results if "statefulset" in key]
        self.assertTrue(
            len(res) > 0, "No statefulset checks found in health check results"
        )

    def test_unapproved_namespace_detected(self):
        self.create_namespace("test-namespace")
        self.run_job(self.job_name)
        self.delete_namespace("test-namespace")
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(self.FAIL, test_results["No unapproved namespaces are present"])

    def test_all_namespaces_exist(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(self.PASS, test_results["All required namespaces are present"])

    def test_all_pods_running_in_a_namespace(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(
            self.PASS, test_results["All pods in namespace health are running"]
        )

    def test_all_nodes_ready(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(self.PASS, test_results["All nodes in cluster are Ready"])

    def test_node_without_disk_pressure(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(
            self.PASS, test_results["No nodes in cluster are experiencing Disk Pressure"]
        )

    def test_node_without_memory_pressure(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(
            self.PASS, test_results["No nodes in cluster are experiencing Memory Pressure"]
        )

    def test_node_without_pid_pressure(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(
            self.PASS, test_results["No nodes in cluster are experiencing PID Pressure"]
        )

    def test_all_pods_ready_in_statefulset(self):
        test_results = self.get_test_results(self.cluster_health, self.cluster_members)
        self.assertEqual(
            self.PASS, test_results["All pods in statefulset pingdirectory are Ready"]
        )


if __name__ == "__main__":
    unittest.main()
