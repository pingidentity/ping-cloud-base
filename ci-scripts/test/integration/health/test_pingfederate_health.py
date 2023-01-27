import requests

from health_common import Categories, TestHealthBase


class TestPingFederateHealth(TestHealthBase):
    job_name = "healthcheck-pingfederate"
    pingfederate = "pingFederate"

    def setUp(self) -> None:
        self.ping_cloud_ns = next((ns for ns in self.get_namespace_names() if ns.startswith(self.ping_cloud)), self.ping_cloud)
        self.pod_names = self.get_namespaced_pod_names(self.ping_cloud_ns, r"pingfederate-(?:|admin-)\d+")

    def test_pingfederate_health_cron_job_exists(self):
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

    def test_health_check_has_certificate_results(self):
        self.assertIn(
            "No certificates are expiring within 30 days",
            self.get_test_results(self.pingfederate, Categories.pod_status).keys(),
        )

    def test_health_check_has_authenticate_a_user_results(self):
        test_results = self.get_test_results(self.pingfederate, Categories.connectivity)
        test_name = "Can authenticate a user"
        self.assertTrue(
            test_name in test_results,
            f"No '{test_name}' checks found in health check results",
        )

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