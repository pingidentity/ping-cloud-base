import sys
import boto3
import os
import time
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


def create_endpoints_domain_name(namespace: str, domain_name: str) -> str:
    return f"{namespace}-endpoints.{domain_name}"


def publish_local_coredns_endpoints_to_aws(namespace: str, domain_name: str):

    endpoint_domain = create_endpoints_domain_name(namespace, domain_name)

    # Look up the K8s Core DNS IPs stored in Route 53
    r53_endpoints = dig_mgr.fetch_name_to_ip_address([endpoint_domain],
                                                     f"Query the AWS Route 53 domain '{endpoint_domain}' to get Core DNS IP addresses")

    # Get just the IPs
    r53_endpoint_ip_addrs = r53_endpoints.get(endpoint_domain)

    # Fetch the K8s Core DNS IPs for the local cluster
    kube_dns_endpoints = k8s_mgr.fetch_kube_dns_endpoints()
   
    # Compare the 2 records
    if r53_endpoint_ip_addrs and set(kube_dns_endpoints) == set(r53_endpoint_ip_addrs):
        logger.log("The Kubernetes DNS IPs match the Route 53 IPs.  Both records are up-to-date no changes are "
                   "required.")

    else:
        logger.log(f"The Kubernetes DNS IP addresses {kube_dns_endpoints} are different than the Route 53 IP addresses {r53_endpoint_ip_addrs}")
        logger.log("Updating the Route 53 entries...")

        # Get hosted zone id matching the domain name
        hosted_zone_id = hosted_zone_mgr.fetch_hosted_zone_id(domain_name)

        # Update R53 recordset with latest endpoint details.
        hosted_zone_mgr.update_type_a_resource_record_sets(
            hosted_zone_id,
            f"{endpoint_domain}",
            kube_dns_endpoints,
            "Multi-Region Kubernetes DNS IPs"
        )


def update_core_dns(namespace, domain_name):
    """
    Update core-dns config map with forwarding routes
    """

    # Query all other clusters to get back
    # the IP addresses of their Core DNS nameservers
    k8s_domains_to_ip_addrs = dig_mgr.get_k8s_domain_to_ip_mappings(namespace, domain_name, lambda x, y: x != y)

    # Reset the entries.  The coredns configmap
    # will not cycle the file if nothing changed.
    overlay_path = template_mgr.reset_kustomization()
    k8s_mgr.exec_kubectl("apply", "-k", overlay_path, "-n", "kube-system")

    if k8s_domains_to_ip_addrs:
        # Use the forwarding routes to prepare the kustomization
        # templates
        overlay_path = template_mgr.apply_forwarding_kustomizations(k8s_domains_to_ip_addrs)

        # Use kustomize to deterministically patch the K8s DNS ConfigMap
        k8s_mgr.exec_kubectl("apply", "-k", overlay_path, "-n", "kube-system")
    else:
        logger.log("No Kubernetes domains to update.  Exiting.")


def validate_tenant_domain() -> str: 
    if "TENANT_DOMAIN" in os.environ:
        domain_name = os.environ.get("TENANT_DOMAIN")
        if domain_name:
            logger.log(f"TENANT_DOMAIN is {domain_name}")
            return domain_name
    
    raise ValueError("Environment variable 'TENANT_DOMAIN' is required but not found.  Exiting...")


def validate_namespace() -> str:
    namespace_prefix = os.environ.get("NAMESPACE_PREFIX") if "NAMESPACE_PREFIX" in os.environ else "ping-cloud"
    logger.log(f"NAMESPACE_PREFIX is {namespace_prefix}")

    # Check if namespace with prefix (eg:- ping-cloud) exists.
    namespace = k8s_mgr.get_namespace(namespace_prefix)
    if namespace is None:
        raise ValueError(f"Unable to find namespace with given prefix: {namespace_prefix}")
    
    return namespace


def create_multi_cluster_domain_entry(namespace: str, domain_name: str, name):

    endpoints_domain_name = create_endpoints_domain_name(namespace, domain_name)
    logger.log(f"Creating a single default TXT entry '{name}' -> '{endpoints_domain_name}'...")

    # Get hosted zone id matching the domain name
    hosted_zone_id = hosted_zone_mgr.fetch_hosted_zone_id(domain_name)
    resource_records = hosted_zone_mgr.build_resource_records([f"\"{endpoints_domain_name}\""])

    # Update R53 recordset with latest endpoint details.
    hosted_zone_mgr.update_resource_record_sets(
        hosted_zone_id, 
        f"{name}",
        "Multi-Region Cluster Entries",
        "TXT",
        resource_records)


def validate_multi_cluster_domain_entry(namespace, domain_name):

    multi_cluster_domains = [] 
    try:
        name = dig_mgr.create_multi_cluster_domain_name(namespace, domain_name)
        multi_cluster_domains = dig_mgr.fetch_txt_records(
            name,
            f"Query the local AWS Route 53 Hosted Zone to verify TXT entries exist for {name}"
        )
    except Exception as error:
        logger.log("There was a problem executing the query:", ERROR)
        logger.log(error, ERROR)

    if not multi_cluster_domains or len(multi_cluster_domains) == 0:
        create_multi_cluster_domain_entry(namespace, domain_name, name)
        logger.log("Waiting for Route 53 changes to take effect...")
        time.sleep(90)
        

# At a high level this CronJob is doing 2 things:
#
# 1) It's getting the coredns IP addresses of the local nameservers
#    and publishing them to Route 53
#
# 2) It's getting the coredns IP addresses of all the other clusters
#    and updating the forwarding routes of the local nameservers so
#    queries within the local cluster will be sent to the right IP
#    in another cluster.
def main():
    """
    main()

    Required:
        - TENANT_DOMAIN: Environment variable

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

        # Test to make sure the Hosted Zone has a
        # multi-cluster-domain entry
        validate_multi_cluster_domain_entry(namespace, domain_name)

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
