from unittest.mock import MagicMock
import dig
import core_dns_logging

namespace = 'ping-cloud-primary'
tenant_domain = 'pingcloudprimary.ping-demo.com'

txt_records = ['ping-cloud-primary-endpoints.pingcloudprimary.ping-demo.com', 
               'ping-cloud-secondary-endpoints.pingcloudsecondary.ping-demo.com',
               'ping-cloud-ternary-endpoints.pingcloudternary.ping-demo.com']
name_to_ip_address = {'ping-cloud-secondary-endpoints.pingcloudsecondary.ping-demo.com': ['10.61.5.130', '10.61.9.16'],
                      'ping-cloud-ternary-endpoints.pingcloudternary.ping-demo.com': ['10.61.4.131', '10.61.8.17']}

secondary_k8s_domain = 'ping-cloud-secondary.svc.cluster.local'
ternary_k8s_domain = 'ping-cloud-ternary.svc.cluster.local'


logger = core_dns_logging.CoreDnsLogger(False)

def test_get_other_k8s_domain_to_ip_mappings():
    logger.log("Test get_other_k8s_domain_to_ip_mappings to verify the output values")
    dig_mgr = dig.DigManager(logger)

    # Mock the return values for these 2 methods since
    # they make dig network calls
    dig_mgr.fetch_txt_records = MagicMock(return_value = txt_records)
    dig_mgr.fetch_name_to_ip_address = MagicMock(return_value = name_to_ip_address)

    domain_to_ips = dig_mgr.get_other_k8s_domain_to_ip_mappings(namespace, tenant_domain)
    for domain_to_ip in domain_to_ips:
        logger.log(type(domain_to_ip))
        logger.log(domain_to_ip)
    
    return domain_to_ips 



domain_to_ips = test_get_other_k8s_domain_to_ip_mappings()
assert len(domain_to_ips) == 2
logger.log("Verified 2 records returned")

secondary_tuple = domain_to_ips[0]
name = secondary_tuple[0]
assert name == secondary_k8s_domain
ips = secondary_tuple[1]
assert ips == ['10.61.5.130', '10.61.9.16']
logger.log("Secondary values verified")

ternary_tuple = domain_to_ips[1]
name = ternary_tuple[0]
assert name == ternary_k8s_domain
ips = ternary_tuple[1]
assert ips == ['10.61.4.131', '10.61.8.17']
logger.log("Ternary values verified")


