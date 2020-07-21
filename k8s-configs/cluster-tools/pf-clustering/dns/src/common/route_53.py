import boto3
import pprint
import botocore
from common import core_dns_logging 

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


class HostedZoneManager():


    def __init__(self, logger):
        self.logger = logger
        self.zone_id_cache = None

        custom_retries = {'total_max_attempts': 10, 'mode': 'adaptive'}
        botocore_config = botocore.config.Config(retries=custom_retries)
        self.r53_client = boto3.client("route53", config=botocore_config)


    def build_resource_records(self, entries):
        # Filter out duplicates
        unique_entries = set()
        for entry in entries:
            unique_entries.add(entry)

        resource_records = []
        for unique_entry in unique_entries:
            value = {'Value': unique_entry}
            resource_records.append(value)

        self.logger.log(f"Building Resource Records: {resource_records}")
        return resource_records


    def __get_hosted_zone_id(self, response, domain_name):
        zone_id = None

        # Drill into the response to get the Hosted Zone Id
        hosted_zones = response["HostedZones"]
        self.logger.log(f"Found the Hosted Zones: {hosted_zones}", DEBUG)
        for hosted_zone in hosted_zones:
            name = hosted_zone["Name"].rstrip(".")
            if name == domain_name.rstrip("."):
                zone_id = hosted_zone["Id"].rstrip(".")
                break

        if zone_id is None:
            raise ValueError(f"Unable to find Hosted Zone Id for domain {domain_name}.  Exiting.")

        return zone_id


    def fetch_hosted_zone_id(self, domain_name):
        """
        Get route 53 hosted zone id.
        """
        if not self.zone_id_cache is None:
            # Return on a cache hit
            self.logger.log(f"Found the Hosted Zone Id '{self.zone_id_cache}' in the cache")
            return self.zone_id_cache
        else:
            self.logger.log("Did not find the Hosted Zone Id in the cache.")

        self.logger.log("Retrieving all of the Hosted Zones...")
        response = self.r53_client.list_hosted_zones()
        zone_id = self.__get_hosted_zone_id(response, domain_name)

        self.logger.log(f"The domain '{domain_name}' has a Hosted Zone Id of {zone_id}")
        self.logger.log(f"Storing the Hosted Zone Id in the cache")
        self.zone_id_cache = zone_id

        return zone_id
    

    def update_resource_record_sets(self, hosted_zone_id, rrs_name, comment, type, resource_records):
        """
        Update route 53 hosted zone resource record sets.
        """
        self.logger.log(f"Updating local Core DNS entries in AWS Route 53 {rrs_name}")
        response = self.r53_client.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                'Comment': comment,
                'Changes': [
                    {
                        'Action': 'UPSERT',
                        'ResourceRecordSet': {
                            'Name': rrs_name,
                            'Type': type,
                            'TTL': 60,
                            'ResourceRecords': resource_records
                        }
                    }
                ]
            })

        self.logger.log("Route 53 record set change response: ")
        pprint.pprint(response)

        return response


    def update_type_a_resource_record_sets(self, hosted_zone_id, rrs_name, ip_addrs, comment):
        resource_records = self.build_resource_records(ip_addrs)
        return self.update_resource_record_sets(hosted_zone_id, rrs_name, comment, 'A', resource_records)

