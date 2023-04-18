import os
from pathlib import Path
from ruamel import yaml


def repr_str(dumper, data):
    text_list = [line.rstrip() for line in data.splitlines()]
    fixed_data = "\n".join(text_list)
    if len(data.splitlines()) > 1:
        return dumper.represent_scalar("tag:yaml.org,2002:str", fixed_data, style="|")
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


def validate_yaml_file_data():
    # Get current working directory
    path = os.getcwd()
    # list out folders and files
    for root, directories, files in os.walk(path):
        # list out yaml and yml extension files
        for name in files:
            # condition accept only yaml and yml extension files
            try:
                if name.endswith(".yaml") or name.endswith(".yml"):
                    file_path = os.path.join(root, name)
                    file_directory = os.path.join(root)
                    yaml_file_contents = Path(file_path).read_text()
                    try:
                        yaml_object = yaml.round_trip_load_all(yaml_file_contents)
                        try:
                            yaml.add_representer(str, repr_str, Dumper=yaml.SafeDumper)
                            yaml.representer.SafeRepresenter.add_representer(
                                str, repr_str
                            )
                            with open(file_path, "w") as write:
                                try:
                                    yaml.dump_all(
                                        yaml_object,
                                        write,
                                        allow_unicode=True,
                                        Dumper=yaml.RoundTripDumper,
                                    )
                                except Exception as e:
                                    print("yaml update failed {}".format(os.path.join(root, name)), e)
                        except Exception as e:
                            print(f"No Kind key {file_path}", e)
                    except Exception as e:
                        print(f"invalid yaml {file_path}", e)
            except Exception as e:
                print("yaml file not valid", e)


# call method for output
validate_yaml_file_data()