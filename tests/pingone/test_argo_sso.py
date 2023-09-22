import os

import p1_test_base


class TestArgoSSO(p1_test_base.P1TestBase):
    def setUp(self) -> None:
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.group_names = [
            "argo-beluga",
            f"{self.tenant_name}-argo-config-team",
            "argo-gso",
            "argo-platform-team",
        ]

    def test_groups_created(self):
        for group_name in self.group_names:
            with self.subTest(msg=f"{group_name} created"):
                p1_group = self.get(self.cluster_env_endpoints.groups, group_name)
                self.assertIsNotNone(p1_group, f"Group '{group_name}' not created")
