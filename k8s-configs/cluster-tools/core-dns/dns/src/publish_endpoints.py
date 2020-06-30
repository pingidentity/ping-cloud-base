import sys
import os
import subprocess
import boto3
import dns.resolver
import zipfile

from shutil import copyfile, move

r53_client = boto3.client("route53")


def kubectl(*args):
    """
    Execute command and return STDOUT
    """
    cmd_out = subprocess.run(
        ["kubectl"] + list(args),
        universal_newlines=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if cmd_out.returncode:
        print(f"Error: {cmd_out.stderr}")
        sys.exit(cmd_out.returncode)

    return cmd_out.stdout


def get_dns_txt_value(domain_name):
    """
    Query and return TXT record of given domain name.
    """
    try:
        return dns.resolver.query(domain_name, "TXT").response.answer[0][-1].strings[0]
    except dns.exception.DNSException:
        return None


def get_hosted_zone_id(domain_name):
    """
    Get route 53 hosted zone id.
    """
    response = r53_client.list_hosted_zones()
    hosted_zones = response["HostedZones"]
    for zones in hosted_zones:
        if zones["Name"].rstrip(".") == domain_name.rstrip("."):
            return zones["Id"].rstrip(".")


def update_resource_record_sets(
    zone_id, action, rrs_name, rrs_type, rrs_ttl, rrs_records
):
    """
    Update route 53 hosted zone resource record sets.
    """
    return r53_client.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={
            "Changes": [
                {
                    "Action": action,
                    "ResourceRecordSet": {
                        "Name": rrs_name,
                        "Type": rrs_type,
                        "TTL": rrs_ttl,
                        "ResourceRecords": [{"Value": f'"{rrs_records}"'}],
                    },
                }
            ]
        },
    )


# get_data() should return entries
# from a call to the other clusters
# in the same format as what's in
# hostname-ip.txt.  Once that's
# replaced, we can remove that file
# and ConfigMap entry.
def get_data():
    print()
    print("Retrieving DNS data...")

    hostname_ip_file = open('/opt/hostname-ip.txt', 'r')
    lines = hostname_ip_file.readlines()

    print("Retrived the data:")
    print(lines)

    return lines

def parse_dns_data(lines):
    dns_hostname_ip_addrs = {}

    for line in lines:
        key_value = line.strip().split(":")
        dns_hostname_ip_addrs[key_value[0].strip()] = key_value[1].strip()

    print()
    print("Processing DNS entries...")
    for k, v in dns_hostname_ip_addrs.items(): print(k,v)

    return dns_hostname_ip_addrs

def get_template(path):
    f = open(path, 'r')
    template = f.read()
    f.close()

    return template

def write_file(path, data):
    f = open(path, 'w')
    f.writelines(data)
    f.close()

def create_kube_dns_forward_routes(current_cluster_domain_name, dns_hostname_ip_addrs):
    print()
    forward_routes = []
    template = get_template('/opt/templates/forward-route-template.yaml')
    for k, v in dns_hostname_ip_addrs.items():
        if current_cluster_domain_name not in k:
            processed_template = template.replace('$hostname', k).replace('$ip_address', v)
            forward_routes.append(processed_template)

    forward_routes = ''.join(forward_routes)
    print("These are the new yaml kube-dns ConfigMap routes:")
    print(forward_routes)
    return forward_routes

def merge_kube_dns_forward_routes(forward_routes):
    template = get_template('/opt/templates/add-forward-routes-coredns.txt')
    processed_template = template.replace('$forward_routes', forward_routes)

    return processed_template

def update_core_dns():

    # We need to get the current cluster domain name from somewhere else
    current_cluster_domain_name = 'ping-cloud-mpeterson.svc.cluster.local'
    target_coredns_file = '/opt/templates/patch/overlay/coredns.yaml'
    overlay_path = '/opt/templates/patch/overlay'

    lines = get_data()
    dns_hostname_ip_addrs = parse_dns_data(lines)
    forward_routes = create_kube_dns_forward_routes(current_cluster_domain_name, dns_hostname_ip_addrs)
    print()
    print('Resetting kube-config ConfigMap...')

    # Overwrite the target_coredns_file with the default
    # configuration to reset the ConfigMap
    copyfile('/opt/templates/reset-coredns.yaml', target_coredns_file)

    # Apply the changes to reset our local cluster kube-dns ConfigMap
    reset_response = subprocess.run(["kubectl", "apply", "-k", overlay_path, "-n" "kube-system"])
    print(reset_response)

    # Merge the forward_routes into a parameterized coredns.yaml file
    merged_kube_dns_configmap = merge_kube_dns_forward_routes(forward_routes)
    write_file('/tmp/coredns.yaml', merged_kube_dns_configmap)

    # Overwrite the target_coredns_file with the new routes
    # and apply the changes with kustomize to the kube-dns
    # ConfigMap. This could probably be done in a single write
    # operation to avoid creating a temp file.
    move('/tmp/coredns.yaml', target_coredns_file)
    publish_response = subprocess.run(["kubectl", "apply", "-k", overlay_path, "-n" "kube-system"])
    print(publish_response)

    print("Processing Complete.")



def main():
    """ Check endpoint config file and update Route53 """

    if "TENANT_DOMAIN" in os.environ:
        domain_name = os.environ.get("TENANT_DOMAIN")
    else:
        print("Environment variable 'TENANT_DOMAIN' is not set, aborting")
        sys.exit(1)

    record_set = f"core-dns-endpoints.{domain_name}"

    r53_endpoints = get_dns_txt_value(record_set)
    if r53_endpoints:
        r53_endpoints = str(r53_endpoints).split("'")[1].split()

    try:
        current_endpoints = (
            kubectl(
                "get",
                "endpoints",
                "-n" "kube-system",
                "kube-dns",
                "-o" "jsonpath='{.subsets[*].addresses[*].ip}'",
            )
            .strip("'")
            .split()
        )
        print(f"Current endpoints: {current_endpoints}")

        if r53_endpoints:
            print(f"r53 endpoints: {r53_endpoints}")

            if set(current_endpoints) == set(r53_endpoints):
                print("Endpoints are up to date. no update required, skipping.")
                sys.exit(0)

        zone_id = get_hosted_zone_id(domain_name)
        if zone_id:
            str_current_endpoints = " ".join(map(str, current_endpoints))
            print(f"Updating {record_set} to point to {str_current_endpoints}")
            update_resource_record_sets(
                zone_id, "UPSERT", f"{record_set}", "TXT", 60, str_current_endpoints
            )
        else:
            print(f"Unable to find Hosted Zone Id for domain {domain_name}, aborting")
            sys.exit(1)

        print("Prepping files...")
        with zipfile.ZipFile("/opt/core-dns-templates.zip", 'r') as zip_ref:
            zip_ref.extractall("/opt/")

        print("Found these files:")
        files = os.listdir("/opt/")
        print(files)

        update_core_dns()

    except Exception as error:
        print(f"Error: {error}")
        sys.exit(1)

    print("Execution completed successfully.")


if __name__ == "__main__":
    main()
