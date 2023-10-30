import os

import p1_test_base


class TestArgoSSO(p1_test_base.P1TestBase):
    def setUp(self) -> None:
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.group_names = [
            "argo-ping-beluga",
            f"{self.tenant_name}-argo-ping-configteam",
            "argo-ping-platform",
        ]
        self.app_name = f"client-{self.tenant_name}-{self.environment_name}-argo-sso"

    def test_groups_created(self):
        for group_name in self.group_names:
            with self.subTest(msg=f"{group_name} created"):
                p1_group = self.get(self.cluster_env_endpoints.groups, group_name)
                self.assertIsNotNone(p1_group, f"Group '{group_name}' not created")

    def test_app_created(self):
        p1_app = self.get(self.cluster_env_endpoints.applications, self.app_name)
        self.assertIsNotNone(p1_app, f"Application '{self.app_name}' not created")
