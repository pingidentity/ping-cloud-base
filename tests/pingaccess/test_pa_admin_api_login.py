import os
import unittest

import requests
import requests.auth

import b64
import k8s_utils
import oauth
import pingone_api


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPAAdminAPILogin(pingone_api.AdminAPITestBase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        cls.environment = os.getenv("ENV", "dev")
        cls.k8s = k8s_utils.K8sUtils()
        cls.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
        cls.pa_admin_env_vars = cls.k8s.get_configmap_values(
            namespace=cls.namespace,
            configmap_name="pingaccess-admin-environment-variables",
        )
        pa_passwords_secret = cls.k8s.get_namespaced_secret(
            namespace=cls.namespace, name="pingaccess-passwords"
        ).data
        cls.pa_passwords = {k: b64.decode(v) for k, v in pa_passwords_secret.items()}
        cls.config = pingone_api.PingOneAPITestConfig(
            ss_app_name="pingaccess",
            p1_app_name=f"client-{cls.tenant_name}-pingaccess-admin-sso",
            scopes="p1asPAOperatorRoles",
            url_to_test=f"https://{cls.pa_admin_env_vars['PA_ADMIN_PUBLIC_HOSTNAME']}/pa-admin-api/v3/auth/oidc",
            basic_auth_username=cls.pa_admin_env_vars["PA_ADMIN_USER_USERNAME"],
            basic_auth_password=cls.pa_passwords["PA_ADMIN_USER_PASSWORD"],
            p1_user_roles={
                "p1asPingAccessRoles": [
                    f"{cls.environment}-pa-admin",
                    f"{cls.environment}-pa-platform",
                ]
            },
            x_xsrf_header="PingAccess",
        )

    def test_customer_oauth_token_login(self):
        token = oauth.get_token(
            app_id=self.config.customer_p1_app_id,
            app_secret=self.config.customer_p1_app_secret,
            app_token_url=self.config.customer_p1_app_token_url,
            scopes=self.config.scopes,
        )

        res = requests.get(
            url=self.config.url_to_test,
            headers={"Authorization": f"Bearer {token}", "X-XSRF-Header": self.config.x_xsrf_header},
            verify=False,
        )

        self.assertEqual(200, res.status_code, res.text)
