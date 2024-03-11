import os
import unittest

from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.common.by import By
from selenium.webdriver.support.wait import WebDriverWait

from pingone import common as p1_utils
import pingone_ui as p1_ui


class TestArgoUILogin(p1_ui.ConsoleUILoginTestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.public_hostname = os.getenv(
            "ARGOCD_PUBLIC_HOSTNAME",
            f"https://argocd.{os.environ['TENANT_DOMAIN']}",
        )
        cls.username = f"sso-argocd-test-user-{cls.tenant_name}"
        cls.password = "2FederateM0re!"
        cls.delete_pingone_user()
        cls.create_pingone_user()
        cls.group_names = [
            "argo-pingbeluga",
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

    def test_user_can_access_argocd_console(self):
        # Wait for admin console to be reachable if it has been restarted by another test
        self.wait_until_url_is_reachable(self.public_hostname)
        # Attempt to access the console with SSO
        self.pingone_login()
        self.browser.get(f"{self.public_hostname}/auth/login")
        self.browser.implicitly_wait(10)
        try:
            title = self.browser.find_element(
                By.XPATH, "//span[contains(text(), 'Applications')]"
            )
            wait = WebDriverWait(self.browser, timeout=10)
            wait.until(lambda t: title.is_displayed())
            self.assertTrue(
                title.is_displayed(),
                f"ArgoCD console 'Applications' page was not displayed when attempting to access {self.public_hostname}. SSO may have failed. Browser contents: {self.browser.page_source}",
            )
        except NoSuchElementException:
            self.fail(
                f"ArgoCD console 'Applications' page was not displayed when attempting to access {self.public_hostname}. SSO may have failed. Browser contents: {self.browser.page_source}",
            )


if __name__ == "__main__":
    unittest.main()
