import subprocess
import sys
from common import core_dns_logging
from kubernetes import client, config
from kubernetes.client.rest import ApiException

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


class K8sManager:

    def __init__(self, logger):
        self.logger = logger
        self.kube_dns_endpoints = None

        # Initialize kubernetes client
        # to use the credentials of the pod
        config.load_incluster_config()
        self.k8s_client = client.CoreV1Api()

    def get_namespace(self, namespace_prefix):
        self.logger.log(f"Querying Kubernetes to get a namespace with the prefix: {namespace_prefix}")
        namespaces = self.k8s_client.list_namespace(watch=False)
        for namespace in namespaces.items:
            name = namespace.metadata.name
            if name.startswith(namespace_prefix):
                self.logger.log(f"Found the local cluster namespace: {name}")
                return name

        return None

    def get_kube_dns_endpoints(self):

        kube_dns_endpoints = []
        try:
            self.logger.log("Getting the IP addresses of the Core DNS pods from kube-dns endpoints...")
            v1_endpoints_list = self.k8s_client.list_namespaced_endpoints('kube-system',
                                                                          pretty='pretty_example',
                                                                          label_selector='k8s-app=kube-dns')

            for v1_endpoints in v1_endpoints_list.items:
                v1_endpoints_subsets = v1_endpoints.subsets
                for v1_endpoint_subset in v1_endpoints_subsets:
                    v1_endpoint_addresses = v1_endpoint_subset.addresses
                    for v1_endpoint_address in v1_endpoint_addresses:
                        kube_dns_endpoints.append(v1_endpoint_address.ip)

            self.logger.log(f"Found the kube-dns endpoints: {kube_dns_endpoints}")

        except ApiException as e:
            self.logger.log("Exception when calling CoreV1Api->list_namespaced_endpoints: %s\n" % e, ERROR)
            sys.exit(1)

        if not kube_dns_endpoints:
            raise ValueError("Unable to get local kube-dns endpoint details")

        return kube_dns_endpoints

    def fetch_kube_dns_endpoints(self):

        if self.kube_dns_endpoints is None:
            self.logger.log("Did not find the local cluster Core DNS IP addresses in the cache.")
        else:
            self.logger.log(f"Found the local cluster Core DNS IP addresses {self.kube_dns_endpoints} in the cache")
            return self.kube_dns_endpoints

        kube_dns_endpoints = self.get_kube_dns_endpoints()
        self.logger.log("Storing the local cluster Core DNS IP addresses in the cache.")
        self.kube_dns_endpoints = kube_dns_endpoints

        return kube_dns_endpoints

    def exec_kubectl(self, *args):
        """
        Execute kubectl command and return STDOUT
        """
        cmd_out = subprocess.run(
            ["kubectl"] + list(args),
            universal_newlines=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        if cmd_out.returncode:
            raise Exception(f"exec_kubectl: {cmd_out.stderr}")

        self.logger.log(f"exec_kubectl: {cmd_out.stdout}")

        return cmd_out.stdout
