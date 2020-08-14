from unittest.mock import MagicMock
from common import k8s
from common import core_dns_logging

test_kube_dns_endpoints = ['10.61.5.130', '10.61.9.16']


def test_fetch_kube_dns_endpoints():
    logger = core_dns_logging.CoreDnsLogger(False)
    logger.log("Test fetch_kube_dns_endpoints to verify it returns a list of IP strings")
    k8s_mgr = k8s.K8sManager(logger)

    k8s_mgr.get_kube_dns_endpoints = MagicMock(return_value=test_kube_dns_endpoints)

    kube_dns_endpoints = k8s_mgr.fetch_kube_dns_endpoints()
    return kube_dns_endpoints


assert test_fetch_kube_dns_endpoints() == test_kube_dns_endpoints
