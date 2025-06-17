import os
import unittest

import b64
import k8s_utils
import pingone_api


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestPFAdminAPILogin(pingone_api.AdminAPITestBase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.tenant_name = os.getenv("TENANT_NAME", f"{os.getenv('USER')}-primary")
        cls.environment = os.getenv("ENV", "dev")
        cls.k8s = k8s_utils.K8sUtils()
        cls.namespace = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
        cls.admin_env_vars = cls.k8s.get_configmap_values(
            namespace=cls.namespace,
            configmap_name="pingfederate-admin-environment-variables",
        )
        passwords_secret = cls.k8s.get_namespaced_secret(
            namespace=cls.namespace, name="pingfederate-passwords"
        ).data
        cls.passwords = {k: b64.decode(v) for k, v in passwords_secret.items()}
        cls.config = pingone_api.PingOneAPITestConfig(
            ss_app_name="pingfederate",
            p1_app_name=f"client-{cls.tenant_name}-pingfederate-admin-sso",
            scopes="p1asPFOperatorRoles",
            url_to_test=f"https://{cls.admin_env_vars['PF_ADMIN_PUBLIC_HOSTNAME']}/pf-admin-api/v1/cluster/status",
            basic_auth_username=cls.admin_env_vars["PF_ADMIN_USER_USERNAME"],
            basic_auth_password=cls.passwords["PF_ADMIN_USER_PASSWORD"],
            p1_user_roles={
                "p1asPingFederateRoles": [
                    f"{cls.environment}-pf-roleadmin",
                ]
            },
            x_xsrf_header="PingFederate",
        )
