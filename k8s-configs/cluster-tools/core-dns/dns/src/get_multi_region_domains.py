import sys
import os
import dns.resolver


def get_dns_txt_value(domain_name):
    return dns.resolver.query(domain_name, "TXT").response.answer[0][-1].strings[0]


def main():
    hostname_ip = {}
    domain_name = f"multi-region-domains.{os.environ.get('TENANT_DOMAIN', 'suraj.ping-demo.com.')}"

    try:
        # Get list of multi region dns name.
        tenant_names = str(get_dns_txt_value(domain_name)).split("'")[1]

        for tenant_name in tenant_names.split():
            endpoints = get_dns_txt_value(
                f"core-dns-endpoints.{tenant_name.rstrip('.')}"
            )
            if endpoints:
                hostname_ip[tenant_name] = endpoints

    except Exception as error:
        print(f"Error: {error}")
        sys.exit(1)

    # TODO: Convert dic to core-dns configmap
    print(hostname_ip)

    print("Execution completed successfully.")


if __name__ == "__main__":
    main()
