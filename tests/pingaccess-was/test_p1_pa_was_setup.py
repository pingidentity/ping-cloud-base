import copy
import os
import unittest

import k8s_utils
import p1_test_base


@unittest.skipIf(os.environ.get('ENV_TYPE') == "customer-hub", "Customer-hub CDE detected, skipping test module")
class TestP1SsoSetup(p1_test_base.P1TestBase):
    k8s = None
    ping_cloud_ns = ""

    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.k8s = k8s_utils.K8sUtils()
        tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        cls.pa_was_app_name = f"client-{tenant_name}-pa-was"
        cls.account_type_scope_name = "account_type"
        cls.pa_was_secret_name = "pingaccess-was-admin-p14c"
        cls.ping_cloud_ns = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")

        cls.oauth_env_vars = cls.k8s.core_client.read_namespaced_config_map(
            "pingaccess-was-admin-environment-variables", cls.ping_cloud_ns
        ).data

    def test_group_created(self):
        group = self.get(self.cluster_env_endpoints.groups, self.population_name)
        self.assertIsNotNone(group, f"Group '{self.population_name}' not created")

    def test_pa_was_application_created(self):
        app = self.get(self.cluster_env_endpoints.applications, self.pa_was_app_name)
        self.assertIsNotNone(app, f"App '{self.pa_was_app_name}' not created")

    def format_redirect_uri(self, url: str):
        return f"https://{url}/pa-was/oidc/cb"

    def test_pa_was_redirect_uris_set(self):
        app = self.get(self.cluster_env_endpoints.applications, self.pa_was_app_name)
        app_uris = app["redirectUris"]
        host_env_vars = [
            "PA_ADMIN_PUBLIC_HOSTNAME",
            "PF_ADMIN_PUBLIC_HOSTNAME",
            "PROMETHEUS_PUBLIC_HOSTNAME",
            "GRAFANA_PUBLIC_HOSTNAME",
            "OSD_PUBLIC_HOSTNAME",
            "ARGOCD_PUBLIC_HOSTNAME",
        ]
        expected_redirect_uris = {
            env_var: self.format_redirect_uri(self.oauth_env_vars[env_var])
            for env_var in host_env_vars
        }

        for env_var, expected_uri in expected_redirect_uris.items():
            with self.subTest(f"{env_var}={expected_uri}"):
                self.assertIn(
                    expected_uri,
                    app_uris,
                    f"Redirect URI '{expected_uri}' from environment variable '{env_var}' not set in PA-WAS",
                )

    def test_configure_pa_was_redirect_uris_updated(self):
        # Change PA-WAS app's redirect URIs to simulate an existing app that already has a list of redirect URIs
        # Respin PA-WAS pod
        # Get URIs from PA-WAS app
        # Confirm URIs were added
        app = self.get(self.cluster_env_endpoints.applications, self.pa_was_app_name)
        uris = app["redirectUris"]
        modded_uris = [f"{uri}-existing" for uri in uris]
        modded_app_payload = copy.deepcopy(app)
        modded_app_payload["redirectUris"] = modded_uris
        self.worker_app_token_session.put(
            f"{self.cluster_env_endpoints.applications}/{app['id']}",
            json=modded_app_payload,
        )

        self.k8s.kill_pods(label="role=pingaccess-was-admin", namespace=self.ping_cloud_ns)
        self.k8s.wait_for_pod_running(label="role=pingaccess-was-admin", namespace=self.ping_cloud_ns)

        updated_app = self.get(
            self.cluster_env_endpoints.applications, self.pa_was_app_name
        )
        updated_uris = updated_app["redirectUris"]

        # revert app's URIs for other tests
        self.worker_app_token_session.put(
            f"{self.cluster_env_endpoints.applications}/{app['id']}", json=app
        )
        expected_uris = uris + modded_uris
        self.assertCountEqual(
            expected_uris,
            updated_uris,
            f"The {self.pa_was_app_name} application's redirect URIs were not updated in PingOne",
        )

    def test_pa_was_account_type_scope_granted_to_application(self):
        app = self.get(self.cluster_env_endpoints.applications, self.pa_was_app_name)
        grants = self.get(
            f"{self.cluster_env_endpoints.applications}/{app['id']}/grants"
        )
        # Get granted resource and scope IDs
        granted_resource_ids = []
        granted_scope_ids = []
        for grant in grants:
            granted_resource_ids.append(grant["resource"]["id"])
            granted_scope_ids += [scope["id"] for scope in grant["scopes"]]

        # Get account_type scope IDs from granted resources
        account_type_scope_ids = []
        for resource_id in granted_resource_ids:
            scope = self.get(
                endpoint=f"{self.cluster_env_endpoints.resources}/{resource_id}/scopes",
                name=self.account_type_scope_name,
            )
            account_type_scope_ids.append(scope["id"])

        # Check that one of the granted scope IDs is an account_type scope
        self.assertTrue(
            any(
                granted_scope_id in account_type_scope_ids
                for granted_scope_id in granted_scope_ids
            ),
            f"No grant for scope '{self.account_type_scope_name}' found for application '{self.pa_was_app_name}'",
        )

    def test_pa_was_k8s_secret_values_created(self):
        pa_was_secret = self.k8s.get_namespaced_secret(
            self.pa_was_secret_name, self.ping_cloud_ns
        )

        self.assertIsNotNone(
            pa_was_secret, f"Secret '{self.pa_was_secret_name}' not created"
        )

        expected_keys = [
            "P14C_CLIENT_ID",
            "P14C_CLIENT_SECRET",
            "P14C_ISSUER",
        ]
        for key in expected_keys:
            with self.subTest(key):
                self.assertIn(
                    key,
                    pa_was_secret.data,
                    f"Key '{key}' not found in secret '{self.pa_was_secret_name}'",
                )

    def test_same_pa_was_used_on_successive_runs(self):
        # Get app from PingOne
        # Respin PA-WAS pod
        # Get app from PingOne
        # Confirm app IDs match
        expected_app = self.get(
            self.cluster_env_endpoints.applications, self.pa_was_app_name
        )

        self.k8s.kill_pods(label="role=pingaccess-was-admin", namespace=self.ping_cloud_ns)
        self.k8s.wait_for_pod_running(label="role=pingaccess-was-admin", namespace=self.ping_cloud_ns)

        updated_app = self.get(
            self.cluster_env_endpoints.applications, self.pa_was_app_name
        )
        self.assertEqual(
            expected_app["id"],
            updated_app["id"],
            "The existing PingAccess-WAS app was not reused on successive runs",
        )


if __name__ == "__main__":
    unittest.main()
