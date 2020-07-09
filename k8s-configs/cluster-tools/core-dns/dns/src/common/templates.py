import os
import shutil
from common import core_dns_logging 

DEBUG = core_dns_logging.LogLevel.DEBUG
WARNING = core_dns_logging.LogLevel.WARNING
ERROR = core_dns_logging.LogLevel.ERROR


class TemplateManager():


    def __init__(self, logger):
        self.logger = logger


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


    def __get_forwarding_routes(self, domains):
        """
        Generate and return core-dns forward route config
        """
        forward_routes = []
        template = """
        hostname:53 {
            errors
            cache 30
            forward . ip_address
            reload
        }
        """
        for hostname, ips in domains:
            ips.sort()
            processed_template = template.replace("hostname", hostname).replace(
                "ip_address", " ".join(ips)
            )
            forward_routes.append(processed_template)

        forward_routes = "".join(forward_routes)

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


    def prepare_kustomization(self, domains):
        source_templates = "/opt/templates"
        source_overlay_path = f"{source_templates}/patch/overlay"
        source_coredns_file = f"{source_overlay_path}/coredns.yaml"

        target_templates = "/tmp/templates"
        target_overlay_path = f"{target_templates}/patch/overlay"
        target_coredns_file = f"{target_overlay_path}/coredns.yaml"

        self.logger.log(f"Copying templates to: {target_templates}")
        shutil.copytree(f"{source_templates}", f"{target_templates}", symlinks=True)
        self.logger.log(f"Copying {source_coredns_file} to {target_coredns_file}")
        shutil.copyfile(f"{source_coredns_file}", f"{target_coredns_file}")


        forward_route_config = self.__get_forwarding_routes(domains)

        # Merge the forward_routes into a parameterized coredns.yaml file
        merged_config_map = self.__process_template(forward_route_config, source_templates)

        # Output merged config to the writable coredns.yaml 
        self.__write_file(f"{target_coredns_file}", merged_config_map)

        return target_overlay_path 
