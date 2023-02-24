import json
import re
import time
import unittest

from datetime import datetime

import kubernetes as k8s


def timeout_reached(start_time: float, timeout_seconds: int):
    return time.time() > start_time + timeout_seconds


class K8sUtils(unittest.TestCase):
    """
    Base class for Healthcheck test suites

    Sets up basic kubernetes API clients and helper methods
    """

    batch_client = None
    core_client = None
    network_client = None
    endpoint = None

    @classmethod
    def setUpClass(cls):
        k8s.config.load_kube_config()
        cls.app_client = k8s.client.AppsV1Api()
        cls.batch_client = k8s.client.BatchV1Api()
        cls.core_client = k8s.client.CoreV1Api()
        cls.network_client = k8s.client.NetworkingV1Api()
        cls.endpoint = cls.get_endpoint("healthcheck")

    @classmethod
    def get_endpoint(cls, substring: str) -> str:
        response = cls.network_client.list_ingress_for_all_namespaces(
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

    @classmethod
    def run_job(cls, name: str, wait: bool = True) -> k8s.client.V1Job:
        cron_jobs = cls.batch_client.list_cron_job_for_all_namespaces()
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
        job = cls.batch_client.create_namespaced_job(
            body=job_body, namespace=job_namespace
        )

        if wait:
            cls.wait_for_job_complete(job_body.metadata.name, job_namespace)

        return job

    @classmethod
    def wait_for_job_complete(cls, name: str, namespace: str):
        watch = k8s.watch.Watch()
        for event in watch.stream(
            func=cls.core_client.list_namespaced_pod,
            namespace=namespace,
            timeout_seconds=60,
        ):
            if event["object"].metadata.name.startswith(name) and event[
                "object"
            ].status.phase in ["Succeeded", "Failed"]:
                watch.stop()
                return

    @classmethod
    def get_deployment_pod_names(cls, label: str, namespace: str):
        res = cls.core_client.list_namespaced_pod(
            namespace=namespace, label_selector=label
        )
        return [pod.metadata.name for pod in res.items]

    @classmethod
    def kill_pods(cls, label: str, namespace: str, timeout_seconds: int = 300):
        pod_names = cls.get_deployment_pod_names(label=label, namespace=namespace)
        for pod_name in pod_names:
            cls.core_client.delete_namespaced_pod(
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
                    cls.core_client.read_namespaced_pod_status(pod_name, namespace)
                except k8s.client.exceptions.ApiException as e:
                    # The pod has been deleted
                    if e.status == 404:
                        break

    @classmethod
    def wait_for_pod_running(cls, label: str, namespace: str):
        watch = k8s.watch.Watch()
        for event in watch.stream(
            func=cls.core_client.list_namespaced_pod,
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

    def get_namespace_names(self):
        namespaces = self.core_client.list_namespace()
        return [
            ns.metadata.name
            for ns in namespaces.items
        ]

    def get_namespaced_pod_names(self, namespace: str, pod_name_pattern: str) -> [str]:
        """
        Get a list of pod_names for pods in a namespace that match a naming pattern
        :param namespace: Namespace to check pod names
        :param pod_name_pattern: Regex pod name pattern to check against pod names
        :returns: {pod_name: pod_IP}
        """
        pods = self.core_client.list_namespaced_pod(namespace)
        return [
            pod.metadata.name
            for pod in pods.items
            if re.search(pod_name_pattern, pod.metadata.name)
        ]
