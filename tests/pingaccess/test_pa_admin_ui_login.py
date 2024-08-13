import os
import unittest

import pingone_ui as p1_ui


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPAAdminUILogin(p1_ui.ConsoleUILoginTestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.public_hostname = os.getenv(
            "PA_ADMIN_PUBLIC_HOSTNAME",
            f"https://pingaccess-admin.{os.environ['TENANT_DOMAIN']}",
        )
        cls.environment = os.getenv("ENV", "dev")
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="PingAccess",
            console_url=cls.public_hostname,
            roles={"p1asPingAccessRoles": [f"{cls.environment}-pa-audit"]},
            # PingFederate has a pop-up that may or may not be displayed
            access_granted_xpaths=["//div[contains(text(), 'Applications')]"],
            access_denied_xpaths=["//pre[contains(text(), 'Access Denied')]"],
        )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()


if __name__ == "__main__":
    unittest.main()
