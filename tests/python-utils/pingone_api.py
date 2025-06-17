import os
import unittest
import warnings

import requests
import requests.auth
import requests_oauthlib
import urllib3

import b64
import k8s_utils
import oauth
from pingone import common as p1_common
import p1_test_base
import pingone_ui


class PingOneAPITestConfig:
    
    def __init__(
            self,
            ss_app_name: str,
            p1_app_name: str,
            scopes: str,
            url_to_test: str,
            basic_auth_username: str = None,
            basic_auth_password: str = None,
            p1_user_roles: {str:[str]} = None,
            x_xsrf_header: str = None,
    ):
        self.ss_app_name = ss_app_name
        self.p1_app_name = p1_app_name
        self.scopes = scopes
        self.url_to_test = url_to_test
        self.basic_auth_username = basic_auth_username
        self.basic_auth_password = basic_auth_password
        self.p1_user_roles = p1_user_roles if p1_user_roles else []
        self.x_xsrf_header = x_xsrf_header
        self.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        self.client = p1_common.get_client()
        self.session = requests_oauthlib.OAuth2Session(
            self.client["client_id"], token=self.client["token"]
        )
        self.p1_env_id = p1_test_base.get(
            token_session=self.session,
            endpoint=f"{p1_common.API_LOCATION}/environments",
            name="ci-cd",
        ).get("id")
        p1as_app = p1_test_base.get(
            token_session=self.session,
            endpoint=f"{p1_common.API_LOCATION}/environments/{self.p1_env_id}/applications",
            name=self.p1_app_name
        )
        self.p1as_app_id = p1as_app.get("id")
        res = self.session.get(url=f"{p1_common.API_LOCATION}/environments/{self.p1_env_id}/applications/{self.p1as_app_id}/secret")
        self.p1as_app_secret = res.json().get("secret")
        self.p1as_app_token_url = f"https://auth.{p1_common.P1_DOMAIN}/{self.p1_env_id}/as/token"
        self.k8s = k8s_utils.K8sUtils()
        customer_secret = self.k8s.get_namespaced_secret(
            namespace="argocd", name="customer-p1-app"
        )
        self.customer_secret = {k: b64.decode(v) for k, v in customer_secret.data.items()}
        self.customer_p1_app_id = self.customer_secret.get("CLIENT_ID")
        self.customer_p1_app_secret = self.customer_secret.get("CLIENT_SECRET")
        self.customer_p1_app_token_url = f"{self.customer_secret.get('ISSUER')}/token"
        pingcommon_environment_variables = self.k8s.get_configmap_values(
            namespace=os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud"), configmap_name="pingcommon-environment-variables",
        )
        self.self_service_public_hostname = pingcommon_environment_variables.get("SELF_SERVICE_PUBLIC_HOSTNAME")
        self.p1as_endpoints = p1_common.EnvironmentEndpoints(
            p1_common.API_LOCATION, self.p1_env_id
        )
        self.population_id = p1_common.get_population_id(
            token_session=self.session,
            endpoints=self.p1as_endpoints,
            name=self.tenant_name,
        )
        self.p1_user = pingone_ui.PingOneUser(
            session=self.session,
            environment_endpoints=self.p1as_endpoints,
            username=f"{self.ss_app_name}-sso-user-{self.tenant_name}",
            roles=self.p1_user_roles,
            population_id=self.population_id,
        )
        self.p1_user.delete()
        self.p1_user.create()

    def delete_users(self):
        self.p1_user.delete()



class AdminAPITestBase(unittest.TestCase):
    """
    Base class for Ping product Admin API tests.

    Add test cases specific to each app in the child classes.
    """
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.config = None
        # Ignore warnings for insecure http requests
        warnings.filterwarnings(
            "ignore", category=urllib3.exceptions.InsecureRequestWarning
        )
        # Ignore ResourceWarning for unclosed SSL sockets
        warnings.filterwarnings("ignore", category=ResourceWarning, message="unclosed <ssl.SSLSocket")

    @classmethod
    def tearDownClass(cls):
        if cls.config:
            cls.config.delete_users()
        super().tearDownClass()

    def test_oauth_token_login(self):
        token = oauth.get_token(
            app_id=self.config.p1as_app_id,
            app_secret=self.config.p1as_app_secret,
            app_token_url=self.config.p1as_app_token_url,
            scopes=self.config.scopes,
        )
        res = requests.get(
            url=self.config.url_to_test,
            headers={"Authorization": f"Bearer {token}", "X-XSRF-Header": self.config.x_xsrf_header},
            verify=False,
        )
        self.assertEqual(200, res.status_code, f"Failed to login with token: {token}")

    def test_user_access_token_login(self):
        p1_ui = pingone_ui.PingOneUIDriver()
        p1_ui.setup_browser()
        p1_ui.self_service_login(
            url=f"https://{self.config.self_service_public_hostname}/api/v1/auth/login/{self.config.ss_app_name}",
            username=self.config.p1_user.username,
            password=self.config.p1_user.password,
        )
        token = p1_ui.self_service_get_token()
        p1_ui.teardown_browser()
        res = requests.get(
            url=self.config.url_to_test,
            headers={"Authorization": f"Bearer {token}", "X-XSRF-Header": self.config.x_xsrf_header},
            verify=False,
        )
        self.assertEqual(200, res.status_code, f"Failed to login with token: {token}")

    def test_basic_auth_login(self):
        res = requests.get(
            url=self.config.url_to_test,
            auth=requests.auth.HTTPBasicAuth(
                username=self.config.basic_auth_username,
                password=self.config.basic_auth_password,
            ),
            headers={"X-XSRF-Header": self.config.x_xsrf_header},
            verify=False,
        )
        self.assertEqual(200, res.status_code)