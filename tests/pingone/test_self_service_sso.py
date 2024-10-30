import os
import json
import unittest

import p1_test_base
from k8s_utils import K8sUtils


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestSelfServiceSSO(p1_test_base.P1TestBase):
    def setUp(self):
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.environment = os.getenv("ENV", "dev")
        self.user_attribute_name = "p1asSelfServiceRoles"
        self.role_names = [
            f"{self.environment}-tls-admin",
            f"{self.environment}-tls-audit",
            "all-tls-admin",
            "all-tls-audit",
        ]
        self.app_name = f"client-{self.tenant_name}-self-service-sso"
        self.auth_policy_name = f"client-{self.tenant_name}"
        self.k8s = K8sUtils()
        self.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")

    def test_roles_created(self):
        existing_attribute_names = self.get_user_attribute_values(
            self.user_attribute_name
        )
        self.assertTrue(
            len(existing_attribute_names) > 0,
            f"No roles found for {self.user_attribute_name}",
        )
        for role_name in self.role_names:
            with self.subTest(msg=f"{role_name} created"):
                self.assertTrue(
                    role_name in existing_attribute_names,
                    f"Role '{role_name}' not created",
                )

    def test_app_created(self):
        p1_app = self.get(self.cluster_env_endpoints.applications, self.app_name)
        self.assertTrue(p1_app, f"Application '{self.app_name}' not created")

    def test_authentication_policy_added_to_app(self):
        p1_auth_policy = self.get(
            self.cluster_env_endpoints.sign_on_policies, self.auth_policy_name
        )
        p1_app = self.get(self.cluster_env_endpoints.applications, self.app_name)
        res = self.worker_app_token_session.get(
            f"{self.cluster_env_endpoints.applications}/{p1_app.get('id')}/signOnPolicyAssignments"
        )
        res.raise_for_status()
        p1_app_policy_ids = [
            policy.get("signOnPolicy").get("id")
            for policy in res.json()["_embedded"]["signOnPolicyAssignments"]
        ]
        self.assertTrue(
            p1_auth_policy.get("id") in p1_app_policy_ids,
            f"Authentication policy '{self.auth_policy_name}' not added to application '{self.app_name}'",
        )

    def test_sso_configmap_created(self):
        sso_configmap_data = self.k8s.get_configmap_values(
            namespace=self.namespace, configmap_name="self-service-sso-status"
        )
        self.assertTrue(json.loads(sso_configmap_data["sso.configured"].lower()))


if __name__ == "__main__":
    unittest.main()
