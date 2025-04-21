import os
import unittest

import pingone_ui as p1_ui


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestSelfServiceAPILogin(p1_ui.ConsoleUILoginTestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.public_hostname = f"https://self-service-api.{os.environ['TENANT_DOMAIN']}/api/v1/auth/login"
        cls.environment = os.getenv("ENV", "dev")
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="SelfService",
            console_url=cls.public_hostname,
            roles={"p1asSelfServiceRoles": [f"{cls.environment}-tls-audit"]},
            access_granted_xpaths=["//h2[contains(text(), 'Authentication Successful!!')]"],
            access_denied_xpaths=[
                "//pre[contains(text(), '{\"detail\":\"Access token is missing required scopes.\"}')]"
            ],
        )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()


if __name__ == "__main__":
    unittest.main()
