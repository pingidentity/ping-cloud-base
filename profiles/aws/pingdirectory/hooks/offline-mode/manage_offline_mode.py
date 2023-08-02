import json
import sys
from json_util import get_json

SERVER_ID_HISTORY = set()
REPLICA_ID_HISTORY = set()
REQUIRED_OFFLINE_WRAPPER_KEYS = {
    "descriptor_json",
    "inst_root",
    "k8s_statefulset_name",
    "local_region",
    "local_ordinal",
    "repl_id_base",
    "repl_id_pd_pod_limit_idx",
    "repl_id_pd_base_dn_limit_idx",
    "https_port_base",
    "ldap_port_base",
    "ldaps_port_base",
    "repl_port_base",
    "port_inc",
    "base_dns",
    "ads_crt_with_new_line_chars",
    "server_version",
}


class ManageOfflineMode:
    def __init__(self, offline_wrapper_json_file_path):
        self.offline_wrapper_json = get_json(offline_wrapper_json_file_path)

        # Verify that the parameters passed from 185-offline-enable-wrapper.sh matches the REQUIRED_OFFLINE_WRAPPER_KEYS
        self._verify_keys()

        # Set all attributes from 185-offline-enable-wrapper.sh as reusable class attributes
        self.descriptor_json = get_json(self.offline_wrapper_json["descriptor_json"])
        self.inst_root = self.offline_wrapper_json["inst_root"]
        self.k8s_statefulset_name = self.offline_wrapper_json["k8s_statefulset_name"]
        self.local_region = self.offline_wrapper_json["local_region"]
        self.local_ordinal = int(self.offline_wrapper_json["local_ordinal"])
        self.repl_id_base = int(self.offline_wrapper_json["repl_id_base"])
        self.repl_id_pd_pod_limit_idx = int(self.offline_wrapper_json["repl_id_pd_pod_limit_idx"])
        self.repl_id_pd_base_dn_limit_idx = int(self.offline_wrapper_json["repl_id_pd_base_dn_limit_idx"])
        self.https_port_base = int(self.offline_wrapper_json["https_port_base"])
        self.ldap_port_base = int(self.offline_wrapper_json["ldap_port_base"])
        self.ldaps_port_base = int(self.offline_wrapper_json["ldaps_port_base"])
        self.repl_port_base = int(self.offline_wrapper_json["repl_port_base"])
        self.port_inc = int(self.offline_wrapper_json["port_inc"])
        self.base_dns = self.offline_wrapper_json["base_dns"].split()
        self.ads_crt_with_new_line_chars = self.offline_wrapper_json[
            "ads_crt_with_new_line_chars"
        ]
        self.server_version = self.offline_wrapper_json["server_version"]

    def generate_topology_file(self):
        topology_json = {"serverInstances": []}

        expected_local_ordinal = (
            -1
        )  # Set to default to -1, as this will be validated later to ensure the calculation is consistent.

        # Loop through all regions from descriptor.json
        for current_region_idx, current_region in enumerate(
            self._get_descriptor_regions()
        ):

            expected_replica_count = self._get_descriptor_replica_count(current_region)

            # While loop through every PingDirectory server within current region
            current_ordinal = 0
            while current_ordinal < expected_replica_count:
                # Reset replication_domain_server_infos list on every while loop iteration
                replication_domain_server_infos = []

                # Generate unique odd replica_id for the base_dns per region
                for base_dn_index, base_dn_name in enumerate(self.base_dns):

                    replica_id = (
                        self.repl_id_base
                        + self.repl_id_pd_pod_limit_idx * current_region_idx
                        + self.repl_id_pd_base_dn_limit_idx * current_ordinal
                        + 2 * base_dn_index
                    )

                    # Ensure replica_id is odd
                    if (replica_id % 2) == 0:
                        replica_id += 1  # force replica_id to be odd

                    # Ensure replica_id isn't a duplicate
                    if replica_id in REPLICA_ID_HISTORY:
                        raise Exception(f"replica_id is a dupe {replica_id}")
                    REPLICA_ID_HISTORY.add(replica_id)

                    replication_domain_server_infos.append(
                        f"{replica_id} {base_dn_name}"
                    )

                # Generate unique even server_id for every PD pod per region
                server_id = (
                    self.repl_id_base
                    + self.repl_id_pd_pod_limit_idx * current_region_idx
                    + self.repl_id_pd_base_dn_limit_idx * current_ordinal
                )  # force server_id to be even

                # Ensure server_id is even
                if (server_id % 2) != 0:
                    raise Exception(f"server_id must be even but was odd {server_id}")

                # Ensure server_id isn't a duplicate
                if server_id in SERVER_ID_HISTORY:
                    raise Exception(f"server_id is a dupe {server_id}")
                SERVER_ID_HISTORY.add(server_id)

                # Get server hostname
                hostname = self._get_descriptor_server_hostname(
                    current_ordinal, current_region
                )

                # The ports to use.
                https_port = self.https_port_base + self.port_inc * current_ordinal

                ldap_port = self.ldap_port_base + self.port_inc * current_ordinal

                ldaps_port = self.ldaps_port_base + self.port_inc * current_ordinal

                repl_port = self.repl_port_base + self.port_inc * current_ordinal

                # Once found appropriate region and ordinal, set expected_local_ordinal. This will be validated later
                if (
                    current_ordinal == self.local_ordinal
                    and current_region == self.local_region
                ):
                    expected_local_ordinal = current_ordinal

                server_instance_info = {
                    "instanceName": f"{self.k8s_statefulset_name}-{current_ordinal}-{current_region}",
                    "clusterName": f"cluster_{self.k8s_statefulset_name}-{current_ordinal}-{current_region}",
                    "location": current_region,
                    "serverRoot": self.inst_root,
                    "hostname": hostname,
                    "ldapPort": ldap_port,
                    "ldapsPort": ldaps_port,
                    "httpsPort": https_port,
                    "replicationPort": repl_port,
                    "replicationServerID": server_id,
                    "startTLSEnabled": "true",
                    "preferredSecurity": "SSL",
                    "listenerCert": self.ads_crt_with_new_line_chars,
                    "product": "DIRECTORY",
                    "productVersion": {"version": self.server_version},
                    "replicationDomainServerInfos": replication_domain_server_infos,
                }

                topology_json["serverInstances"].append(server_instance_info)
                current_ordinal += 1

        # Make sure the instance number calculation is consistent. This should not fail.
        if self.local_ordinal != expected_local_ordinal:
            raise Exception(
                f"Calculation for this server is inconsistent with descriptor.json. Was expecting the region={self.local_region} from the descriptor to have the same local_ordinal={self.local_ordinal} as expected_local_ordinal={expected_local_ordinal}. Please ensure that the region name or replicas count within the descriptor.json is consistent with the environment"
            )

        return topology_json

    def _verify_keys(self):
        for required_key in REQUIRED_OFFLINE_WRAPPER_KEYS:
            if required_key not in self.offline_wrapper_json:
                raise Exception(
                    f"Parameter '{required_key}' is missing from 185-offline-enable-wrapper.sh script"
                )

        if len(REQUIRED_OFFLINE_WRAPPER_KEYS) != len(self.offline_wrapper_json):
            raise Exception(
                f"Too many parameters found in 185-offline-enable-wrapper.sh script. The manage_offline_mode.py script is unaware of extra parameters"
            )

    def _get_descriptor_regions(self):
        return self.descriptor_json.keys()

    def _get_descriptor_server_hostname(self, ordinal, region):
        pd_domain_hostname = self.descriptor_json[region]["hostname"]
        return f"{self.k8s_statefulset_name}-{ordinal}"

    def _get_descriptor_replica_count(self, region):
        return int(self.descriptor_json[region]["replicas"])


if __name__ == "__main__":
    offline_wrapper_json_file_path = sys.argv[1]
    mom = ManageOfflineMode(offline_wrapper_json_file_path)

    # Generate topology file
    topology_json = mom.generate_topology_file()

    # Print topology file to sdout
    print(json.dumps(topology_json, indent=4))
