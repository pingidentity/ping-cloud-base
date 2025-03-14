import unittest
import warnings

from k8s_utils import K8sUtils

class TestCustomerIssuer(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.k8s = K8sUtils()
        # Rerun the job to be sure it runs after the self-service API is ready
        cls.k8s.rerun_job(name="customer-p1-connection", namespace="argocd")

    def setUp(self) -> None:
        warnings.filterwarnings("ignore", category=ResourceWarning, message="unclosed <ssl.SSLSocket")
        self.configmap_name = "customer-issuer"
        self.ping_cloud = "ping-cloud"

    def test_customer_issuer_added(self):
        configmap = self.k8s.get_configmap_values(namespace=self.ping_cloud, configmap_name=self.configmap_name)
        self.assertTrue(configmap, f"ConfigMap '{self.configmap_name}' not created")
