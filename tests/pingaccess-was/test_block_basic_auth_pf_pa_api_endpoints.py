import os
import unittest
import urllib3
import requests
from requests.auth import HTTPBasicAuth
from kubernetes import client, config, stream

# The following conditions don't really matter for this test:
# 1) Username / Password
# 2) Including header: 'x-xsrf-header: PingFederate' or 'x-xsrf-header: PingAccess' which is mandatory by PF and PA API.
# The reason being is PingAccess-WAS will be blocking the request before it ever gets to PingFederate or PingAccess
USERNAME = "fakeadmin"
PASSWORD = "test123"

SOME_SNIPPET_OF_PAWAS_HTML_ERROR_PAGE = "<p>The requested URL was not found on this server.</p>"

class TestItem404(unittest.TestCase):
    """Verify each API endpoint returns a 404 and the expected HTML."""

    @classmethod
    def setUpClass(cls):
        # Disable only InsecureRequestWarning warnings
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        # ----------------------------
        # Kubernetes Pre-Test Setup
        # ----------------------------
        # Load the Kubernetes configuration and set the active context to desired
        config.load_kube_config()
        cls.core_v1 = client.CoreV1Api()

    def setUp(self):

        self.namespace = os.environ.get("PING_CLOUD_NAMESPACE")
        self.assertIsNotNone(self.namespace, "PING_CLOUD_NAMESPACE is None")

        # Get PingAccess Admin Environment Variables ConfigMap
        # Assert that the configmap is truthy (i.e., not None and not an empty string)
        pingaccess_admin_environment_variables_configmap = self.get_configmap("pingaccess-admin-environment-variables")
        self.assertTrue(pingaccess_admin_environment_variables_configmap, "Unable to retrieve configmap pingaccess-admin-environment-variables")

        # Get PingAccess Admin URL e.g. https://pingaccess-admin.customerName.dev.ping-demo.com
        PA_ADMIN_PUBLIC_HOSTNAME = pingaccess_admin_environment_variables_configmap.data.get('PA_ADMIN_PUBLIC_HOSTNAME')
        self.assertIsNotNone(PA_ADMIN_PUBLIC_HOSTNAME, "PA_ADMIN_PUBLIC_HOSTNAME is None")
        self.assertNotEqual(PA_ADMIN_PUBLIC_HOSTNAME, "", "PA_ADMIN_PUBLIC_HOSTNAME is empty")

        # Get PingFederate Admin Environment Variables ConfigMap
        # Assert that the configmap is truthy (i.e., not None and not an empty string)
        pingfederate_admin_environment_variables_configmap = self.get_configmap("pingfederate-admin-environment-variables")
        self.assertTrue(pingfederate_admin_environment_variables_configmap, "Unable to retrieve configmap pingfederate-admin-environment-variables")

        # Get PingFederate Admin URL e.g. https://pingfederate-admin.customerName.dev.ping-demo.com
        PF_ADMIN_PUBLIC_HOSTNAME = pingfederate_admin_environment_variables_configmap.data.get('PF_ADMIN_PUBLIC_HOSTNAME')
        self.assertIsNotNone(PF_ADMIN_PUBLIC_HOSTNAME, "PF_ADMIN_PUBLIC_HOSTNAME is None")
        self.assertNotEqual(PF_ADMIN_PUBLIC_HOSTNAME, "", "PF_ADMIN_PUBLIC_HOSTNAME is empty")

        # Use any PingAccess and PingFederate API endpoints for this test.
        self.API_TARGETS = [f"https://{PA_ADMIN_PUBLIC_HOSTNAME}/pa-admin-api/v3/rules",
                            f"https://{PF_ADMIN_PUBLIC_HOSTNAME}/pf-admin-api/v1/keyPairs"]

    def get_configmap(self, configmap_name):
        return self.core_v1.read_namespaced_config_map(name=configmap_name, namespace=self.namespace)

    def test_item_endpoints_return_404(self):

        # Build Basic Auth HTTP
        auth = HTTPBasicAuth(USERNAME, PASSWORD)

        for url in self.API_TARGETS:
            url = url.strip()  # in case spaces sneak in
            with self.subTest(url=url):
                resp = requests.get(url, auth=auth, timeout=10, verify=False)

                # 1) Verify PA-WAS presented 404 status code
                self.assertEqual(
                    resp.status_code, 404,
                    f"{url} should return HTTP 404"
                )

                # 2) Verify PA-WAS html page contained small error snippet
                self.assertIn(
                    SOME_SNIPPET_OF_PAWAS_HTML_ERROR_PAGE, resp.text,
                    f"{url} should contain the 404 paragraph"
                )


if __name__ == "__main__":
    unittest.main()