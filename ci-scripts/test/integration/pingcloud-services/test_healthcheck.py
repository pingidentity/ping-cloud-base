import unittest

import requests

from k8s_utils import K8sUtils


class TestHealthcheck(K8sUtils):
    def test_healthcheck_pod_exists(self):
        pods = self.core_client.list_pod_for_all_namespaces(watch=False)
        res = next(
            (
                pod.metadata.name
                for pod in pods.items
                if pod.metadata.name.startswith("pingcloud-healthcheck")
            ),
            False,
        )
        self.assertTrue(res)

    def test_healthcheck_get_route_ok_response(self):
        res = requests.get(self.endpoint, verify=False)
        self.assertEqual(200, res.status_code)


if __name__ == "__main__":
    unittest.main()
