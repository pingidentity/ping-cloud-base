import os
import unittest

import pingone_ui as p1_ui


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestOpensearchUILogin(p1_ui.ConsoleUILoginTestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.public_hostname = os.getenv(
            "OPENSEARCH_PUBLIC_HOSTNAME",
            f"https://logs.{os.environ['TENANT_DOMAIN']}",
        )
        cls.console_url = f"{cls.public_hostname}/auth/openid/login"
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="Opensearch",
            console_url=cls.console_url,
            roles={"p1asOpensearchRoles": ["os-configteam"]},
            access_granted_xpaths=["//div[contains(text(), 'Introducing new OpenSearch Dashboards look & feel')]"],
            access_denied_xpaths=["//h3[contains(text(), 'Missing Role')]"],
        )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()


if __name__ == "__main__":
    unittest.main()
