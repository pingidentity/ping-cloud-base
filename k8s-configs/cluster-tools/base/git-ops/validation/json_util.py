import json
import os
import sys


def get_json(file_path):
    """Open and read JSON file"""
    # Verify if file exist and isn't empty
    if not os.path.exists(file_path):
        raise ValueError(f"{file_path} doesn't exist")
    elif os.path.exists(file_path) and os.stat(file_path).st_size == 0:
        raise ValueError(f"{file_path} exists but is empty")

    with open(file_path) as json_file:
        json_dict = json.load(json_file, object_pairs_hook=enforce_json_syntax)
        return json_dict


def enforce_json_syntax(ordered_pairs):
    """Reject Duplicate Keys and spaces within keys"""
    data = {}
    for key, value in ordered_pairs:
        if key in data:
            raise ValueError("Duplicate key found: %r" % (key))
        if " " in key:
            raise ValueError("No spaces are allowed within keys: %r" % (key))
        else:
            data[key] = value

    if len(data) == 0:
        raise ValueError("No keys were found")

    return data


if __name__ == "__main__":
    descriptor_json_file = sys.argv[1]
    get_json(descriptor_json_file)
