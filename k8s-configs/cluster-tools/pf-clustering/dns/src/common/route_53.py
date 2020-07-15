import boto3
import pprint
from common import core_dns_logging 

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


class HostedZoneManager():


    def __init__(self, logger):
        self.logger = logger
        self.r53_client = boto3.client("route53")


    def __build_resource_records(self, ip_addrs):
        # Filter out duplicates
        unique_ip_addrs = set()
        for ip_addr in ip_addrs:
            unique_ip_addrs.add(ip_addr)

        resource_records = []
        for unique_ip_addr in unique_ip_addrs:
            value = {'Value': unique_ip_addr}
            resource_records.append(value)

        self.logger.log(f"Building Resource Records: {resource_records}")
        return resource_records

    
    def fetch_hosted_zone_id(self, domain_name):
        """
        Get route 53 hosted zone id.
        """
        zone_id = None
        
        self.logger.log("Retrieving all of the Hosted Zones...")
        response = self.r53_client.list_hosted_zones()
        hosted_zones = response["HostedZones"]
        self.logger.log(f"Found the Hosted Zones: {hosted_zones}", DEBUG)
        for hosted_zone in hosted_zones:
            name = hosted_zone["Name"].rstrip(".")
            if name == domain_name.rstrip("."):
                zone_id = hosted_zone["Id"].rstrip(".")
                break

        if zone_id is None:
            raise ValueError(f"Unable to find Hosted Zone Id for domain {domain_name}.  Exiting.")

        self.logger.log(f"The domain '{domain_name}' has a hosted zone id of {zone_id}")

        return zone_id
    

    def update_resource_record_sets(self, hosted_zone_id, rrs_name, rrs_ttl, ip_addrs, comment):
        """
        Update route 53 hosted zone resource record sets.
        """
        self.logger.log(f"Updating local Core DNS entries in AWS Route 53 {rrs_name}")
        resource_records = self.__build_resource_records(ip_addrs)
        response = self.r53_client.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                'Comment': comment,
                'Changes': [
                    {
                        'Action': 'UPSERT',
                        'ResourceRecordSet': {
                            'Name': rrs_name,
                            'Type': 'A',
                            'TTL': rrs_ttl,
                            'ResourceRecords': resource_records
                        }
                    }
                ]
            })

        self.logger.log("Route 53 record set change response: ")
        pprint.pprint(response)

        return response
