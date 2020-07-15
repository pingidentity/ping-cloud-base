import pydig
from tabulate import tabulate
from common import core_dns_logging 

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


class DigManager():


    def __init__(self, logger):
        self.logger = logger


    def __fetch_all_cluster_fqdns(self, fqdn, query_description):
        self.logger.log(query_description)

        multi_cluster_domains = []
        record = pydig.query(fqdn, 'TXT')
        if record:
            for line in record:
                # self.logger.log(f"line = {line}")
                replaced_line = str(line).replace('"', "")
                # self.logger.log(f"replaced_line = {replaced_line}")
                stripped_line = replaced_line.strip()
                # self.logger.log(f"stripped_line = {stripped_line}")
                for domain in stripped_line.split():
                    multi_cluster_domains.append(domain.strip())
            
        self.logger.log(f"Dig query results for {fqdn}: {multi_cluster_domains}")
        if len(multi_cluster_domains) > 0:
            return multi_cluster_domains
        else:
            raise ValueError(f"{fqdn} must have at least one FQDN TXT value")


    def fetch_name_to_ip_address(self, names, query_description):
        self.logger.log(query_description)

        name_to_ip_addrs = {}
        for name in names:
            record = pydig.query(name, 'A')
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


    def get_domain_endpoints(self, namespace, domain_name):

        # The multi-cluster-domains recordset in the local
        # Hosted Zone holds a TXT record of all the clusters
        # (regions)
        name =  f"multi-cluster-domains.{namespace}.{domain_name}."
        multi_cluster_domains = self.__fetch_all_cluster_fqdns(
                        name,
                        f"Query the local AWS Route 53 Hosted Zone to get all of the TXT entries for {name}"
        )

        domain_to_ips = {}

        # Get endpoint details of all clusters
        for domain_name in multi_cluster_domains:
            self.logger.log(f"The domain-name is: {domain_name}", DEBUG)
            ns = domain_name.split("-endpoints.")[0]
            self.logger.log(f"Deriving the namespace {ns}", DEBUG)
            # Omit the current domain since
            # K8s forwarding entries should
            # only contain routes to other
            # domains
            if ns != namespace:
                name_to_ip_addrs = self.fetch_name_to_ip_address([domain_name], "Query to get the XXXXXXX")
                if name_to_ip_addrs:
                    domain_to_ips[f"{ns}.svc.cluster.local"] = name_to_ip_addrs.get(domain_name)

        # Sort by key so update to configMap is consistent
        domain_to_ips = sorted(domain_to_ips.items())
        self.logger.log(f"Domain to IP address mappings: {domain_to_ips}")

        return domain_to_ips 