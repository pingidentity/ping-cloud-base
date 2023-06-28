import base64
import os
import unittest

import requests
import urllib3

import k8s_utils

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


@unittest.skipIf(os.getenv("PF_PROVISIONING_ENABLED", "false") != "true", "PingFederate provisioning feature disabled")
class TestPingFederateProvisioning(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.k8s = k8s_utils.K8sUtils()

    def setUp(self) -> None:
        pf_admin_api_endpoint = self.k8s.get_endpoint("pingfederate-admin")
        self.data_stores_endpoint = (
            f"{pf_admin_api_endpoint}/pf-admin-api/v1/dataStores"
        )
        self.outbound_provisioning_endpoint = f"{pf_admin_api_endpoint}/pf-admin-api/v1/serverSettings/outboundProvisioning"
        pf_credentials = base64.b64encode(b"administrator:2FederateM0re").decode(
            "ascii"
        )
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

    def test_provisioning_data_store_is_applied_as_outbound_provisioner(self):
        res = requests.get(
            url=self.data_stores_endpoint, verify=False, headers=self.headers
        )
        data_store_id = next(ds["id"] for ds in res.json()["items"] if ds["name"] == self.data_store_name)
        res = requests.get(
            url=self.outbound_provisioning_endpoint, verify=False, headers=self.headers
        )
        provisioner_id = res.json()["dataStoreRef"]["id"]
        self.assertEqual(data_store_id, provisioner_id)


if __name__ == "__main__":
    unittest.main()
