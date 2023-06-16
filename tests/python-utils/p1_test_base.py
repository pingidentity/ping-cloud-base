import os
import unittest
from typing import Optional

from pingone import common as p1_utils
from requests_oauthlib import OAuth2Session


class P1TestBase(unittest.TestCase):
    worker_app_token_session = None
    environment_name = None
    population_name = None
    cluster_env_id = None
    cluster_env_endpoints = None

    @classmethod
    def setUpClass(cls) -> None:
        client = p1_utils.get_client(p1_utils.WORKERAPP_CLIENT)
        P1TestBase.worker_app_token_session = OAuth2Session(
            client["client_id"], token=client["token"]
        )
        cluster_name = os.getenv("CLUSTER_NAME", "not_set")
        P1TestBase.environment_name = (
            "ci-cd" if cluster_name.startswith("ci-cd") else cluster_name
        )
        P1TestBase.population_name = f"{cluster_name}-{os.getenv('CI_COMMIT_REF_SLUG')}"
        P1TestBase.cluster_env_id = cls.get(
            endpoint=f"{p1_utils.API_LOCATION}/environments",
            name=P1TestBase.environment_name,
        ).get("id")
        P1TestBase.cluster_env_endpoints = p1_utils.EnvironmentEndpoints(
            p1_utils.API_LOCATION, P1TestBase.cluster_env_id
        )

    @classmethod
    def get(cls, endpoint: str, name: str = "") -> Optional[dict]:
        res = cls.worker_app_token_session.get(endpoint)
        embedded_key = endpoint.split("/")[-1]
        if not name:
            return res.json()["_embedded"][embedded_key]

        for e in res.json()["_embedded"][embedded_key]:
            if e["name"] == name:
                print(f"{embedded_key}: {name} ID: {e['id']}")
                return e
        print(f"{embedded_key} {name} not found")
        return None
