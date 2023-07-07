import json
import re
import time

from datetime import datetime
from typing import Optional

import kubernetes
import kubernetes as k8s


def timeout_reached(start_time: float, timeout_seconds: int):
    return time.time() > start_time + timeout_seconds


class K8sUtils:
    """
    Utility class for interacting with a Kubernetes deployment

    Sets up basic kubernetes API clients and helper methods
    """

    batch_client = None
    core_client = None
    network_client = None

    def __init__(self):
        k8s.config.load_kube_config()
        self.app_client = k8s.client.AppsV1Api()
        self.batch_client = k8s.client.BatchV1Api()
        self.core_client = k8s.client.CoreV1Api()
        self.network_client = k8s.client.NetworkingV1Api()

    def get_endpoint(self, substring: str) -> str:
        response = self.network_client.list_ingress_for_all_namespaces(
            _preload_content=False
        )
        routes = json.loads(response.data)
        hostname = next(
            (
                route["spec"]["rules"][0]["host"]
                for route in routes["items"]
                if substring in route["spec"]["rules"][0]["host"]
            ),
            None,
        )
        return f"http://{hostname}"

    def run_job(self, name: str, wait: bool = True) -> k8s.client.V1Job:
        cron_jobs = self.batch_client.list_cron_job_for_all_namespaces()
        try:
            job_body, job_namespace = next(
                (cron_job.spec.job_template, cron_job.metadata.namespace)
                for cron_job in cron_jobs.items
                if cron_job.metadata.name == name
            )
        except StopIteration:
            raise ValueError(f"No cron job named '{name}' found")

        curr_time = datetime.now().strftime("%Y%m%d%H%M%S.%f")
        job_body.metadata.name = f"{name}-test-{curr_time}"
        job = self.batch_client.create_namespaced_job(
            body=job_body, namespace=job_namespace
        )

        if wait:
            self.wait_for_job_complete(job_body.metadata.name, job_namespace)

        return job

    def wait_for_job_complete(self, name: str, namespace: str):
        watch = k8s.watch.Watch()
        for event in watch.stream(
            func=self.core_client.list_namespaced_pod,
            namespace=namespace,
            timeout_seconds=60,
        ):
            if event["object"].metadata.name.startswith(name) and event[
                "object"
            ].status.phase in ["Succeeded", "Failed"]:
                watch.stop()
                return

    def get_deployment_pod_names(self, label: str, namespace: str):
        res = self.core_client.list_namespaced_pod(
            namespace=namespace, label_selector=label
        )
        return [pod.metadata.name for pod in res.items]

    def kill_pods(self, label: str, namespace: str, timeout_seconds: int = 300):
        pod_names = self.get_deployment_pod_names(label=label, namespace=namespace)
        for pod_name in pod_names:
            self.core_client.delete_namespaced_pod(
                name=pod_name,
                namespace=namespace,
                body=k8s.client.V1DeleteOptions(
                    propagation_policy="Foreground", grace_period_seconds=5
                ),
            )
        # Wait for the pods to be deleted
        start_time = time.time()
        for pod_name in pod_names:
            while not timeout_reached(start_time, timeout_seconds):
                try:
                    self.core_client.read_namespaced_pod_status(pod_name, namespace)
                except k8s.client.exceptions.ApiException as e:
                    # The pod has been deleted
                    if e.status == 404:
                        break

    def wait_for_pod_running(self, label: str, namespace: str):
        watch = k8s.watch.Watch()
        for event in watch.stream(
            func=self.core_client.list_namespaced_pod,
            namespace=namespace,
            label_selector=label,
            timeout_seconds=60,
        ):
            if event["object"].status.phase == "Running":
                watch.stop()
                return

    def get_latest_pod_logs(
        self, pod_name: str, container_name: str, pod_namespace: str, log_lines: int
    ):
        pod_logs = self.core_client.read_namespaced_pod_log(
            name=pod_name,
            container=container_name,
            namespace=pod_namespace,
            tail_lines=int(log_lines),
        )
        pod_logs = pod_logs.splitlines()
        return pod_logs

    def wait_for_pod_log(
        self,
        pod_name: str,
        namespace: str,
        log_message: str,
        timeout_seconds: int = 120,
    ):
        """
        Wait until a message has been logged or timeout reached
        :param pod_name: Pod name to watch the logs
        :param namespace: Namespace of pod name
        :param log_message: Log message to wait for
        :param timeout_seconds: Timeout seconds
        """
        pods = self.core_client.list_namespaced_pod(namespace)
        try:
            pod = next(
                pod.metadata.name
                for pod in pods.items
                if pod.metadata.name.startswith(pod_name)
            )
        except StopIteration as err:
            print(f"Pod '{pod_name}' not found. {err}")
            raise

        watch = k8s.watch.Watch()
        watch_start = time.time()
        for event in watch.stream(
            func=self.core_client.read_namespaced_pod_log,
            namespace=namespace,
            name=pod,
        ):
            if log_message in event or timeout_reached(
                start_time=watch_start, timeout_seconds=timeout_seconds
            ):
                watch.stop()
                return

    def get_namespace_names(self):
        namespaces = self.core_client.list_namespace()
        return [ns.metadata.name for ns in namespaces.items]

    def get_first_matching_pod_name(self, namespace: str, label: str) -> str:
        try:
            return next(
                name
                for name in self.get_deployment_pod_names(label, namespace)
            )
        except StopIteration:
            print(
                f"Pod not found for label {label} in namespace {namespace}"
            )
            return ""

    def get_namespaced_secret(
        self, name: str, namespace: str
    ) -> Optional[kubernetes.client.V1Secret]:
        """
        Get a secret from a namespace
        :param name: Name of the secret
        :param namespace: Namespace of the secret
        :return: V1Secret object
        """
        secrets = self.core_client.list_namespaced_secret(namespace)
        return next(
            (
                secret
                for secret in secrets.items
                if secret.metadata.name.startswith(name)
            ),
            None,
        )

    def get_pod_env_vars(self, namespace: str, label: str) -> [str]:
        """
        Exec into a pod and get the environment variables

        :param namespace: Namespace of pod
        :param label: Pod label
        :return: List of environment variables
        """
        pod_name = self.get_first_matching_pod_name(namespace, label)
        if not pod_name:
            return []
        return self.exec_command(namespace, pod_name, ["env"]).split("\n")

    def run_python_script_in_pod(
        self, namespace: str, label: str, script_path: str
    ) -> [str]:
        pod_name = self.get_first_matching_pod_name(namespace, label)
        if not pod_name:
            return []
        return self.exec_command(namespace, pod_name, ["python", script_path]).split(
            "\n"
        )

    def exec_command(self, namespace: str, pod_name: str, command: [str]) -> str:
        """
        Execute a command in a running pod

        :param namespace: Namespace of pod
        :param pod_name: Pod name
        :param command: Command to run in pod
        :return: response
        """
        try:
            res = k8s.stream.stream(
                self.core_client.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                command=command,
                stderr=True,
                stdin=False,
                stdout=True,
                tty=False,
            )
            return res
        except k8s.client.exceptions.ApiException as err:
            print(f"Unable to exec in pod {pod_name}. {err}")
            return ""

    def get_configmap_values(self, namespace: str, configmap_name: str) -> {str: str}:
        try:
            res = self.core_client.read_namespaced_config_map(configmap_name, namespace)
            return res.data
        except k8s.client.exceptions.ApiException as err:
            print(
                f"Unable to get values for configmap {configmap_name} in namespace {namespace}. {err}"
            )
            return {}
