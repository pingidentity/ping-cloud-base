import time
from dataclasses import dataclass
import os

import kubernetes as k8s
import requests
import urllib3

import k8s_utils
from k8s_utils import K8sUtils

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


@dataclass
class Categories:
    pod_status = "podStatus"
    synthetic = "synthetic"
    data = "data"
    connectivity = "connectivity"
    cluster_members = "clusterMembers"


class TestHealthBase(K8sUtils):
    deployment_name = ""
    ping_cloud = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
    health = "health"
    admin_configmap_name = ""
    admin_service_name_env_var = ""
    admin_port_env_var = ""
    label = ""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # Handle cases where the tests are still retrying by killing the pods and running the check
        cls.kill_pods(label=f"role={cls.deployment_name}", namespace=cls.health)
        cls.wait_for_pod_running(label=f"role={cls.deployment_name}", namespace=cls.health)
        cls.wait_for_healthcheck_sent(label=f"role={cls.deployment_name}", namespace=cls.health)

    @classmethod
    def wait_for_healthcheck_sent(cls, label: str, namespace: str):
        pod_names = cls.get_deployment_pod_names(label=label, namespace=namespace)
        watch = k8s.watch.Watch()
        for pod_name in pod_names:
            watch_start = time.time()
            watch_timeout_seconds = 120
            for event in watch.stream(
                func=cls.core_client.read_namespaced_pod_log,
                namespace=namespace,
                name=pod_name,
            ):
                if (
                    event.endswith(".xml")
                    or k8s_utils.timeout_reached(
                        start_time=watch_start, timeout_seconds=watch_timeout_seconds
                    )
                ):
                    watch.stop()
                    return

    def get_test_results(self, suite: str, category: str) -> {}:
        """
        Request test results from the healthcheck service and get a dictionary of the test names and PASS/FAIL result
        :param suite: Test suite
        :param category: Category within the test suite
        :return: Test results dictionary in the format {"test name": "PASS/FAIL", ...}
        """
        response = requests.get(self.endpoint, verify=False)
        return response.json()["health"][suite]["tests"][category]

    def deployment_exists(self):
        deployments = self.app_client.list_namespaced_deployment("health")
        deployment_name = next(
            (
                deployment.metadata.name
                for deployment in deployments.items
                if deployment.metadata.name == self.deployment_name
            ),
            "",
        )
        self.assertEqual(
            self.deployment_name,
            deployment_name,
            f"Deployment '{self.deployment_name}' not found in cluster",
        )

    def get_runtime_value_from_pod(self, namespace: str, label: str, script: str, var_name: str) -> str:
        variables = self.run_python_script_in_pod(namespace, label, script)
        return get_variable_value(variables, var_name)

    def assert_admin_api_url_uses_service_name(self, variable_file_path: str, variable_name: str):
        admin_env_vars = self.get_configmap_values(
            self.ping_cloud, self.admin_configmap_name
        )
        admin_service_name = admin_env_vars.get(self.admin_service_name_env_var)
        admin_port = admin_env_vars.get(self.admin_port_env_var)
        expected = f"{admin_service_name}.{self.ping_cloud}:{admin_port}"

        admin_api_endpoint = self.get_runtime_value_from_pod(
            self.health,
            self.label,
            variable_file_path,
            variable_name
        )

        self.assertEqual(expected, admin_api_endpoint)


def get_variable_value(variables: [str], name: str) -> str:
    """
    Get the value of a variable in a list of variables in the format ["name=value",...]
    :param variables: List of variables
    :param name: Variable name
    :return: Value, or empty string if variable name not found
    """
    return next((ev.split("=")[-1] for ev in variables if ev.startswith(name)), "")
