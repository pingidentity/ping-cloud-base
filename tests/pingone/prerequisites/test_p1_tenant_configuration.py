import os
import unittest

import p1_test_base


class TestP1EnvSetupAndTeardown(p1_test_base.P1TestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")

    def test_population_exists(self):
        pop = self.get(self.cluster_env_endpoints.populations, self.population_name)
        self.assertIsNotNone(pop)

    def test_authentication_policy_created(self):
        auth_policy_name = f"client-{self.tenant_name}"
        p1_auth_policy = self.get(self.cluster_env_endpoints.sign_on_policies, auth_policy_name)
        self.assertTrue(p1_auth_policy, f"Authentication policy '{auth_policy_name}' not created")


if __name__ == "__main__":
    unittest.main()
