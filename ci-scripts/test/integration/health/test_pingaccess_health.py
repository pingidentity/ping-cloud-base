import requests

from health_common import Categories, TestHealthBase


class TestPingAccessHealth(TestHealthBase):
    job_name = "healthcheck-pingaccess"
    pingaccess = "pingAccess"

    def test_pingaccess_health_cron_job_exists(self):
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
        test_results = self.get_test_results(
            self.pingaccess, Categories.connectivity
        )
        res = [key for key in test_results if "create an object" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'create an object' checks found in health check results",
        )

    def test_health_check_has_proxy_results(self):
        test_results = self.get_test_results(
            self.pingaccess, Categories.connectivity
        )
        res = [key for key in test_results if "proxy an unauthenticated request" in key]
        self.assertTrue(
            len(res) > 0,
            "No 'proxy an unauthenticated request' checks found in health check results",
        )