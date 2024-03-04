import json
import os
import unittest

import p1_test_base
from k8s_utils import K8sUtils


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
        self.app_name = f"client-{self.tenant_name}-pingfederate-admin-sso"
        self.k8s = K8sUtils()
        self.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")

    def test_groups_created(self):
        for group_name in self.group_names:
            with self.subTest(msg=f"{group_name} created"):
                p1_group = self.get(self.cluster_env_endpoints.groups, group_name)
                self.assertTrue(p1_group, f"Group '{group_name}' not created")

    def test_app_created(self):
        p1_app = self.get(self.cluster_env_endpoints.applications, self.app_name)
        self.assertTrue(p1_app, f"Application '{self.app_name}' not created")

    def test_sso_configmap_created(self):
        sso_configmap_data = self.k8s.get_configmap_values(namespace=self.namespace,
                                                           configmap_name="pingfederate-sso-status")
        self.assertTrue(json.loads(sso_configmap_data["sso.configured"].lower()))


if __name__ == "__main__":
    unittest.main()
