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

    def setUp(self):
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.environment = os.getenv("ENV", "dev")
        self.user_attribute_name = "p1asPingAccessRoles"
        self.role_names = [
            f"{self.environment}-pa-admin",
            f"{self.environment}-pa-platform",
            f"{self.environment}-pa-audit",
        ]
        self.app_name = f"client-{self.tenant_name}-pingaccess-admin-sso"
        self.auth_policy_name = f"client-{self.tenant_name}"
        self.k8s = k8s_utils.K8sUtils()
        self.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
        self.operator_resource_name = f"client-{self.tenant_name}-pa-operator"
        self.operator_scope_name = "p1asPAOperatorRoles"
        self.pa_admin_env_vars = self.k8s.get_configmap_values(
            namespace=self.namespace,
            configmap_name="pingaccess-admin-environment-variables",
        )
        pa_passwords_secret = self.k8s.get_namespaced_secret(
            namespace=self.namespace, name="pingaccess-passwords"
        ).data
        self.pa_passwords = {k: b64.decode(v) for k, v in pa_passwords_secret.items()}
        pa_p14c_secret = self.k8s.get_namespaced_secret(
            namespace=self.namespace, name="pingaccess-admin-p14c"
        ).data
        self.pa_p14c_secret = {k: b64.decode(v) for k, v in pa_p14c_secret.items()}
        self.pa_p14c_configmap = self.k8s.get_configmap_values(
            namespace=self.namespace, configmap_name="pingaccess-admin-p14c"
        )
        self.pa_admin_api_url = f"https://{self.pa_admin_env_vars['PA_ADMIN_PUBLIC_HOSTNAME']}/pa-admin-api/v3"
        self.scopes = "p1asPAOperatorRoles"
        self.environment = os.getenv("ENV", "dev")

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

    def test_basic_auth_login(self):
        res = requests.get(
            url=f"{self.pa_admin_api_url}/auth/oauth",
            auth=requests.auth.HTTPBasicAuth(
                username=self.pa_admin_env_vars["PA_ADMIN_USER_USERNAME"],
                password=self.pa_passwords["PA_ADMIN_USER_PASSWORD"],
            ),
            headers={"X-XSRF-Header": "PingAccess"},
            verify=False,
        )
        self.assertEqual(200, res.status_code)
