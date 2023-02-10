import sys
from json_util import get_json


def verify_descriptor(descriptor_json):
    """Wrapper method that calls all verification methods"""
    verify_json_schema(descriptor_json)

def verify_json_schema(descriptor_json):
    """Verify hostname and replicas is included and that replicas is a number."""
    regions = descriptor_json.keys()

    """Verify that the descriptor.json has 2 or more regions"""
    if len(regions) < 2:
        raise ValueError(
            "descriptor.json must have 2 or more regions"
        )

    for region in regions:
        if region == "":
            raise ValueError("region value is null within descriptor.json")
        if "hostname" not in descriptor_json[region]:
            raise KeyError("'hostname' key must be present within descriptor.json")
        if "replicas" not in descriptor_json[region]:
            raise KeyError("'replicas' key must be present within descriptor.json")
        if descriptor_json[region]["hostname"] == "":
            raise ValueError("hostname value is null within descriptor.json")
        if not isinstance(descriptor_json[region]["replicas"], int):
            raise ValueError("'replicas' key must be a number within descriptor.json %r"
                             % descriptor_json[region]["replicas"])
        if descriptor_json[region]["replicas"] == 0:
            raise ValueError("replicas value must be greater than zero within descriptor.json")
    
if __name__ == "__main__":
    descriptor_json_file_path = sys.argv[1]
    # Generate descriptor.json as a dict
    descriptor_json = get_json(descriptor_json_file_path)
    verify_descriptor(descriptor_json)
    print("Descriptor.json file is valid")