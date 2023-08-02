import sys
from json_util import get_json


def verify_descriptor(descriptor_json, local_region_name, k8s_num_of_replicas):
    """Wrapper method that calls all verification methods"""
    verify_json_schema(descriptor_json)
    verify_local_region_replicas_exist(
        descriptor_json, local_region_name, k8s_num_of_replicas
    )


def verify_json_schema(descriptor_json):
    """Verify hostname and replicas is included and that replicas is a number."""
    regions = descriptor_json.keys()

    for region in regions:
        if "hostname" not in descriptor_json[region]:
            raise ValueError("'hostname' key must be present within descriptor.json")
        if "replicas" not in descriptor_json[region]:
            raise ValueError("'replicas' key must be present within descriptor.json")

        try:
            int(descriptor_json[region]["replicas"])
        except ValueError:
            raise ValueError(
                "'replicas' key must be a number within descriptor.json %r"
                % descriptor_json[region]["replicas"]
            )


def verify_local_region_replicas_exist(
    descriptor_json, local_region_name, k8s_num_of_replicas
):
    """Verify local region of the server is found in the descriptor.json file and that the PingDirectory Statefulset replicas matches"""

    if local_region_name not in descriptor_json:
        raise ValueError(
            "'Region' does not exist in descriptor.json file %r" % local_region_name
        )

    descriptor_replica_count = int(descriptor_json[local_region_name]["replicas"])

    if descriptor_replica_count != int(k8s_num_of_replicas):
        raise ValueError(
            f"descriptor.json replicas={descriptor_replica_count} count doesn't match k8s PingDirectory Statefulset replicas={k8s_num_of_replicas}"
        )


if __name__ == "__main__":
    descriptor_json_file_path = sys.argv[1]
    region_name = sys.argv[2]
    k8s_replicas = sys.argv[3]

    # Generate descriptor.json as a dict
    descriptor_json = get_json(descriptor_json_file_path)

    verify_descriptor(descriptor_json, region_name, k8s_replicas)
