import os
import unittest

import tenacity
from pingone import common as p1_utils
from requests_oauthlib import OAuth2Session


def print_error(retry_state: tenacity.RetryCallState) -> None:
    print(
        f"Retrying {retry_state.fn}: attempt {retry_state.attempt_number} ended with: {retry_state.outcome}"
    )


@tenacity.retry(
    reraise=True,
    wait=tenacity.wait_fixed(1),
    before_sleep=print_error,
    stop=tenacity.stop_after_attempt(5),
)
def get(token_session, endpoint: str, name: str = "") -> {}:
    res = token_session.get(endpoint)
    res.raise_for_status()

    embedded_key = endpoint.split("/")[-1]
    if not name:
        return res.json()["_embedded"][embedded_key]

    for e in res.json()["_embedded"][embedded_key]:
        if e["name"] == name:
            print(f"{embedded_key}: {name} ID: {e['id']}")
            return e
    print(f"{embedded_key} {name} not found")

    return {}


class P1TestBase(unittest.TestCase):
    worker_app_token_session = None
    environment_name = None
    population_name = None
    cluster_env_id = None
    cluster_env_endpoints = None

    @classmethod
    def setUpClass(cls) -> None:
        client = p1_utils.get_client()
        P1TestBase.worker_app_token_session = OAuth2Session(
            client["client_id"], token=client["token"]
        )
        cluster_name = os.getenv("CLUSTER_NAME", "not_set")
        P1TestBase.environment_name = (
            "ci-cd" if cluster_name.startswith("ci-cd") else "dev"
        )
        P1TestBase.population_name = f"{cluster_name}"
        P1TestBase.cluster_env_id = cls.get(
            endpoint=f"{p1_utils.API_LOCATION}/environments",
            name=P1TestBase.environment_name,
        ).get("id")
        P1TestBase.cluster_env_endpoints = p1_utils.EnvironmentEndpoints(
            p1_utils.API_LOCATION, P1TestBase.cluster_env_id
        )

    @classmethod
    def get(cls, endpoint: str, name: str = "") -> {}:
        return get(cls.worker_app_token_session, endpoint=endpoint, name=name)

    def get_user_attribute_values(self, attribute_name: str) -> []:
        user_schema_id = self.get(self.cluster_env_endpoints.schemas, "User").get("id")
        response = self.get(
            f"{self.cluster_env_endpoints.schemas}/{user_schema_id}/attributes"
        )
        attribute_values = next(
            attr["enumeratedValues"]
            for attr in response
            if attr["name"] == attribute_name
        )
        return [attr["value"] for attr in attribute_values]

    def get_app_scope_ids(self, app_name: str) -> []:
        app = self.get(self.cluster_env_endpoints.applications, app_name)
        grants = self.get(
            f"{self.cluster_env_endpoints.applications}/{app['id']}/grants"
        )
        # Get granted scope IDs
        scope_ids = []
        for grant in grants:
            scope_ids += [scope["id"] for scope in grant["scopes"]]

        return scope_ids

    def get_resource_scope_id(self, resource_name: str, scope_name: str) -> str:
        resource = self.get(self.cluster_env_endpoints.resources, resource_name)
        scopes = self.get(resource["_links"]["scopes"]["href"])
        for scope in scopes:
            if scope["name"] == scope_name:
                return scope["id"]
        return ""
