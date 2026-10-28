import os
import unittest
import warnings

import requests
from os import getenv

import urllib3
from tenacity import retry, stop_after_attempt, wait_fixed


class ClusterEndpointsPreCheck(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        # Ignore warnings for insecure http requests
        warnings.filterwarnings(
            "ignore", category=urllib3.exceptions.InsecureRequestWarning
        )
        tenant_domain = getenv("PRIMARY_TENANT_DOMAIN", "ping-oasis.com")
        cls.domains = [f"metadata.{tenant_domain}", f"self-service-api.{tenant_domain}/docs", f"pingaccess-admin-api.{tenant_domain}/pa-admin-api/api-docs", f"pingaccess-was-admin.{tenant_domain}/pa-admin-api/v3/api-docs/"]

        # Add optional domains
        if os.getenv("HEALTHCHECKS_ENABLED") == "true":
            cls.domains.append(f"healthcheck.{tenant_domain}")

    def test_ingress(self):
        for domain in self.domains:
            with self.subTest(msg=f"{domain} is not available"):
                response = self.get_ingress_response(f"{domain}")
                self.assertEqual(response.status_code, 200)

    @retry(stop=stop_after_attempt(3), wait=wait_fixed(5))
    def get_ingress_response(self, url_base):
        url = f"https://{url_base}"
        print(f"Checking URL: {url}")
        auth = None
        if url_base.startswith("pingaccess-was-admin."):
            auth = ("Administrator", os.getenv("ADMIN_PASS", ""))
        response = requests.get(url, verify=False, timeout=5, auth=auth)
        response.raise_for_status()        
        return response
