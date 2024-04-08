import os
import unittest

from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.common.by import By

from pingone import common as p1_utils
import pingone_ui as p1_ui


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPingFederateUILogin(p1_ui.ConsoleUILoginTestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.public_hostname = os.getenv(
            "PINGFEDERATE_ADMIN_PUBLIC_HOSTNAME",
            f"https://pingfederate-admin.{os.environ['TENANT_DOMAIN']}",
        )
        cls.username = f"sso-pingfederate-test-user-{cls.tenant_name}"
        cls.password = "2FederateM0re!"
        cls.delete_pingone_user()
        cls.create_pingone_user()
        cls.group_names = [
            f"{cls.tenant_name}-{cls.environment}-pf-roleadmin",
            cls.tenant_name,
        ]
        for group in cls.group_names:
            p1_utils.add_group_to_user(
                token_session=cls.p1_session,
                endpoints=cls.p1_environment_endpoints,
                user_name=cls.username,
                group_name=group,
            )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        cls.delete_pingone_user()

    def test_user_can_access_pingfederate_admin_console(self):
        # Wait for admin console to be reachable if it has been restarted by another test
        self.wait_until_url_is_reachable(self.public_hostname)
        # Attempt to access the console with SSO
        self.pingone_login()
        self.browser.get(self.public_hostname)
        self.browser.implicitly_wait(10)
        try:
            try:
                # This pop-up may or may not be displayed
                if self.browser.find_element(By.XPATH, "//span[contains(text(), 'Welcome to PingFederate')]"):
                    self.browser.find_element(By.CSS_SELECTOR, 'a[data-id="content-link"]').click()
            except NoSuchElementException:
                pass
            cluster = self.browser.find_element(By.XPATH, "//div[contains(text(), 'Cluster')]")
            self.assertTrue(
                cluster.is_displayed(),
                f"PingFederate Admin console 'Cluster' was not displayed when attempting to access {self.public_hostname}. SSO may have failed. Browser contents: {self.browser.page_source}",
            )
        except NoSuchElementException:
            self.fail(
                f"PingFederate Admin console 'Cluster' was not displayed when attempting to access {self.public_hostname}. SSO may have failed. Browser contents: {self.browser.page_source}",
            )


if __name__ == "__main__":
    unittest.main()
