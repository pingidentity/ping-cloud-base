import unittest
from unittest.mock import MagicMock
from common import dig
from common import core_dns_logging

namespace = 'ping-cloud-primary'
tenant_domain = 'pingcloudprimary.ping-demo.com'

txt_records = ['ping-cloud-primary-endpoints.pingcloudprimary.ping-demo.com',
               'ping-cloud-secondary-endpoints.pingcloudsecondary.ping-demo.com',
               'ping-cloud-tertiary-endpoints.pingcloudtertiary.ping-demo.com']
name_to_ip_address = {'ping-cloud-secondary-endpoints.pingcloudsecondary.ping-demo.com': ['10.61.5.130', '10.61.9.16'],
                      'ping-cloud-tertiary-endpoints.pingcloudtertiary.ping-demo.com': ['10.61.4.131', '10.61.8.17']}

primary_k8s_domain = 'ping-cloud-primary.svc.cluster.local'
secondary_k8s_domain = 'ping-cloud-secondary.svc.cluster.local'
tertiary_k8s_domain = 'ping-cloud-tertiary.svc.cluster.local'

logger = core_dns_logging.CoreDnsLogger(False)


class DigTests(unittest.TestCase):

    def setUp(self):
        logger.log("Test get_k8s_domain_to_ip_mappings to verify the output values")
        self.dig_mgr = dig.DigManager(logger)

    def test_dns_retry_sec_happy_path(self):
        self.dig_mgr.__get_dns_resolution_var = MagicMock(return_value="60")
        retry_secs = self.dig_mgr.get_retry_secs()
        self.assertEqual(60, retry_secs, 'The retry_secs should be 60 seconds but was not')

    def test_get_k8s_domain_to_ip_mappings(self):
        # Mock the return values for these 2 methods since
        # they make dig network calls
        self.dig_mgr.fetch_txt_records = MagicMock(return_value=txt_records)
        self.dig_mgr.fetch_name_to_ip_address = MagicMock(return_value=name_to_ip_address)

        domain_to_ips = self.dig_mgr.get_k8s_domain_to_ip_mappings(namespace, tenant_domain)
        self.assertEqual(len(domain_to_ips), 3, 'The length of the domain_to_ips list should be 3')
        logger.log("Verified 3 records returned")

        primary_entry = domain_to_ips[0]
        primary_name = primary_entry[0]
        self.assertEqual(primary_name, primary_k8s_domain, 'The primary_name should be: ' + primary_k8s_domain)
        logger.log('Verified the primary_name was ' + primary_name)

        secondary_entry = domain_to_ips[1]
        secondary_name = secondary_entry[0]
        self.assertEqual(secondary_name, secondary_k8s_domain, 'The secondary_name should be: ' + secondary_k8s_domain)
        logger.log('Verified the secondary_name was ' + secondary_name)

        secondary_ips = secondary_entry[1]
        self.assertEqual(secondary_ips, ['10.61.5.130', '10.61.9.16'],
                         'The secondary IP addresses did not match the expected values: ' + str(secondary_ips))
        logger.log('Verified the secondary_ips were ' + str(secondary_ips))

        tertiary_entry = domain_to_ips[2]
        tertiary_name = tertiary_entry[0]
        self.assertEqual(tertiary_name, tertiary_k8s_domain, 'The tertiary_name should be: ' + tertiary_k8s_domain)
        logger.log('Verified the tertiary_name was ' + tertiary_name)

        tertiary_ips = tertiary_entry[1]
        self.assertEqual(tertiary_ips, ['10.61.4.131', '10.61.8.17'],
                         'The tertiary IP addresses did not match the expected values: ' + str(tertiary_ips))
        logger.log('Verified the tertiary_ips were ' + str(tertiary_ips))


if __name__ == '__main__':
    unittest.main()
