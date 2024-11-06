import os
import unittest

import p1_test_base


class TestP1EnvSetupAndTeardown(p1_test_base.P1TestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        cls.auth_policy_name = f"client-{cls.tenant_name}"
        cls.external_idp_name = cls.tenant_name

    def test_population_exists(self):
        pop = self.get(self.cluster_env_endpoints.populations, self.population_name)
        self.assertTrue(pop)

    def test_authentication_policy_created(self):
        p1_auth_policy = self.get(self.cluster_env_endpoints.sign_on_policies, self.auth_policy_name)
        self.assertTrue(p1_auth_policy, f"Authentication policy '{self.auth_policy_name}' not created")

    def test_authentication_policy_actions_added(self):
        p1_auth_policy = self.get(self.cluster_env_endpoints.sign_on_policies, self.auth_policy_name)
        res = self.worker_app_token_session.get(p1_auth_policy.get("_links").get("actions").get("href"))
        p1_auth_policy_actions = res.json()["_embedded"]["actions"]
        actions = ["LOGIN", "MULTI_FACTOR_AUTHENTICATION"]
        for action in actions:
            with self.subTest(msg=f"{action} added"):
                self.assertTrue(
                    any(action in a.get("type") for a in p1_auth_policy_actions),
                    f"Authentication policy '{self.auth_policy_name}' action '{action}' not added",
                )

    @unittest.skipIf(
        os.environ.get("CUSTOMER_PINGONE_ENABLED", "false") == "false",
        "Customer PingOne not enabled, skipping test",
    )
    def test_external_idp_created(self):
        p1_idp = self.get(self.cluster_env_endpoints.identity_providers, self.external_idp_name)
        self.assertTrue(p1_idp, f"External IDP '{self.external_idp_name}' not created")

    @unittest.skipIf(
        os.environ.get("CUSTOMER_PINGONE_ENABLED", "false") == "false",
        "Customer PingOne not enabled, skipping test",
    )
    def test_external_idp_added_to_authentication_policy(self):
        p1_idp = self.get(self.cluster_env_endpoints.identity_providers, self.external_idp_name)
        p1_auth_policy = self.get(self.cluster_env_endpoints.sign_on_policies, self.auth_policy_name)
        res = self.worker_app_token_session.get(p1_auth_policy.get("_links").get("actions").get("href"))
        p1_auth_policy_actions = res.json()["_embedded"]["actions"]
        login_action = next(action for action in p1_auth_policy_actions if action.get("type") == "LOGIN")
        self.assertTrue(
            p1_idp.get("id") in [idp.get("id") for idp in login_action.get("socialProviders")],
            f"External Identity Provider '{self.external_idp_name}' not added to Authentication Policy {self.auth_policy_name}",
        )


if __name__ == "__main__":
    unittest.main()
