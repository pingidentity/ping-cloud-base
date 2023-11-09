import unittest
import requests
from os import getenv

class CicdPreCheckTests(unittest.TestCase):
    def test_ingress(self):
        dns_zone = getenv("DNS_ZONE", "ping-demo.com")
        subdomains = [
            "healthcheck",
            "metadata"
        ]
        for subdomain in subdomains:
            url = f"https://{subdomain}.{dns_zone}"
            try:
                response = requests.get(url, verify=False)
                response.raise_for_status()
            except requests.exceptions.RequestException as e:
                self.fail(f"Failed to make GET request to {url}: {e}")

            self.assertEqual(response.status_code, 200)