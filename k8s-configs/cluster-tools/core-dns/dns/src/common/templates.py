import shutil
from common import core_dns_logging

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


class TemplateManager:

    def __init__(self, logger):
        self.logger = logger
        self.source_templates = "/opt/templates"
        self.source_overlay_path = f"{self.source_templates}/patch/overlay"
        self.source_coredns_file = f"{self.source_overlay_path}/coredns.yaml"
        self.source_forward_route_template_file = f"{self.source_templates}/forward-route-template.yaml"
        self.source_reset_file = f"{self.source_templates}/reset-coredns.yaml"

        self.target_templates = "/tmp/templates"
        self.target_overlay_path = f"{self.target_templates}/patch/overlay"
        self.target_coredns_file = f"{self.target_overlay_path}/coredns.yaml"

        logger.log("Preparing the templates...")
        logger.log(f"Copying templates to: {self.target_templates}")
        shutil.copytree(f"{self.source_templates}", f"{self.target_templates}", symlinks=True)
        logger.log(f"Copying {self.source_coredns_file} to {self.target_coredns_file}")
        shutil.copyfile(f"{self.source_coredns_file}", f"{self.target_coredns_file}")

    def __read_file(self, file_path):
        """
        Read and return file content
        """
        try:
            self.logger.log(f"Reading file {file_path}")
            fh = open(file_path, "r")
            file_content = fh.read()
            fh.close()

            return file_content
        except Exception as Error:
            raise Exception(f"There was an error reading the file {file_path}:{Error}")

    def __write_file(self, file_path, data):
        """
        Write content to a file
        """
        try:
            self.logger.log(f"Writing to {file_path}: {data}")
            fh = open(file_path, "w")
            fh.write(data)
            fh.close()
        except Exception as Error:
            raise Exception(f"There was an error writing the file {file_path}:{Error}")

    def __create_kube_dns_forward_routes(self, k8s_domains_to_ip_addrs, source_templates):
        print()
        forward_routes = []
        template = self.__read_file(f"{source_templates}")

        for hostname, ips in k8s_domains_to_ip_addrs:
            # Inject the IP addresses as a single entry with a space in between
            processed_template = template.replace('$hostname', hostname).replace('$ip_addresses', " ".join(ips))
            forward_routes.append(processed_template)

        forward_routes = ''.join(forward_routes)
        self.logger.log(f"Coredns forwarding routes: {forward_routes}")
        return forward_routes

    def __process_template(self, forward_route_config, source_templates):
        """
        Merge configmap
        """
        add_forward_route_template = self.__read_file(f"{source_templates}/add-forward-routes-coredns.txt")
        processed_template = add_forward_route_template.replace("$forward_routes", forward_route_config)
        self.logger.log(f"Merged configmap: {processed_template}", DEBUG)

        return processed_template

    def apply_forwarding_kustomizations(self, k8s_domains_to_ip_addrs):

        forward_route_config = self.__create_kube_dns_forward_routes(k8s_domains_to_ip_addrs,
                                                                     self.source_forward_route_template_file)

        # Merge the forward_routes into a parameterized coredns.yaml file
        merged_config_map = self.__process_template(forward_route_config, self.source_templates)

        # Output merged config to the writable coredns.yaml 
        self.__write_file(f"{self.target_coredns_file}", merged_config_map)

        return self.target_overlay_path

    def reset_kustomization(self):
        # Overwrite the coredns yaml file with the baseline reset file.
        # When the kustomization is applied, it will remove all forwarding
        # routes.  This is necessary to flush routes when a cluster is 
        # removed for instance.
        self.logger.log("Copying the reset file into position...")
        shutil.copyfile(f"{self.source_reset_file}", f"{self.target_coredns_file}")

        return self.target_overlay_path

    # def parse_dns_data(lines):
#     dns_hostname_ip_addrs = {}

#     for line in lines:
#         key_value = line.strip().split(":")
#         dns_hostname_ip_addrs[key_value[0].strip()] = key_value[1].strip()

#     print()
#     print("Processing DNS entries...")
#     for k, v in dns_hostname_ip_addrs.items(): print(k,v)

#     return dns_hostname_ip_addrs

# def get_template(path):
#     f = open(path, 'r')
#     template = f.read()
#     f.close()

#     return template

# def write_file(path, data):
#     f = open(path, 'w')
#     f.writelines(data)
#     f.close()

# def create_kube_dns_forward_routes(current_cluster_domain_name, dns_hostname_ip_addrs):
#     print()
#     forward_routes = []
#     template = get_template('/opt/templates/forward-route-template.yaml')
#     for k, v in dns_hostname_ip_addrs.items():
#         if current_cluster_domain_name not in k:
#             processed_template = template.replace('$hostname', k).replace('$ip_address', v)
#             forward_routes.append(processed_template)

#     forward_routes = ''.join(forward_routes)
#     print("These are the new yaml kube-dns ConfigMap routes:")
#     print(forward_routes)
#     return forward_routes

# def merge_kube_dns_forward_routes(forward_routes):
#     template = get_template('/opt/templates/add-forward-routes-coredns.txt')
#     processed_template = template.replace('$forward_routes', forward_routes)

#     return processed_template

# def update_core_dns():

#     # We need to get the current cluster domain name from somewhere else
#     current_cluster_domain_name = 'ping-cloud-mpeterson.svc.cluster.local'
#     target_coredns_file = '/opt/templates/patch/overlay/coredns.yaml'
#     overlay_path = '/opt/templates/patch/overlay'

#     lines = get_data()
#     dns_hostname_ip_addrs = parse_dns_data(lines)
#     forward_routes = create_kube_dns_forward_routes(current_cluster_domain_name, dns_hostname_ip_addrs)
#     print()
#     print('Resetting kube-config ConfigMap...')

#     # Overwrite the target_coredns_file with the default
#     # configuration to reset the ConfigMap
#     copyfile('/opt/templates/reset-coredns.yaml', target_coredns_file)

#     # Apply the changes to reset our local cluster kube-dns ConfigMap
#     reset_response = subprocess.run(["kubectl", "apply", "-k", overlay_path, "-n" "kube-system"])
#     print(reset_response)

#     # Merge the forward_routes into a parameterized coredns.yaml file
#     merged_kube_dns_configmap = merge_kube_dns_forward_routes(forward_routes)
#     write_file('/tmp/coredns.yaml', merged_kube_dns_configmap)

#     # Overwrite the target_coredns_file with the new routes
#     # and apply the changes with kustomize to the kube-dns
#     # ConfigMap. This could probably be done in a single write
#     # operation to avoid creating a temp file.
#     move('/tmp/coredns.yaml', target_coredns_file)
#     publish_response = subprocess.run(["kubectl", "apply", "-k", overlay_path, "-n" "kube-system"])
#     print(publish_response)

#     print("Processing Complete.")
