import sys
import os
import logging
import subprocess
import time
import zipfile
import boto3
import pydig

logging.basicConfig(stream=sys.stdout, level=logging.INFO)

# Delays for 15 seconds, give some time for pod to be ready before making any api calls to AWS.
# This is temporary and can be removed later.
time.sleep(15)

r53_client = boto3.client("route53")


def exec_kubectl(*args):
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

    logging.info(f"exec_kubectl: {cmd_out.stdout}")

    return cmd_out.stdout


def get_namespace(namespace_prefix):
    """
    Check and return existing k8s namespace matching the prefix
    """

    namespace = None

    namespaces = exec_kubectl("get", "ns", "-o" "jsonpath='{.items[*].metadata.name}'",)
    namespace_list = namespaces.split()

    for name in namespace_list:
        if name.startswith(namespace_prefix):
            namespace = name
            break

    logging.info(f"get_namespace: {namespace}")

    return namespace


def strip_txt_val(value):
    """
    Strip string value
    """
    stripped_value = str(value).replace("'", "")
    stripped_value = str(value).replace('"', "")

    return stripped_value.strip()


def get_dns_txt_value(domain_name):
    """
    Query and return TXT record of given domain name.
    """
    txt_list = []
    answers = pydig.query(f"{domain_name}", "TXT")
    for rdata in answers:
        rdata = strip_txt_val(rdata)
        for txt_string in rdata.split():
            txt_list.append(strip_txt_val(txt_string))

    if not answers:
        logging.warning(f"Unable to resolve: {domain_name}")
    else:
        logging.info(f"get_dns_txt_value: {domain_name}: {''.join(txt_list)}")

    return txt_list


def get_hosted_zone_id(domain_name):
    """
    Get route 53 hosted zone id.
    """
    zone_id = None
    response = r53_client.list_hosted_zones()
    hosted_zones = response["HostedZones"]
    for zones in hosted_zones:
        if zones["Name"].rstrip(".") == domain_name.rstrip("."):
            zone_id = zones["Id"].rstrip(".")

    logging.info(f"get_hosted_zone_id: {domain_name}: {zone_id}")

    return zone_id


def update_resource_record_sets(
    zone_id, action, rrs_name, rrs_type, rrs_ttl, rrs_records
):
    """
    Update route 53 hosted zone resource record sets.
    """
    response = r53_client.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={
            "Changes": [
                {
                    "Action": action,
                    "ResourceRecordSet": {
                        "Name": rrs_name,
                        "Type": rrs_type,
                        "TTL": rrs_ttl,
                        "ResourceRecords": [{"Value": rrs_records}],
                    },
                }
            ]
        },
    )

    logging.info(f"update_resource_record_set: {response}")

    return response


def read_file(file_path):
    """
    Read and return file content
    """
    try:
        fh = open(file_path, "r")
    except Exception as Error:
        raise Exception(f"read_file:{Error}")

    file_content = fh.read()
    fh.close()

    logging.info(f"read_file: {file_path}: {file_content}")

    return file_content


def write_file(file_path, data):
    """
    Write content to a file
    """
    try:
        fh = open(file_path, "w")
    except Exception as Error:
        raise Exception(f"write_file:{Error}")

    fh.write(data)
    fh.close()

    logging.info(f"write_file: {file_path}: {data}")


def get_forward_routes_config(domain_endpoint_list):
    """
    Generate and return core-dns forward route config
    """
    forward_routes = []
    template = """
    hostname:53 {
        errors
        cache 30
        forward . ip_address
        reload
    }
    """
    for hostname, ips in domain_endpoint_list:
        ips.sort()
        processed_template = template.replace("hostname", hostname).replace(
            "ip_address", " ".join(ips)
        )
        forward_routes.append(processed_template)

    forward_routes = "".join(forward_routes)

    logging.info(f"get_forward_route_config: {forward_routes}")

    return forward_routes


def merge_configmap(configmap_template, forward_route_config):
    """
    Merge configmap
    """

    processed_template = configmap_template.replace(
        "$forward_routes", forward_route_config
    )

    logging.info(f"merge_configmap: {processed_template}")

    return processed_template


def get_templates(template_file_path, target_path):
    """
    Extract .zip file and return its contents
    """

    try:
        with zipfile.ZipFile(template_file_path, "r") as zip_ref:
            zip_ref.extractall(f"{target_path}/")
    except Exception:
        raise Exception(f"Failed to extract {template_file_path}")

    template_files = os.listdir(f"{target_path}/")

    logging.info(f"get_templates: {template_files}")

    return template_files


