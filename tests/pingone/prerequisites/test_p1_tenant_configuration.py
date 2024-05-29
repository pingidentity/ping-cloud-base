import os
import unittest

import p1_test_base


class TestP1EnvSetupAndTeardown(p1_test_base.P1TestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        cls.auth_policy_name = f"client-{cls.tenant_name}"

    def test_population_exists(self):
        pop = self.get(self.cluster_env_endpoints.populations, self.population_name)
        self.assertIsNotNone(pop)

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


if __name__ == "__main__":
    unittest.main()
