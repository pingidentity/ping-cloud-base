import unittest
import requests
from os import getenv

class CicdPreCheckTests(unittest.testcase):
    def test_ingress(self):
        dns_zone = getenv("DNS_ZONE", "ping-demo.com")
        subdomains = [
            "healthcheck",
            "metadata",
            "pingaccess-admin-api",
            "pingaccess-agent",
            "pingaccess",
            "pingaccess-was-admin"
            "pingaccess-admin",
            "pingdelegator",
            "pingdirectory",
            "pingfederate-admin-api",
            "pingfederate"
        ]
        for subdomain in subdomains:
            url = f"https://{subdomain}.{dns_zone}"
            try:
                response = requests.get(url)
                response.raise_for_status()
            except requests.exceptions.RequestException as e:
                self.fail(f"Failed to make GET request to {url}: {e}")

            self.assertEqual(response.status_code, 200)