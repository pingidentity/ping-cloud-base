import boto3
import pydig
import os
import botocore
from tabulate import tabulate
import pprint
from common import core_dns_logging, route_53, dig, k8s

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR

verbose = True if "VERBOSE" in os.environ else False 

logger = core_dns_logging.CoreDnsLogger(verbose)
dig_mgr = dig.DigManager(logger)
k8s_mgr = k8s.K8sManager(logger)
hosted_zone_mgr = route_53.HostedZoneManager(logger)

custom_retries = {'total_max_attempts': 5, 'max_attempts': 5, 'mode': 'adaptive'}
botocore_config = botocore.config.Config(retries=custom_retries)
r53_client = boto3.client("route53", config=botocore_config)


def create_endpoints_domain_name(namespace, domain_name):
    return f"{namespace}-endpoints.{domain_name}"


def create_fqdns(domains):
    pingfederate_admin = 'pingfederate-admin-0.pingfederate-admin'
    pingfederate_cluster = 'pingfederate-cluster'

    fqdns = []
    for hostname, ips in domains:
        fqdns.append(f"{pingfederate_admin}.{hostname}")
        fqdns.append(f"{pingfederate_cluster}.{hostname}")

    logger.log("PingFederate domain names to query:")
    for fqdn in fqdns:
        logger.log(fqdn)

    print()

    return fqdns


def build_resource_records(name_to_ip_addrs):
    # Filter out duplicates
    unique_ip_addrs = set()
    for name, ip_addrs in name_to_ip_addrs.items():
        for ip_addr in ip_addrs:
            unique_ip_addrs.add(ip_addr)

    resource_records = []
    for unique_ip_addr in unique_ip_addrs:
        value = {'Value': unique_ip_addr}
        resource_records.append(value)

    logger.log("Gathering IP addresses for a record set: %s", resource_records)
    return resource_records


def dict_to_set_values(dictionary):
    result_set = set()
    for key, values in dictionary.items():
        for value in values:
            result_set.add(value)

    return result_set


def route53_requires_update(existing_r53_ip_addrs, name_to_ip_addrs):
    r53_set = dict_to_set_values(existing_r53_ip_addrs)
    coredns_set = dict_to_set_values(name_to_ip_addrs)

    # Subtract each set to detect differences between them
    r53_records = r53_set.difference(coredns_set)
    kubernetes_records = coredns_set.difference(r53_set)

    # Calculate the length to determine whether
    # an update is needed
    r53_records_length = len(r53_records)
    kubernetes_records_length = len(kubernetes_records)

    if r53_records_length > 0:
        printable_r53_records = {"Route 53 Records not currently in Kubernetes Core DNS": r53_records}
        logger.log(tabulate(printable_r53_records.items(), headers=["Record Type", "IPs"]))
        print()

    if kubernetes_records_length > 0:
        printable_k8s_records = {"K8s Records not currently in Route 53": kubernetes_records}
        logger.log(tabulate(printable_k8s_records.items(), headers=["Record Type", "IPs"]))
        print()

    if r53_records_length > 0 or kubernetes_records_length > 0:
        return True

    logger.log("Route 53 is up-to-date with the correct IP addresses")
    return False


def update_route53(domain_name, name_to_ip_addrs):
    identifier = 'pf-cluster-ip-addrs'
    name = identifier + hosted_zone

    existing_r53_ip_addrs = dig_mgr.fetch_name_to_ip_address([name], "Query AWS Route 53 DNS to get published PingFederate cluster IP addresses")

    # Compare the PingFederate cluster addresses K8s knows about to the PingFederate
    # cluster addresses published earlier to Route 53 to see if Route 53 needs
    # to be refreshed.
    requires_update = route53_requires_update(existing_r53_ip_addrs, name_to_ip_addrs)
    if requires_update:
        logger.log("Route 53 requires an update to record set '%s'", name)

        # Get hosted zone id matching the domain name
        hosted_zone_id = hosted_zone_mgr.fetch_hosted_zone_id(domain_name)

        # Update R53 recordset with latest PF IP addresses.
        hosted_zone_mgr.update_type_a_resource_record_sets(
            hosted_zone_id,
            f"{name}",
            name_to_ip_addrs,
            "PingFederate Cluster IPs"
        )

        logger.log("Route 53 record set change response: ")
        pprint.pprint(response)


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

# Goal:
#
# The objective of this script is to collate the IP addresses of the PingFederate Admin 
# and all of the PingFederate engines across all regions and publish them as an A record
# to the AWS Route 53 Hosted Zone for the local region:
#
# pf-cluster-ip-addrs.mpeterson.ping-demo.com.   10.62.32.34
#                                                10.62.6.188
#                                                10.62.29.125 
#
# Each PingFederate engine then will look for pf-cluster-ip-addrs in it's own Hosted Zone
# and pass all of the known IPs it's own JGroups so it can join the cluster.
#
#
# Assumptions:
# - Route 53 has a TXT record entry like this:
#
#   multi-cluster-domains.ping-cloud-mpeterson.mpeterson.ping-demo.com ->
#         "ping-cloud-mpetersonsecondary-endpoints.mpetersonsecondary.ping-demo.com"
#         "ping-cloud-mpeterson-endpoints.mpeterson.ping-demo.com"
#
# 1) Query the local AWS Route 53 Hosted Zone to get all of the TXT entries for multi-cluster-domains.ping-cloud-mpeterson.mpeterson.ping-demo.com.
#    * This tells the script how many regions there are
#
# 2) Use Dig to query the coredns forwarding routes to get the IPs for all non-local clusters.  For example,
#    if this cronjob is running in the primary region it would look up the core :
#    ping-cloud-mpetersonsecondary-endpoints.mpetersonsecondary.ping-demo.com  ['10.62.21.243', '10.62.61.37']

# 1) Query kubernetes nameserver for local names:
#  - if deployment: dig pingfederate-service?  pingfederate-cluster contains all pf endpoints
#  - if stateful set:
#    - if isPrimary: dig pingfederate-admin-0
#    - loop: dig pingfederate-0...pingfederate-n
#
# 2) Query local k8s dns for each other region:
#  - if deployment: dig pingfederate-service.namespace?  pingfederate-cluster.namespace contains all pf endpoints
#  - if stateful set:
#    - dig pingfederate-admin-0
#    - loop: dig pingfederate-0...pingfederate-n
# 3) Combine all FQDNs + IPs
# 4) Update route53
def main():
    
    logger.log("Starting...")
    logger.log_env_vars()

    namespace = validate_namespace()
    domain_name = validate_tenant_domain()

    domains = dig_mgr.get_k8s_domain_to_ip_mappings(namespace, domain_name)
    fqdns = create_fqdns(domains)
    name_to_ip_addrs = dig_mgr.fetch_name_to_ip_address(fqdns, "Query Kubernetes Core DNS to get PingFederate cluster IP addresses")
    update_route53(domain_name, name_to_ip_addrs)

    logger.log("Execution completed successfully.")


if __name__ == "__main__":
    main()
