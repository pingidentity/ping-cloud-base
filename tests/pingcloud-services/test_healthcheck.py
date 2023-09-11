import unittest

import requests

from health_common import TestHealthBase


class TestHealthcheck(TestHealthBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.healthcheck_pod_label = "role=pingcloud-healthcheck"

    def test_healthcheck_pod_exists(self):
        pod_name = self.k8s.get_first_matching_pod_name(self.ping_cloud, self.healthcheck_pod_label)
        self.assertIsNotNone(pod_name)

    def test_healthcheck_get_route_ok_response(self):
        res = requests.get(self.healthcheck_endpoint, verify=False)
        self.assertEqual(200, res.status_code)


if __name__ == "__main__":
    unittest.main()
