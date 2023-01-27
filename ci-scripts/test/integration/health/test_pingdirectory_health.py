import requests

from health_common import Categories, TestHealthBase


class TestPingDirectoryHealth(TestHealthBase):
    job_name = "healthcheck-pingdirectory"
    pingdirectory = "pingDirectory"

    def setUp(self) -> None:
        self.ping_cloud_ns = next((ns for ns in self.get_namespace_names() if ns.startswith(self.ping_cloud)), self.ping_cloud)
        self.pod_names = self.get_namespaced_pod_names(self.ping_cloud_ns, r"pingdirectory-\d+")

    def prometheus_test_patterns_by_pod(self, query: str):
        # baseDN pattern (pingdirectory-N example.com query)
        patterns = [rf"{name} \w+\.*\w+ {query}" for name in self.pod_names]
        # appintegrations pattern (pingdirectory-N o_appintegrations_query)
        patterns += [f"{name} o_appintegrations_{query}" for name in self.pod_names]
        return patterns

    def test_pingdirectory_health_cron_job_exists(self):
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

    def test_health_check_has_pingdirectory_results(self):
        res = requests.get(self.endpoint, verify=False)
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
        expected_test_patterns = self.prometheus_test_patterns_by_pod("replica_failed_replayed_updates")
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
        expected_test_patterns = self.prometheus_test_patterns_by_pod("replica_unresolved_naming_conflicts")
        for expected_test in expected_test_patterns:
            with self.subTest(expected_test):
                self.assertRegex(
                    test_results,
                    expected_test,
                    f"No '{expected_test}' checks found in health check results",
                )
