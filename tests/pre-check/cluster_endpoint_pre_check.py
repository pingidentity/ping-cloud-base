import unittest
import requests
from os import getenv
from tenacity import retry, stop_after_attempt, wait_fixed

SUBDOMAINS = ["healthcheck", "metadata"]


class ClusterEndpointsPreCheck(unittest.TestCase):
    def test_ingress(self):
        tenant_domain = getenv("PRIMARY_TENANT_DOMAIN", "ping-oasis.com")

        for subdomain in SUBDOMAINS:
            with self.subTest(msg=f"{subdomain}.{tenant_domain} is not available"):
                response = self.get_ingress_response(subdomain, tenant_domain)
                self.assertEqual(response.status_code, 200)

    @retry(stop=stop_after_attempt(3), wait=wait_fixed(5))
    def get_ingress_response(self, subdomain, tenant_domain):
        url = f"https://{subdomain}.{tenant_domain}"
        print(f"Checking URL: {url}")
        response = None
        response = requests.get(url, verify=False, timeout=5)
        response.raise_for_status()        
        return response
