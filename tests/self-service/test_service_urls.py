import os
import unittest
import warnings
from itertools import chain

from kubernetes.client import V1Ingress, V1Service
from pydantic import AnyUrl
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
import urllib3

from k8s_utils import K8sUtils
import pingone_ui as p1_ui


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestTlsUI(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        # Global variables
        cls.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
        cls.tenant_domain = os.getenv("TENANT_DOMAIN")
        cls.self_service_url = f"https://self-service.{cls.tenant_domain}"

        # Initialize utils
        cls.k8s_utils = K8sUtils()

        # Create PingOne User
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="SelfServiceUI",
            console_url=cls.self_service_url,
            roles={"p1asSelfServiceRoles": ["all-tls-audit"]},
            access_granted_xpaths=[],
            access_denied_xpaths=[],
            create_local_only=True,
        )

        # Setup browser
        cls.ui_driver = p1_ui.PingOneUIDriver()
        cls.ui_driver.setup_browser(window_size="1920,1080")
        cls.ui_driver.login(url=cls.config.console_url, username=cls.config.local_user.username, password=cls.config.local_user.password)
        cls.browser = cls.ui_driver.browser

        # Ignore warnings for insecure http requests
        warnings.filterwarnings(
            "ignore", category=urllib3.exceptions.InsecureRequestWarning
        )

        # Set selenium parameters
        cls.wait_time_sec = 10
        cls.wait = WebDriverWait(cls.browser, 30)
        cls.loader_locator = (By.CSS_SELECTOR, 'div[aria-label="Loading in progress"]')

    @classmethod
    def tearDownClass(cls) -> None:
        # Cleanup dependencies
        cls.browser.quit()
    
    def parse_multiple_urls(self, raw: str) -> dict[str, str]:
        items = {}
        if "|" not in raw:
            items[""] = raw
        else:
            for part in raw.split("|"):
                part = part.strip()
                if not part:
                    continue
                key, value = part.split(":", 1)
                items[key.strip()] = value.strip()
        return items

    def get_service_info(self, ingress_obj):
        annotations = ingress_obj.metadata.annotations or {}
        name = annotations.get("self-service.metadata.pingidentity.com/name", "").strip()
        category = annotations.get(
            "self-service.metadata.pingidentity.com/category", ""
        ).strip()
        url_map = self.parse_multiple_urls(
            annotations.get("self-service.metadata.pingidentity.com/displayURL", "")
        )
        desc_map = self.parse_multiple_urls(
            annotations.get("self-service.metadata.pingidentity.com/description", "")
        )

        services = []
        for descriptor, url in url_map.items():
            desc = desc_map.get(descriptor, "")
            service_name = f"{name} {descriptor}" if descriptor else name

            services.append(
                {
                    "name": service_name,
                    "url": url,
                    "category": category,
                    "description": desc,
                }
            )

        return services

    def get_service_connectivity(self, kube_obj):
        connectivity = "private"
        if isinstance(kube_obj, V1Ingress):
            ingress_class = ""
            if hasattr(kube_obj.spec, "ingress_class_name"):
                ingress_class = kube_obj.spec.ingress_class_name
            elif "kubernetes.io/ingress.class" in kube_obj.metadata.annotations:
                ingress_class = kube_obj.metadata.annotations.get(
                    "kubernetes.io/ingress.class"
                )

            if ingress_class == "nginx-public":
                connectivity = "public"
            elif ingress_class == "nginx-private":
                connectivity = "private"
        elif isinstance(kube_obj, V1Service):
            # This service does not have an ingress and is private by default
            connectivity = "private"
        return connectivity
    

    def wait_for_loader(self):
        try:
            WebDriverWait(self.browser, self.wait_time_sec).until(
                EC.presence_of_element_located(self.loader_locator)
            )
            WebDriverWait(self.browser, self.wait_time_sec).until_not(
                EC.presence_of_element_located(self.loader_locator)
            )
        except TimeoutException:
            print("Timeout waiting for page loader")

    def navigate_to_page(self, path: str):
        print(f"Navigating to {path} page")
        nav_btn = self.wait.until(
            EC.element_to_be_clickable((By.ID, f"/self-service/{path}"))
        )
        classes = nav_btn.get_attribute("class")
        if "is-selected" not in classes.split():
            nav_btn.click()
            self.wait_for_loader()

    def get_cards_data(self, service_urls_container, connectivity):
        service_urls = []
        category_blocks = service_urls_container.find_elements(
            By.XPATH, ".//div/details"
        )

        for details in category_blocks:
            category = details.find_element(By.XPATH, "./summary").text.strip()
            cards = details.find_elements(By.XPATH, "./div/div")

            for card in cards:
                name = card.find_element(By.XPATH, "./div/div/span").text.strip()
                assert name, f"Card {card.text}: name is empty"

                description = card.find_element(By.XPATH, "./div/div/p").text.strip()

                url = card.find_element(By.XPATH, "./div/div/a/span").text.strip()
                assert url, f"Card {card.text}: url is empty"
                assert url.startswith(("http://", "https://", "ldaps://"))

                service_urls.append(
                    {
                        "name": name,
                        "url": url,
                        "description": description,
                        "connectivity": connectivity,
                        "category": category,
                    }
                )

        return service_urls

    def test_service_urls_listed_successfully(self):
        """
        Service URLs listed successfully
        """
        # Wait for the Self Service nav link
        self.wait.until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, 'div[data-testid="Self Service"]'))
        )

        # Select the test environment
        env_selector_btn = self.wait.until(
            EC.element_to_be_clickable(
                (By.CSS_SELECTOR, '[data-testid="env-selector"]')
            )
        )
        env_selector_btn.click()
        self.wait.until(
            EC.presence_of_element_located(
                (By.XPATH, '//ul[@aria-label="Environment Selector" and @role="menu"]')
            )
        )
        menu_item = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, '//li[@role="menuitem"]'))
        )
        menu_item.click()
        self.wait.until(
            EC.invisibility_of_element_located(
                (By.XPATH, '//ul[@aria-label="Environment Selector" and @role="menu"]')
            )
        )

        # Navigate to service urls page
        self.navigate_to_page(path="service-urls")
        self.browser.refresh()
        service_urls_container = self.wait.until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, '[data-testid="service-urls-container"]')
            )
        )
        self.wait_for_loader()

        ingresses = self.k8s_utils.network_client.list_namespaced_ingress(
            namespace=self.namespace,
            label_selector="self-service.urls/managed=true"
        )
        services = self.k8s_utils.core_client.list_namespaced_service(
            namespace=self.namespace,
            label_selector="self-service.urls/managed=true"
        )
        service_labels = []
        for kube_obj in chain(ingresses.items, services.items):
            try:
                services_info = self.get_service_info(kube_obj)
                for service_info in services_info:
                    service_info["connectivity"] = self.get_service_connectivity(kube_obj)
                    service_labels.append(service_info)
            except Exception as ex:
                print(f"Error occurred trying to extract services data from {kube_obj.metadata.name}: {str(ex)}")

        service_urls = []
        print("Get all public URLs")
        service_urls.extend(self.get_cards_data(service_urls_container, "public"))

        print("Navigate to private URLs tab")
        tab_button = self.browser.find_element(
            By.XPATH, '//div[@role="tab" and @data-key="Private"]'
        )
        tab_button.click()
        service_urls_container = self.wait.until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, '[data-testid="service-urls-container"]')
            )
        )

        print("Get all private URLs")
        service_urls.extend(self.get_cards_data(service_urls_container, "private"))

        assert len(service_urls) == len(service_labels), f"Incorrect number of urls displayed. Actual: {len(service_urls)} - Expected: {len(service_labels)}"

        for service_label in service_labels:
            service = next(
                (s for s in service_urls if s["name"] == service_label["name"]), None
            )
            assert service is not None
            assert service_label["category"] == service["category"]
            assert service_label["description"] == service["description"]
            assert service_label["url"] == service["url"]
            assert service_label["connectivity"] == service["connectivity"]
