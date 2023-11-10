import unittest
import requests
from os import getenv
from tenacity import retry, stop_after_attempt, wait_fixed


CI_SCRIPTS_DIR = getenv("SHARED_CI_SCRIPTS_DIR", "/ci-scripts")
SUBDOMAINS = ["healthcheck", "metadata"]


class ClusterEndpointsPreCheck(unittest.TestCase):
    @retry(stop=stop_after_attempt(3), wait=wait_fixed(5))
    def test_ingress(self):
        dns_zone = getenv("PRIMARY_TENANT_DOMAIN", "ping-oasis.com")

        for subdomain in SUBDOMAINS:
            with self.subTest(msg=f"{subdomain} is not available"):
                url = f"https://{subdomain}.{dns_zone}"
                print(f"Checking URL: {url}")
                try:
                    response = requests.get(url, verify=False, timeout=5)
                    response.raise_for_status()
                except requests.exceptions.RequestException as e:
                    self.fail(f"Failed to make GET request to {url}: {e}")

                self.assertEqual(response.status_code, 200)
