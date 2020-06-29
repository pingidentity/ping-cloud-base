import sys
import os
import subprocess
import boto3
import dns.resolver


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
    except Exception as error:
        print(f"Error: {error}")
        sys.exit(1)

    print("Execution completed successfully.")


if __name__ == "__main__":
    main()