def publish_endpoints(namespace, domain_name):
    """
    Check and update R53 with latest endpoints
    """

    # Get current endpoints
    current_endpoints = (
        exec_kubectl(
            "get",
            "endpoints",
            "-n" "kube-system",
            "kube-dns",
            "-o" "jsonpath='{.subsets[*].addresses[*].ip}'",
        )
        .strip("'")
        .split()
    )
    if not current_endpoints:
        raise ValueError("Unable to get current endpoint details, aborting")

    logging.info(f"Current endpoints: {current_endpoints}")

    # Use k8s namespace in r53 to store core-dns endpoint details
    endpoint_domain = f"{namespace}-endpoints.{domain_name}"

    # Check & get endpoints detail stored in r53
    r53_endpoints = get_dns_txt_value(endpoint_domain)

    # Check endpoint details stored in R53 with current endpoint, skip if its same.
    if r53_endpoints:
        logging.info(f"r53_recordset: {r53_endpoints}")

        if set(current_endpoints) == set(r53_endpoints):
            logging.info("Endpoints are up to date no update required, skipping.")

        else:
            # Get hosted zone id matching the domain name
            zone_id = get_hosted_zone_id(domain_name)
            if zone_id is None:
                raise ValueError(
                    f"Unable to find Hosted Zone Id for domain {domain_name}, aborting"
                )

            str_current_endpoints = " ".join('"%s"' % ip for ip in current_endpoints)

            logging.info(
                f"Updating {endpoint_domain} to point to {str_current_endpoints}"
            )

            # Update R53 recordset with latest endpoint details.
            update_resource_record_sets(
                zone_id,
                "UPSERT",
                f"{endpoint_domain}",
                "TXT",
                60,
                str_current_endpoints,
            )


def update_core_dns(parent_domain_name):
    """
    Update core-dns config map with forward route
    """
    source_dir = os.path.dirname(os.path.realpath(__file__))
    target_path = "/tmp/core-dns"
    template_source = f"{source_dir}/core-dns-templates.zip"
    coredns_file = f"{target_path}/templates/patch/overlay/coredns.yaml"
    overlay_path = f"{target_path}/templates/patch/overlay"
    forward_route_template = f"{target_path}/templates/add-forward-routes-coredns.txt"

    # Get template files
    template_files = get_templates(template_source, target_path)
    if not template_files:
        raise Exception("Failed to get template files")

    # multi-cluster-domains recordset in parent r53 hold,
    # - dns name of all child/secondary cluster endpoint
    # - TXT record
    multi_cluster_domains = get_dns_txt_value(
        f"multi-cluster-domains.{parent_domain_name}"
    )

    domain_endpoint_list = {}

    # Get endpoint details of all child/secondary clusters
    for domain_name in multi_cluster_domains:
        ns = domain_name.split("-endpoints.")[0]
        domain_endpoint_list[f"{ns}.svc.cluster.local"] = get_dns_txt_value(domain_name)

    # Sort by key so update to configMap is consistent
    domain_endpoint_list = sorted(domain_endpoint_list.items())

    # Get forward route config
    forward_route_config = get_forward_routes_config(domain_endpoint_list)

    logging.info(forward_route_config)

    configmap_template = read_file(forward_route_template)

    # Merge the forward_routes into a parameterized coredns.yaml file
    configmap_content = merge_configmap(configmap_template, forward_route_config)

    # Write configMap config to a file.
    write_file(coredns_file, configmap_content)

    # update core dns configmap
    exec_kubectl("apply", "-k", overlay_path, "-n", "kube-system")


def main():
    """
    main()

    Required:
        - TENANT_DOMAIN: Environment variable
        - PARENT_TENANT_DOMAIN: Environment variable

    OPTIONAL:
        - NAMESPACE_PREFIX: Environment variable, defaults to 'ping-cloud'
    """
    try:
        if "PARENT_TENANT_DOMAIN" in os.environ:
            parent_domain_name = os.environ.get("PARENT_TENANT_DOMAIN")
        else:
            raise ValueError(
                "Environment variable 'PARENT_TENANT_DOMAIN' is not set, aborting"
            )

        if "TENANT_DOMAIN" in os.environ:
            domain_name = os.environ.get("TENANT_DOMAIN")
        else:
            raise ValueError(
                "Environment variable 'TENANT_DOMAIN' is not set, aborting"
            )

        if "NAMESPACE_PREFIX" in os.environ:
            ns_prefix = os.environ.get("NAMESPACE_PREFIX")
        else:
            ns_prefix = "ping-cloud"

        # Check if namespace with prefix (eg:- ping-cloud) exists.
        namespace = get_namespace(ns_prefix)
        if namespace is None:
            raise ValueError(f"Unable to find namespace with given prefix: {ns_prefix}")

        # Check and update R53 with latest endpoints if required
        publish_endpoints(namespace, domain_name)

        # Update core dns configMap with forward route
        update_core_dns(parent_domain_name)

    except Exception as error:
        logging.error(error)
        sys.exit(1)

    logging.info("Execution completed successfully.")


if __name__ == "__main__":
    main()
