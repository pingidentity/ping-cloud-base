import subprocess
import sys
from common import core_dns_logging
from kubernetes import client, config
from kubernetes.client.rest import ApiException

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


class K8sManager():


    def __init__(self, logger):
        self.logger = logger

        # Initialize kubernetes client
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

    
    def fetch_kube_dns_endpoints(self):
        self.logger.log("Getting the IP addresses of coredns pods from kube-dns endpoints...")

        kube_dns_endpoints = []
        try:
            v1_endpoints_list = self.k8s_client.list_namespaced_endpoints('kube-system',
                                                                    pretty='pretty_example', 
                                                                    label_selector='k8s-app=kube-dns')
            for v1_endpoints in v1_endpoints_list.items:
                v1_endpoints_subsets = v1_endpoints.subsets
                for v1_endpoint_subset in v1_endpoints_subsets:
                    v1_endpoint_addresses = v1_endpoint_subset.addresses
                    for v1_endpoint_address in v1_endpoint_addresses:
                        kube_dns_endpoints.append(v1_endpoint_address.ip)

        except ApiException as e:
            self.logger.log("Exception when calling CoreV1Api->list_namespaced_endpoints: %s\n" % e, ERROR)
            sys.exit(1)

        if not kube_dns_endpoints:
            raise ValueError("Unable to get local kube-dns endpoint details")

        self.logger.log(f"Found the kube-dns endpoints: {kube_dns_endpoints}")
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
