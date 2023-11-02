import os
import time
import unittest

import seleniumbase
import p1_test_base

import pingone_ui as p1_ui

@unittest.skipIf(os.environ.get('ENV_TYPE') == "customer-hub", "Customer-hub CDE detected, skipping test module")
class TestPFAdminSSO(seleniumbase.BaseCase, p1_test_base.P1TestBase):
    pf_admin_public_hostname = os.getenv(
        "PF_ADMIN_PUBLIC_HOSTNAME",
        f"https://pingfederate-admin-{os.environ['BELUGA_ENV_NAME']}.{os.environ['TENANT_DOMAIN']}",
    )

    def setUp(self, masterqa_mode=False):
        # This line is needed when overriding seleniumbase.BaseCase.setUp()
        super(TestPFAdminSSO, self).setUp()
        # Add any pre-test setup here
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.environment = os.getenv("ENV", "dev")
        self.group_names = [
            f"{self.tenant_name}-{self.environment}-pf-roleadmin",
            f"{self.tenant_name}-{self.environment}-pf-crypto",
            f"{self.tenant_name}-{self.environment}-pf-useradmin",
            f"{self.tenant_name}-{self.environment}-pf-expression",
            f"{self.tenant_name}-{self.environment}-pf-audit",
        ]
        self.app_name = f"client-{self.tenant_name}-${self.environment}-pingfederate-sso"

    def tearDown(self):
        # This line is needed when overriding seleniumbase.BaseCase.tearDown()
        super(TestPFAdminSSO, self).tearDown()
        # Add any post-test setup here

    def test_groups_created(self):
        for group_name in self.group_names:
            with self.subTest(msg=f"{group_name} created"):
                p1_group = self.get_p1_endpoint(self.cluster_env_endpoints.groups, group_name)
                self.assertIsNotNone(p1_group, f"Group '{group_name}' not created")

    def test_app_created(self):
        p1_app = self.get_p1_endpoint(self.cluster_env_endpoints.applications, self.app_name)
        self.assertIsNotNone(p1_app, f"Application '{self.app_name}' not created")

    def pingone_login(self):
        username = "PingFederateAdmin"
        old_password = "2FederateM0re!"
        new_password = "TestNewPassword1!"
        self.open(p1_ui.admin_env_ui_url)
        self.type("#username", username)
        self.type("#password", old_password)
        self.click('button[data-id="submit-button"]')
        timeout = time.time() + 10.0
        while time.time() < timeout:
          # Password has already been changed
          if self.is_text_visible(text="Incorrect username or password."):
              self.type("#username", username)
              self.type("#password", new_password)
              self.click('button[data-id="submit-button"]')
              break
          # Change password screen
          elif self.is_text_visible(text="Change Password", selector="h1"):
              self.type("#password", old_password)
              self.type("#new", new_password)
              self.type("#verify", new_password)
              self.click('button[data-id="submit-button"]')
              break
        self.wait_for_element_present('img[src="images/ping-identity-white.svg"]',timeout=30)
        # "Welcome To Ping" pop-up for first time login
        if self.is_element_visible('button[data-id="guide-close-button"]'):
            self.click('button[data-id="guide-close-button"]')
    
    @unittest.skip("Skipping until PDO-4904")
    def test_pf_admin_user_can_log_in_to_admin_environment(self):
        self.pingone_login()
        # The content frame on the home page displays the list of environments
        self.save_screenshot_to_logs()
        self.switch_to_frame("content-iframe")
        self.assert_text_visible("Your Environments", "div")

    @unittest.skip("Skipping until PDO-4904")
    def test_pf_admin_user_can_access_pf_admin_page(self):
        self.pingone_login()
        # Check if the PF Admin page can be accessed using SSO in a new window
        self.open_new_window()
        self.open(self.pf_admin_public_hostname)
        self.save_screenshot_to_logs()
        if self.is_text_visible("Welcome to PingFederate"):
            self.click('a[data-id="content-link"]')
        self.assert_text_visible("Shortcuts")


if __name__ == "__main__":
    unittest.main()
