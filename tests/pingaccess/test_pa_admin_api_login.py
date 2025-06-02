import os
import unittest

import requests
import requests.auth
import urllib3
import warnings

import b64
import k8s_utils
import oauth
import pingone_ui


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPAAdminAPILogin(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # Ignore warnings for insecure http requests
        warnings.filterwarnings(
            "ignore", category=urllib3.exceptions.InsecureRequestWarning
        )
        # Ignore ResourceWarning for unclosed SSL sockets
        warnings.filterwarnings("ignore", category=ResourceWarning, message="unclosed <ssl.SSLSocket")
        cls.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        cls.environment = os.getenv("ENV", "dev")
        cls.user_attribute_name = "p1asPingAccessRoles"
        cls.role_names = [
            f"{cls.environment}-pa-admin",
            f"{cls.environment}-pa-platform",
            f"{cls.environment}-pa-audit",
        ]
        cls.app_name = f"client-{cls.tenant_name}-pingaccess-admin-sso"
        cls.auth_policy_name = f"client-{cls.tenant_name}"
        cls.k8s = k8s_utils.K8sUtils()
        cls.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
        cls.operator_resource_name = f"client-{cls.tenant_name}-pa-operator"
        cls.operator_scope_name = "p1asPAOperatorRoles"
        cls.pa_admin_env_vars = cls.k8s.get_configmap_values(
            namespace=cls.namespace,
            configmap_name="pingaccess-admin-environment-variables",
        )
        pa_passwords_secret = cls.k8s.get_namespaced_secret(
            namespace=cls.namespace, name="pingaccess-passwords"
        ).data
        cls.pa_passwords = {k: b64.decode(v) for k, v in pa_passwords_secret.items()}
        pa_p14c_secret = cls.k8s.get_namespaced_secret(
            namespace=cls.namespace, name="pingaccess-admin-p14c"
        ).data
        cls.pa_p14c_secret = {k: b64.decode(v) for k, v in pa_p14c_secret.items()}
        cls.pa_p14c_configmap = cls.k8s.get_configmap_values(
            namespace=cls.namespace, configmap_name="pingaccess-admin-p14c"
        )
        customer_p1_app_secret = cls.k8s.get_namespaced_secret(
            namespace="argocd", name="customer-p1-app"
        )
        cls.customer_p1_app_secret = {k: b64.decode(v) for k, v in customer_p1_app_secret.data.items()}
        cls.pa_admin_api_url = f"https://{cls.pa_admin_env_vars['PA_ADMIN_PUBLIC_HOSTNAME']}/pa-admin-api/v3"
        cls.scopes = "p1asPAOperatorRoles"
        cls.environment = os.getenv("ENV", "dev")

    def test_oauth_token_login(self):
        token = oauth.get_token(
            app_id=self.pa_p14c_configmap["P14C_CLIENT_ID"],
            app_secret=self.pa_p14c_secret["P14C_CLIENT_SECRET"],
            app_token_url=f"{self.pa_p14c_configmap['P14C_ISSUER']}/token",
            scopes=self.scopes,
        )
        res = requests.get(
            url=f"{self.pa_admin_api_url}/auth/oidc",
            headers={"Authorization": f"Bearer {token}", "X-XSRF-Header": "PingAccess"},
            verify=False,
        )
        self.assertEqual(200, res.status_code)

    def test_customer_oauth_token_login(self):
        print(self.customer_p1_app_secret)
        token = oauth.get_token(
            app_id=self.customer_p1_app_secret["CLIENT_ID"],
            app_secret=self.customer_p1_app_secret["CLIENT_SECRET"],
            app_token_url=f"{self.customer_p1_app_secret['ISSUER']}/token",
            scopes=self.scopes,
        )

        res = requests.get(
            url=f"{self.pa_admin_api_url}/auth/oidc",
            headers={"Authorization": f"Bearer {token}", "X-XSRF-Header": "PingAccess"},
            verify=False,
        )

        self.assertEqual(200, res.status_code, res.text)

    @unittest.skip("Must disable MFA for local_user to run this test")
    def test_user_access_token_login(self):
        ui_test_config = pingone_ui.PingOneUITestConfig(
            app_name="PingAccess-API",
            console_url=self.pa_admin_env_vars["PA_ADMIN_PUBLIC_HOSTNAME"],
            roles={
                "p1asPingAccessRoles": [
                    f"{self.environment}-pa-admin",
                    f"{self.environment}-pa-platform",
                ]
            },
            access_granted_xpaths=[],
            access_denied_xpaths=[],
            create_local_only=True,
        )
        p1_ui = pingone_ui.PingOneUIDriver()
        p1_ui.setup_browser()
        p1_ui.self_service_login(
            url=f"https://{self.pa_admin_env_vars['SELF_SERVICE_PUBLIC_HOSTNAME']}/api/v1/auth/login/pingaccess",
            username=ui_test_config.local_user.username,
            password=ui_test_config.local_user.password,
        )
        token = p1_ui.self_service_get_token()
        p1_ui.teardown_browser()
        res = requests.get(
            url=f"{self.pa_admin_api_url}/auth/tokenProvider",
            headers={"Authorization": f"Bearer {token}", "X-XSRF-Header": "PingAccess"},
            verify=False,
        )
        self.assertEqual(200, res.status_code)
