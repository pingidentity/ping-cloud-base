import os
import unittest
import warnings

from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
import urllib3

from k8s_utils import K8sUtils
import pingone_ui as p1_ui
from resources.tls_utils import create_self_signed_cert


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
        cls.product_names = [
            "pingaccess-engines",
            "pingaccess-agents",
            "pingaccess-admin-api",
            "pingfederate-engines",
            "pingfederate-admin-api",
            "pingdirectory",
            "pingdelegator",
        ]
        cls.hostname_suffix = f"tls-ui.{cls.tenant_domain}"
        cls.certname = os.getenv("TENANT_NAME")+"-cert-ui"
        cls.default_fullchain, cls.default_privkey, _ = create_self_signed_cert(
            common_name=f"*.{cls.tenant_domain}")

        # Initialize utils
        cls.k8s_utils = K8sUtils()

        # Create PingOne User
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="SelfServiceUI",
            console_url=cls.self_service_url,
            roles={"p1asSelfServiceRoles": [f"all-tls-admin"]},
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
        cls.wait_time_sec = 5
        cls.wait = WebDriverWait(cls.browser, 30)
        cls.loader_locator = (By.CSS_SELECTOR, 'div[aria-label="Loading in progress"]')

    @classmethod
    def tearDownClass(cls) -> None:
        # Cleanup dependencies
        cls.browser.quit()
    

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


    def wait_for_list_item(
        self, list_container_locator: str, item: str, max_retries: int = 5
    ):
        item_row_locator = (By.CSS_SELECTOR, f'div[role="row"][data-key="{item}"]')
        for attempt in range(1, max_retries + 1):
            try:
                # Wait for the main list container to be visible
                main_list_container = self.wait.until(
                    EC.visibility_of_element_located(list_container_locator)
                )

                # Wait for the item inside container
                WebDriverWait(main_list_container, 5).until(
                    EC.presence_of_element_located(item_row_locator)
                )
                # If found, return
                print(f"Item found on attempt {attempt}")
                return

            except TimeoutException:
                if attempt < max_retries:
                    print(
                        f"Item not found, retrying {attempt}/{max_retries}... refreshing page."
                    )
                    self.browser.refresh()
                else:
                    raise TimeoutException(
                        f"Item not found after {max_retries} retries."
                    )


    def navigate_to_page(self, path: str):
        print(f"Navigating to {path} page")
        nav_btn = self.wait.until(
            EC.element_to_be_clickable((By.ID, f"/self-service/{path}"))
        )
        classes = nav_btn.get_attribute("class")
        if "is-selected" not in classes.split():
            nav_btn.click()
            self.wait_for_loader()


    def open_create_form(self):
        create_btn = self.wait.until(
            EC.element_to_be_clickable((By.ID, "create"))
        )
        create_btn.click()

    
    def select_dropdown_option(self, label_text: str, option_key: str, has_async_loader: bool = False):
        """
        Selects an option from a custom dropdown by its visible label.

        This function simulates a user's actions:
        1. Finds the specific dropdown container by its label text.
        2. Clicks the button to open the options list.
        3. (Optional) Waits for a specific loading indicator within the dropdown to disappear.
        4. Clicks the desired option using its data-key.
        
        Args:
            label_text (str): The text of the label associated with the dropdown (e.g., "Product Mapping").
            option_key (str): The 'data-key' attribute of the option to select (e.g., "pingfederate-engines").
            has_async_loader (bool): True if the dropdown options are loaded asynchronously
                                    and have a 'Loading in progress' indicator.
        """
        print(f"Selecting '{option_key}' for dropdown '{label_text}'.")
        try:
            # Find the specific dropdown container using its label text
            dropdown_container_locator = (By.XPATH, f"//div[@data-pendo-id='SelectField'][.//*[text()='{label_text}']]")
            dropdown_container = self.wait.until(
                EC.presence_of_element_located(dropdown_container_locator)
            )

            # Wait for dropdown options to load
            if has_async_loader:
                print("Waiting for the dropdown options to load...")
                self.wait_for_loader()
                print("Dropdown options have loaded")
            
            # Click the dropdown button, scoped to the container
            dropdown_button_locator = (By.CSS_SELECTOR, 'button[role="button"]')
            dropdown_button = WebDriverWait(dropdown_container, self.wait_time_sec).until(
                EC.element_to_be_clickable(dropdown_button_locator)
            )
            dropdown_button.click()

            # Wait for the options list to appear
            options_list_locator = (By.XPATH, "//div[@role='presentation']")
            self.wait.until(
                EC.presence_of_element_located(options_list_locator)
            )
            
            # Click the required option
            option_locator = (By.XPATH, f"//li[@data-key='{option_key}']")
            selected_option = self.wait.until(
                EC.element_to_be_clickable(option_locator)
            )
            selected_option.click()
            print(f"Successfully selected '{option_key}' for dropdown '{label_text}'.")
        except (TimeoutException, NoSuchElementException) as ex:
            print(f"Error occurred selecting '{option_key}' for dropdown '{label_text}': {ex}")
        except Exception as ex:
            print(f"Unhandled error occurred selecting '{option_key}' for dropdown '{label_text}': {ex}")


    def create_certificate(self):
        print(f"Creating certificate: {self.certname}")
        try:
            # Open the form
            self.open_create_form()

            # Fill the form
            name_input = self.wait.until(EC.presence_of_element_located((By.NAME, "name")))
            fullchain_textarea = self.wait.until(EC.presence_of_element_located((By.NAME, "fullchain")))
            privkey_textarea = self.wait.until(EC.presence_of_element_located((By.NAME, "privkey")))

            name_input.send_keys(self.certname)
            fullchain_textarea.send_keys(self.default_fullchain.rstrip())
            privkey_textarea.send_keys(self.default_privkey.rstrip())

            # Submit the form
            submit_button = self.wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, 'button[type="submit"]')))
            submit_button.click()
            print(f"Certificate created: {self.certname}")
        except (TimeoutException, NoSuchElementException) as ex:
            print(f"Error occurred creating certificate '{self.certname}': {ex}")


    def create_hostname(self, product: str):
        hostname = f"{product}-{self.hostname_suffix}"
        print(f"Creating hostname: {hostname}")
        try:
            # Open the form
            self.open_create_form()

            # Fill the form
            hostname_input = self.wait.until(EC.presence_of_element_located((By.NAME, "hostname")))
            hostname_input.clear() # Make sure field is empty
            hostname_input.send_keys(hostname)

            self.select_dropdown_option(
                label_text="Product Mapping",
                option_key=product
            )

            self.select_dropdown_option(
                label_text="Certificate name",
                option_key=self.certname,
                has_async_loader=True
            )

            # Submit the form
            submit_button = self.wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, 'button[type="submit"]')))
            submit_button.click()
            print(f"Hostname created: {hostname}")
        except (TimeoutException, NoSuchElementException) as ex:
            print(f"Error occurred creating hostname '{hostname}': {ex}")


    def delete_list_item(self, list_container_locator: str, item: str):
        print(f"Deleting item: {item}")
        try:
            # Wait for list container to load
            main_list_container = self.wait.until(
                EC.visibility_of_element_located(list_container_locator)
            )

            # Find the item
            item_row = main_list_container.find_element(By.CSS_SELECTOR, f'div[role="row"][data-key="{item}"]')

            # Click on more options
            more_options_button_locator = (By.CSS_SELECTOR, 'button[aria-label="more options"]')
            more_options_button = WebDriverWait(item_row, self.wait_time_sec).until(
                EC.element_to_be_clickable(more_options_button_locator)
            )
            more_options_button.click()

            # Click on the Delete button
            delete_popup_option_locator = (By.XPATH, "//li[@data-key='delete']/span[text()='Delete']")
            delete_popup_option = self.wait.until(
                EC.element_to_be_clickable(delete_popup_option_locator)
            )
            delete_popup_option.click()

            # Wait for confirmation modal
            modal_locator = (By.CSS_SELECTOR, 'div.generic-modal[role="dialog"]')
            delete_modal = self.wait.until(
                EC.element_to_be_clickable(modal_locator)
            )
            print("Delete confirmation modal appeared.")

            # Check the confirmation checkbox
            checkbox_label_locator = (By.XPATH, "//label[@for='confirm-delete' and contains(., 'I understand and want to continue')]")
            confirm_checkbox_label = WebDriverWait(delete_modal, self.wait_time_sec).until(
                EC.element_to_be_clickable(checkbox_label_locator)
            )
            confirm_checkbox_label.click()

            # Confirm delete
            confirm_delete_button_locator = (By.CSS_SELECTOR, 'button[aria-label="Delete"]')
            confirm_delete_button = WebDriverWait(delete_modal, self.wait_time_sec).until(
                EC.element_to_be_clickable(confirm_delete_button_locator)
            )
            confirm_delete_button.click()
            print(f"Delete successful for item: '{item}'.")
        except (TimeoutException, NoSuchElementException) as ex:
            print(f"Error occurred deleting item '{item}': {ex}")


    def get_item_list(self, list_container_locator: str):
        print("Getting item list")
        list_items = []
        # Wait for the main list container to be visible
        main_list_container = self.wait.until(
            EC.visibility_of_element_located(list_container_locator)
        )

        # Find all rows
        row_divs = main_list_container.find_elements(By.CSS_SELECTOR, 'div[role="row"][data-key]')
        if not row_divs:
            print("No list items found within the container.")
            return []

        # Iterate over rows to get text and subtext
        for row_div in row_divs:
            span_elements = row_div.find_elements(By.TAG_NAME, "span")
            if len(span_elements) == 2:
                list_items.append((span_elements[0].text.strip(), span_elements[1].text.strip()))          

        print("Get item list successfully")
        return list_items

    def test_vhost_creates_successfully(self):
        """
        Test that we can successfully create a vhost for each product
        """
        # Virtual Hosts list locator
        hostname_list_locator = (By.CSS_SELECTOR, 'div[data-testid="Virtual Hosts"]')
        # Secrets list locator
        certificate_list_locator = (By.CSS_SELECTOR, 'div[data-testid="Secrets"]')

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

        # Create certificate
        self.navigate_to_page("secrets")
        self.create_certificate()
        self.browser.refresh()
        self.wait.until(EC.visibility_of_element_located(certificate_list_locator))
        try:
            self.wait_for_list_item(certificate_list_locator, self.certname)
        except:
            pass

        # Create virtual hosts
        self.navigate_to_page("virtual-hosts")
        # Wait for page load
        self.wait.until(EC.visibility_of_element_located(hostname_list_locator))

        print("Creating hostnames")
        ingresses = []
        for product in self.product_names:
            with self.subTest(msg=f"{product} hostname creation failed"):
                self.create_hostname(product)
                self.browser.refresh() # Reset form
                ingresses.append(f"{product}-{self.hostname_suffix}")

        # Check cert is created in k8s
        print("Checking certificate created in k8s")
        with self.subTest(msg=f"Cert {self.certname} not found in cluster"):
            self.k8s_utils.wait_for_secret_event(name=self.certname, event_type="ADDED", namespace=self.namespace)
            cert = self.k8s_utils.get_namespaced_secret(
                name=self.certname,
                namespace=self.namespace,
            )
            self.assertIsNotNone(cert, f"Certificate {self.certname} not found in cluster")

        # Check ingresses are created in k8s
        print(f"Checking ingresses created in k8s")
        with self.subTest(msg=f"vHosts not found in cluster"):
            self.k8s_utils.wait_for_ingress_event(names=ingresses, event_type="ADDED", namespace=self.namespace)
            for product in self.product_names:
                ingress = self.k8s_utils.get_ingress_object(
                    name=f"{product}-{self.hostname_suffix}",
                    namespace=self.namespace,
                )
                self.assertIsNotNone(ingress, f"Ingress {product}-{self.hostname_suffix} not found in cluster")

        # Delete the hostnames
        print("Deleting hostnames")
        self.browser.refresh() # Refresh to make sure all hostnames are visible
        for product in self.product_names:
            with self.subTest(msg=f"vHost for {product} failed to delete via UI"):
                self.wait_for_list_item(hostname_list_locator, f"{product}-{self.hostname_suffix}")
                self.delete_list_item(hostname_list_locator, f"{product}-{self.hostname_suffix}")
                self.browser.refresh()
                self.wait.until(EC.visibility_of_element_located(hostname_list_locator))

                # Check if ingress has been removed from UI
                hostname_list = self.get_item_list(hostname_list_locator)
                self.assertTrue(product not in [h[1] for h in hostname_list], "Failed to delete hostname")

        # Check hostnames are deleted in cluster
        print(f"Checking ingresses deleted from cluster")
        with self.subTest(msg=f"vHosts not deleted from cluster"):
            self.k8s_utils.wait_for_ingress_event(names=ingresses, event_type="DELETED", namespace=self.namespace)
            for product in self.product_names:
                ingress = self.k8s_utils.get_ingress_object(
                    name=f"{product}-{self.hostname_suffix}",
                    namespace=self.namespace,
                )
                self.assertIsNone(ingress, f"Ingress {product}-{self.hostname_suffix} not deleted from cluster")

        # Delete the certificate
        print(f"Deleting certificate {self.certname}")
        self.navigate_to_page("secrets")
        with self.subTest(msg=f"Cert {self.certname} failed to delete via UI"):
            self.delete_list_item(certificate_list_locator, self.certname)

            # Check if certificate has been removed from UI
            certificate_list = self.get_item_list(certificate_list_locator)
            self.assertTrue(self.certname not in [c[1] for c in certificate_list], "Failed to delete certificate")

        # Check the cert is deleted in cluster
        print(f"Checking certificate deleted from cluster")
        with self.subTest(msg=f"Certificate not deleted from cluster"):
            self.k8s_utils.wait_for_secret_event(name=self.certname, event_type="DELETED", namespace=self.namespace)
            cert = self.k8s_utils.get_namespaced_secret(
                name=self.certname,
                namespace=self.namespace,
            )
            self.assertIsNone(cert, f"Certificate {self.certname} not deleted from cluster")
