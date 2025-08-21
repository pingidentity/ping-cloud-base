import os
import unittest

from selenium.common.exceptions import NoSuchElementException

import pingone_ui


class TestArgoUILogin(pingone_ui.ConsoleUILoginTestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.public_hostname = os.getenv(
            "ARGOCD_PUBLIC_HOSTNAME",
            f"https://argocd.{os.environ['TENANT_DOMAIN']}",
        )
        cls.console_url = f"{cls.public_hostname}/auth/login"
        cls.applications_list_xpath = "//div[contains(@class, 'applications-list__entry')]"
        cls.access_granted_xpaths = [cls.applications_list_xpath]
        cls.configteam_role = {"p1asArgoCDRoles": ["argo-configteam"]}
        cls.config = pingone_ui.PingOneUITestConfig(
            app_name="ArgoCD",
            console_url=cls.console_url,
            roles=cls.configteam_role,
            access_granted_xpaths=cls.access_granted_xpaths,
            access_denied_xpaths=[
                "//h4[contains(text(), 'No applications available to you')]"
            ],
        )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()

    def test_ping_user_can_access_argocd_with_any_population(self):
        ping_user = pingone_ui.PingOneUser(
            session=self.config.session,
            environment_endpoints=self.config.p1as_endpoints,
            username=f"{self.config.app_name}-ping-user-{self.config.tenant_name}",
            roles={"p1asPingRoles": ["argo-pingbeluga"]},
            population_id=None,
        )
        ping_user.delete()
        ping_user.create(add_p1_role=True)
        ping_user.disable_mfa()
        self.addCleanup(ping_user.delete)

        self.p1_ui.wait_until_url_is_reachable(self.console_url)
        self.p1_ui.login(url=self.console_url, username=ping_user.username, password=ping_user.password)
        self.p1_ui.browser.get(self.console_url)
        try:
            self.assertTrue(
                pingone_ui.any_browser_element_displayed(self.p1_ui.browser, self.config.access_granted_xpaths),
                f"Applications were not visible on ArgoCD console 'Applications' page when attempting to access "
                f"{self.console_url}. SSO may have failed. Browser contents: {self.p1_ui.browser.page_source}",
            )
        except NoSuchElementException:
            self.fail(
                f"ArgoCD console 'Applications' page was not displayed when attempting to access {self.console_url}. "
                f"SSO may have failed. Browser contents: {self.p1_ui.browser.page_source}",
            )


if __name__ == "__main__":
    unittest.main()
