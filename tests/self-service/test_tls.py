import os
import unittest
import warnings
from typing import List

import kubernetes
import requests
import chromedriver_autoinstaller
from selenium import webdriver
from selenium.webdriver.common.by import By
import urllib3

from k8s_utils import K8sUtils
import pingone_ui as p1_ui
from resources.tls_utils import create_self_signed_cert


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestTlsBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        # Global variables
        cls.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
        cls.tenant_domain = os.getenv("TENANT_DOMAIN")
        cls.api_prefix = "/api/v1"
        cls.self_service_url = f"https://self-service-api.{cls.tenant_domain}"
        cls.product_names = [
            "pingaccess-engines",
            "pingaccess-agents",
            "pingaccess-admin-api",
            "pingfederate-engines",
            "pingfederate-admin-api",
            "pingdirectory",
            "pingdelegator",
        ]
        cls.hostname_suffix = f"tls.{cls.tenant_domain}"
        cls.certname = os.getenv("TENANT_NAME")+"-cert"
        cls.default_fullchain, cls.default_privkey, _ = create_self_signed_cert(
            common_name=f"*.{cls.tenant_domain}")

        # Initialize utils
        cls.k8s_utils = K8sUtils()

        # Create PingOne User
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="SelfService",
            console_url=f"{cls.self_service_url}/api/v1/auth/login",
            roles={"p1asSelfServiceRoles": [f"all-tls-admin"]},
            access_granted_xpaths=[],
            access_denied_xpaths=[],
            create_local_only=True,
        )

        # Setup dependencies
        chromedriver_autoinstaller.install()
        # Ignore warnings for insecure http requests
        warnings.filterwarnings(
            "ignore", category=urllib3.exceptions.InsecureRequestWarning
        )

        # Get authentication token and set header
        options = webdriver.ChromeOptions()
        # Ignore certificate error warning page from chrome
        options.add_argument("--ignore-ssl-errors=yes")
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--headless=new")  # run in headless mode in CICD
        options.add_argument("--no-sandbox")  # run in Docker
        options.add_argument("--disable-dev-shm-usage")  # run in Docker
        cls.browser = webdriver.Chrome(options=options)
        cls.browser.implicitly_wait(60)
        # Go to login page
        cls.browser.get(cls.config.console_url)
        cls.browser.find_element(By.ID, "username").send_keys(cls.config.local_user.username)
        cls.browser.find_element(By.ID, "password").send_keys(cls.config.local_user.password)
        cls.browser.find_element(
            By.CSS_SELECTOR, 'button[data-id="submit-button"]'
        ).click()
        # Get token and set header
        token = cls.browser.find_element(By.ID, "id-token").get_attribute(
            "textContent"
        )
        cls.headers = {"Authorization": f"Bearer {token}"}

    @classmethod
    def tearDownClass(cls) -> None:
        # Cleanup dependencies
        cls.browser.quit()

    def wait_for_ingress_event(self, names: List, event_type: str = "ADDED", namespace: str = "", timeout_seconds: int = 60):
        """
        Waits for the creation of a Kubernetes secret in a specific namespace.

        :param str names: The Kubernetes resource names.
        :param str event_type: The type of event to wait for.
        :param str namespace: The namespace for the resource
        :param int timeout_seconds: The number of seconds to wait for the resource to be created.
        """
        w = kubernetes.watch.Watch()
        names_left_to_check = names.copy()
        for event in w.stream(
                func=self.k8s_utils.network_client.list_namespaced_ingress,
                namespace=namespace,
                timeout_seconds=timeout_seconds,
        ):
            if event["object"].metadata.name in names_left_to_check and (
                    event["type"] == event_type
            ):
                names_left_to_check.remove(event["object"].metadata.name)

            if not names_left_to_check:
                w.stop()

    def test_vhost_creates_successfully(self):
        """
        Test that we can successfully create a vhost for each product
        """
        # create the certificate
        print(f"Creating certificate {self.certname}")
        data = {
            "fullchain": self.default_fullchain,
            "privkey": self.default_privkey,
            "name": self.certname,
        }
        response = requests.post(
            url=f"{self.self_service_url}{self.api_prefix}/certificates",
            json=data,
            headers=self.headers,
            verify=False,
        )

        # check the api response
        self.assertEqual(response.status_code, 201,
                         f"API Failed to create certificate with error: {response.json()}")
        content = response.json()
        self.assertEqual(content["name"], self.certname, f"API response does not contain the correct certname: {content}")

        # Create the hostnames for each product
        ingresses = []
        for product in self.product_names:
            print(f"Creating hostname for {product}")
            with self.subTest(msg=f"{product} hostname creation failed"):
                # create the hostname
                hostname = f"{product}-{self.hostname_suffix}"
                data = {
                    "certname": self.certname,
                    "hostname": hostname,
                    "product": product,
                }
                response = requests.post(
                    url=f"{self.self_service_url}{self.api_prefix}/hostnames",
                    json=data,
                    headers=self.headers,
                    verify=False,
                )

                # check the api response
                self.assertEqual(response.status_code, 201,
                             f"API Failed to create hostname with error: {response.json()}")
                content = response.json()
                self.assertEqual(content["hostname"], data["hostname"],
                                 f"API response does not contain the correct hostname: {content}")
                self.assertEqual(content["product"], data["product"],
                                 f"API response does not contain the correct product: {content}")
                self.assertEqual(content["certname"], data["certname"],
                                 f"API response does not contain the correct certname: {content}")

                ingresses.append(hostname)

        # check cert is created in k8s
        print("Checking certificate created in k8s")
        with self.subTest(msg=f"Cert {self.certname} not found in cluster"):
            self.k8s_utils.wait_for_secret_event(name=self.certname, event_type="ADDED", namespace=self.namespace)
            cert = self.k8s_utils.get_namespaced_secret(
                name=self.certname,
                namespace=self.namespace,
            )
            self.assertIsNotNone(cert, f"Certificate {self.certname} not found in cluster")

        # check ingresses are created in k8s
        print(f"Checking ingresses created in k8s")
        with self.subTest(msg=f"vHosts not found in cluster"):
            self.wait_for_ingress_event(names=ingresses, event_type="ADDED", namespace=self.namespace)
            for product in self.product_names:
                ingress = self.k8s_utils.get_ingress_object(
                    name=f"{product}-{self.hostname_suffix}",
                    namespace=self.namespace,
                )
                self.assertIsNotNone(ingress, f"Ingress {product}-{self.hostname_suffix} not found in cluster")

        # delete the hostnames
        for product in self.product_names:
            print(f"Deleting hostname for {product}")
            with self.subTest(msg=f"vHost for {product} failed to delete via API"):
                response = requests.delete(
                    url=f"{self.self_service_url}{self.api_prefix}/hostnames/{product}-{self.hostname_suffix}",
                    headers=self.headers,
                    verify=False,
                )

                # check the api response
                self.assertEqual(response.status_code,204, f"API Failed to delete hostname with error: {response}")

        # delete the certificate
        print(f"Deleting certificate {self.certname}")
        with self.subTest(msg=f"Cert {self.certname} failed to delete via API"):
            response = requests.delete(
                url=f"{self.self_service_url}{self.api_prefix}/certificates/{self.certname}?force_delete=true",
                headers=self.headers,
                verify=False,
            )

            # check the api response
            self.assertEqual(response.status_code, 204, f"API Failed to delete certificate with error: {response}")

        # check hostnames are deleted in cluster
        print(f"Checking ingresses deleted from cluster")
        with self.subTest(msg=f"vHosts not deleted from cluster"):
            self.wait_for_ingress_event(names=ingresses, event_type="DELETED", namespace=self.namespace)
            for product in self.product_names:
                ingress = self.k8s_utils.get_ingress_object(
                    name=f"{product}-{self.hostname_suffix}",
                    namespace=self.namespace,
                )
                self.assertIsNone(ingress, f"Ingress {product}-{self.hostname_suffix} not deleted from cluster")

        # check the cert is deleted in cluster
        print(f"Checking certificate deleted from cluster")
        with self.subTest(msg=f"Certificate not deleted from cluster"):
            self.k8s_utils.wait_for_secret_event(name=self.certname, event_type="DELETED", namespace=self.namespace)
            cert = self.k8s_utils.get_namespaced_secret(
                name=self.certname,
                namespace=self.namespace,
            )
            self.assertIsNone(cert, f"Certificate {self.certname} not deleted from cluster")