import base64
import unittest

import requests

import k8s_utils


class TestPingFederateProvisioning(k8s_utils.K8sUtils):
    def setUp(self) -> None:
        pf_admin_api_endpoint = self.get_endpoint("pingfederate-admin")
        self.data_stores_endpoint = f"{pf_admin_api_endpoint}/pf-admin-api/v1/dataStores"
        pf_credentials = base64.b64encode(b"administrator:2FederateM0re").decode("ascii")
        self.headers = {
            "Authorization": f"Basic {pf_credentials}",
            "X-XSRF-Header": "PingFederate",
        }
        self.data_store_name = "pf-provisioning"

    def test_provisioning_data_store_exists_in_pingfederate(self):
        res = requests.get(
            url=self.data_stores_endpoint, verify=False, headers=self.headers
        )
        data_stores = [ds["name"] for ds in res.json()["items"]]
        self.assertIn(self.data_store_name, data_stores)


if __name__ == "__main__":
    unittest.main()
