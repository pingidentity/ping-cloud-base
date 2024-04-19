import json
import os

import p1_test_base
from k8s_utils import K8sUtils


class TestOpensearchSSO(p1_test_base.P1TestBase):
    def setUp(self) -> None:
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.user_attribute_name = "p1asOpensearchRoles"
        self.role_names = [
            "os-configteam",
            "os-ping",
        ]
        self.app_name = f"client-{self.tenant_name}-opensearch-sso"
        self.k8s = K8sUtils()

    def test_roles_created(self):
        existing_attribute_names = self.get_user_attribute_values(self.user_attribute_name)
        self.assertTrue(len(existing_attribute_names) > 0, f"No roles found for {self.user_attribute_name}")
        for role_name in self.role_names:
            with self.subTest(msg=f"{role_name} created"):
                self.assertTrue(
                    role_name in existing_attribute_names,
                    f"Role '{role_name}' not created",
                )

    def test_app_created(self):
        p1_app = self.get(self.cluster_env_endpoints.applications, self.app_name)
        self.assertTrue(p1_app, f"Application '{self.app_name}' not created")

    def test_sso_configmap_created(self):
        sso_configmap_data = self.k8s.get_configmap_values(namespace="elastic-stack-logging",
                                                           configmap_name="opensearch-sso-status")
        self.assertTrue(json.loads(sso_configmap_data["sso.configured"].lower()))
