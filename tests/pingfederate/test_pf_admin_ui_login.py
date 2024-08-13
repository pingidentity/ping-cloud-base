import os
import unittest

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
        cls.environment = os.getenv("ENV", "dev")
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="PingFederate",
            console_url=cls.public_hostname,
            roles={"p1asPingFederateRoles": [f"{cls.environment}-pf-audit"]},
            # PingFederate has a pop-up that may or may not be displayed
            access_granted_xpaths=[
                "//div[contains(text(), 'Welcome to PingFederate')]",
                "//div[contains(text(), 'Cluster')]",
            ],
            access_denied_xpaths=[
                "//span[contains(text(), 'An error occurred while trying to login with OIDC')]"
            ],
        )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()


if __name__ == "__main__":
    unittest.main()
