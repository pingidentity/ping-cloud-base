import pydig
import os
import time
from tabulate import tabulate
from common import core_dns_logging

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


def create_multi_cluster_domain_name(namespace: str, domain_name: str) -> str:
    return f"multi-cluster-domains.{namespace}.{domain_name}."


def get_dns_resolution_var() -> str:
    if "DNS_RESOLUTION_RETRY_SECS" in os.environ:
        env_var = os.environ.get("DNS_RESOLUTION_RETRY_SECS")
        if env_var:
            return env_var

    return ""


class DigManager:

    def __init__(self, logger: core_dns_logging) -> None:
        self.logger = logger

    def get_retry_secs(self) -> float:
        env_var = get_dns_resolution_var()
        if env_var != "":
            try:
                return float(env_var)
            except ValueError:
                self.logger.log(f"DNS_RESOLUTION_RETRY_SECS was not a number '{env_var}'.  Defaulting to 30 secs.",
                                WARNING)

        return 30

    def __query(self, fqdn: str, record_type: str) -> str:

        retry_in_secs = self.get_retry_secs()
        for i in range(0, 3):
            try:
                record = pydig.query(fqdn, record_type)
                if record:
                    # TODO remove
                    self.logger.log("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$4")
                    self.logger.log(f"Found entry {record}")
                    self.logger.log("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$4")

                    return record
                else:
                    self.logger.log(f"Record not found for {fqdn}", WARNING)
            except Exception as error:
                self.logger.log(f"Error retrieving records for {fqdn}", ERROR)

            self.logger.log(f"Retrying query in {retry_in_secs} seconds...")
            time.sleep(retry_in_secs)

        return ''

    def fetch_txt_records(self, fqdn: str, query_description: str) -> list:
        self.logger.log(query_description)

        records = []
        record = self.__query(fqdn, 'TXT')
        if record:
            for line in record:
                replaced_line = str(line).replace('"', "")
                stripped_line = replaced_line.strip()
                for domain in stripped_line.split():
                    records.append(domain.strip())

        self.logger.log(f"Dig query results for {fqdn}: {records}")
        return records

    def fetch_all_cluster_fqdns(self, fqdn: str, query_description: str) -> list:
        multi_cluster_domains = self.fetch_txt_records(fqdn, query_description)
        if len(multi_cluster_domains) > 0:
            return multi_cluster_domains
        else:
            raise ValueError(f"{fqdn} must have at least one FQDN TXT value")

    def fetch_name_to_ip_address(self, names: list, query_description: str) -> dict:
        self.logger.log(query_description)

        name_to_ip_addrs = {}
        for name in names:
            record = self.__query(name, 'A')
            if record:
                self.logger.log(f"record = {record}")
                name_to_ip_addrs[name] = record
            else:
                self.logger.log(f"Unable to resolve: {name}", WARNING)

        # tabulate behaves better after sorting
        if len(name_to_ip_addrs) > 0:
            self.logger.log("Dig query results: ")

            sorted_names_to_addrs = sorted(name_to_ip_addrs.items())
            self.logger.log(tabulate(sorted_names_to_addrs, headers=["FQDNs", "IPs"]))
            print()
        else:
            self.logger.log(f"Dig failed to locate any records when querying: {names}")

        return name_to_ip_addrs

    def get_k8s_domain_to_ip_mappings(self,
                                      namespace: str,
                                      domain_name: str,
                                      ns_filter=lambda x, y: True) -> dict:

        # The multi-cluster-domains recordset in the local
        # Hosted Zone holds a TXT record of all the clusters
        # (regions)
        name = create_multi_cluster_domain_name(namespace, domain_name)
        multi_cluster_domains = self.fetch_all_cluster_fqdns(
            name,
            f"Query the local AWS Route 53 Hosted Zone to get all of the TXT entries for {name}"
        )

        # Use the TXT records to look up the Core DNS IPs of other clusters
        domain_to_ips = {}
        for domain_name in multi_cluster_domains:

            ns = domain_name.split("-endpoints.")[0]
            self.logger.log(f"Using the Route 53 domain name '{domain_name}' to derive the namespace '{ns}'")

            # Omit the current namespace
            # since this method is trying
            # to find the Core DNS IP 
            # addresses for other clusters
            # via Route 53
            if ns_filter(ns, namespace):
                # TODO: refactor logs
                self.logger.log("0000000000000000000000000000000000000000000000000000000000000000000")
                self.logger.log(f"domain_name: {domain_name}, namespace: {namespace}")
                self.logger.log("0000000000000000000000000000000000000000000000000000000000000000000")
                name_to_ip_addrs = self.fetch_name_to_ip_address([domain_name],
                                                                 f"Query to get the Core DNS IP addresses "
                                                                 "for {domain_name}")

                # Using the namespace, derive the Kubernetes
                # domain name and set it as the key in a dict
                # to the list of Core DNS IP addresses 
                if name_to_ip_addrs:
                    domain_to_ips[f"{ns}.svc.cluster.local"] = name_to_ip_addrs.get(domain_name)

        # Sort by key so update to configMap is consistent
        domain_to_ips = sorted(domain_to_ips.items())
        self.logger.log(f"Domain to IP address mappings: {domain_to_ips}")

        return domain_to_ips
