import unittest

import p1_test_base


class TestP1SsoSetup(p1_test_base.P1TestBase):
    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()

    def test_group_created(self):
        group_id = self.get_id(self.cluster_env_endpoints.groups, self.population_name)
        self.assertIsNotNone(group_id)


if __name__ == "__main__":
    unittest.main()
