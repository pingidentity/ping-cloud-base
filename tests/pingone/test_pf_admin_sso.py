import os
import unittest

import p1_test_base


@unittest.skipIf(os.environ.get('ENV_TYPE') == "customer-hub", "Customer-hub CDE detected, skipping test module")
class TestPFAdminSSO(p1_test_base.P1TestBase):
    def setUp(self):
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.environment = os.getenv("ENV", "dev")
        self.group_names = [
            f"{self.tenant_name}-{self.environment}-pf-roleadmin",
            f"{self.tenant_name}-{self.environment}-pf-crypto",
            f"{self.tenant_name}-{self.environment}-pf-useradmin",
            f"{self.tenant_name}-{self.environment}-pf-expression",
            f"{self.tenant_name}-{self.environment}-pf-audit",
        ]
        self.app_name = f"client-{self.tenant_name}-pingfederate-sso"

    def test_groups_created(self):
        for group_name in self.group_names:
            with self.subTest(msg=f"{group_name} created"):
                p1_group = self.get(self.cluster_env_endpoints.groups, group_name)
                self.assertIsNotNone(p1_group, f"Group '{group_name}' not created")

    def test_app_created(self):
        p1_app = self.get(self.cluster_env_endpoints.applications, self.app_name)
        self.assertIsNotNone(p1_app, f"Application '{self.app_name}' not created")


if __name__ == "__main__":
    unittest.main()
