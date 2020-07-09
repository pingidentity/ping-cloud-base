import sys
import boto3
import os
from common import core_dns_logging, route_53, dig, k8s, templates

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR

verbose = True if "VERBOSE" in os.environ else False 

logger = core_dns_logging.CoreDnsLogger(verbose)
dig_mgr = dig.DigManager(logger)
k8s_mgr = k8s.K8sManager(logger)
template_mgr = templates.TemplateManager(logger)
hosted_zone_mgr = route_53.HostedZoneManager(logger)

# Initialize route 53 client
r53_client = boto3.client("route53")


def publish_local_coredns_endpoints_to_aws(namespace, domain_name):
    """
    Check and update R53 with latest endpoints
    """
    # Use k8s namespace in r53 to store core-dns endpoint details
    endpoint_domain = f"{namespace}-endpoints.{domain_name}"
    r53_endpoints = dig_mgr.fetch_name_to_ip_address([endpoint_domain],
                                                     f"Query the AWS Route 53 domain '{endpoint_domain}' to get Core DNS IP addresses")

    r53_endpoint_ip_addrs = r53_endpoints.get(endpoint_domain)

    # If the IP addresses are the same then skip
    kube_dns_endpoints = k8s_mgr.fetch_kube_dns_endpoints()
   

    if r53_endpoint_ip_addrs and set(kube_dns_endpoints) == set(r53_endpoint_ip_addrs):
        logger.log("Endpoints are up-to-date no changes are required.")

    else:
        logger.log(f"The Kubernetes DNS IP addresses {kube_dns_endpoints} are different than the Route 53 IP addresses {r53_endpoint_ip_addrs}")
        logger.log("Updating Route 53 entries...")

        # Get hosted zone id matching the domain name
        hosted_zone_id = hosted_zone_mgr.fetch_hosted_zone_id(domain_name)

        # Update R53 recordset with latest endpoint details.
        hosted_zone_mgr.update_resource_record_sets(
            hosted_zone_id,
            f"{endpoint_domain}",
            60,
            kube_dns_endpoints,
            "Multi-Region Kubernetes DNS IPs"
        )


def update_core_dns(namespace, domain_name):
    """
    Update core-dns config map with forward route
    """
    domains = dig_mgr.get_domain_endpoints(namespace, domain_name)

    if domains:
        # Use the forwarding routes to prepare the kustomization
        # templates
        overlay_path = template_mgr.prepare_kustomization(domains)

        # Use kustomize to deterministically patch the K8s DNS ConfigMap
        k8s_mgr.exec_kubectl("apply", "-k", overlay_path, "-n", "kube-system")
    else:
        logger.log("No Kubernetes domains to update.  Exiting.")


def validate_tenant_domain():
    if "TENANT_DOMAIN" in os.environ:
        domain_name = os.environ.get("TENANT_DOMAIN")
        logger.log(f"TENANT_DOMAIN is {domain_name}")
        return domain_name
    else:
        raise ValueError("Environment variable 'TENANT_DOMAIN' is required but not found.  Exiting...")


def validate_namespace():
    namespace_prefix = os.environ.get("NAMESPACE_PREFIX") if "NAMESPACE_PREFIX" in os.environ else "ping-cloud"
    logger.log(f"NAMESPACE_PREFIX is {namespace_prefix}")

    # Check if namespace with prefix (eg:- ping-cloud) exists.
    namespace = k8s_mgr.get_namespace(namespace_prefix)
    if namespace is None:
        raise ValueError(f"Unable to find namespace with given prefix: {namespace_prefix}")
    
    return namespace


def main():
    """
    main()

    Required:
        - TENANT_DOMAIN: Environment variable
        - PARENT_TENANT_DOMAIN: Environment variable

    OPTIONAL:
        - NAMESPACE_PREFIX: Environment variable, defaults to 'ping-cloud'
    """

    logger.log("Starting...")
    logger.log_env_vars()

    try:

        # ping-cloud-mpeterson
        namespace = validate_namespace()

        # mpeterson.ping-demo.com
        domain_name = validate_tenant_domain()

        # Check and update R53 with latest endpoints if required
        publish_local_coredns_endpoints_to_aws(namespace, domain_name)

        # Update core dns configMap with forward route
        update_core_dns(namespace, domain_name)

    except Exception as error:
        logger.log(error, ERROR)
        sys.exit(1)

    logger.log("Execution completed successfully.")


if __name__ == "__main__":
    main()
