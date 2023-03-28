import os
import unittest
from typing import Optional

from pingone import common as p1_utils
from requests_oauthlib import OAuth2Session


class TestP1EnvSetupAndTeardown(unittest.TestCase):
    worker_app_token_session = None
    environment_name = None
    population_name = None
    cluster_env_id = None
    cluster_env_endpoints = None

    @classmethod
    def setUpClass(cls) -> None:
        client = p1_utils.get_client(p1_utils.WORKERAPP_CLIENT)
        TestP1EnvSetupAndTeardown.worker_app_token_session = OAuth2Session(client["client_id"], token=client["token"])
        cluster_name = os.getenv("CLUSTER_NAME", "not_set")
        TestP1EnvSetupAndTeardown.environment_name = "ci-cd" if cluster_name.startswith("ci-cd") else cluster_name
        TestP1EnvSetupAndTeardown.population_name = f"{cluster_name}-{os.getenv('CI_COMMIT_REF_SLUG')}"
        TestP1EnvSetupAndTeardown.cluster_env_id = cls.get_id(endpoint=f"{p1_utils.API_LOCATION}/environments", name=TestP1EnvSetupAndTeardown.environment_name)
        TestP1EnvSetupAndTeardown.cluster_env_endpoints = p1_utils.EnvironmentEndpoints(p1_utils.API_LOCATION, TestP1EnvSetupAndTeardown.cluster_env_id)

    @classmethod
    def get_id(cls, endpoint: str, name: str) -> Optional[str]:
        res = cls.worker_app_token_session.get(endpoint)
        embedded_key = endpoint.split("/")[-1]
        for e in res.json()["_embedded"][embedded_key]:
            if e["name"] == name:
                print(f"{embedded_key}: {name} ID: {e['id']}")
                return e["id"]
        print(f"{embedded_key} {name} not found")
        return None

    def test_population_exists(self):
        pop_id = self.get_id(self.cluster_env_endpoints.populations, self.population_name)
        self.assertIsNotNone(pop_id)


if __name__ == '__main__':
    unittest.main()
