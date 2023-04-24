from pathlib import Path
import os
import sys
import logging
import ruamel.yaml

yaml = ruamel.yaml.YAML()

def validate_yaml_file_data():
    path = os.getcwd()
    logger = logging.getLogger(__name__)
    for file_path in Path(path).rglob("*.[yY][aA][mM][lL]"):
        yaml_file_data = Path(file_path).read_text()
        try:
            yaml_object = yaml.load_all(yaml_file_data)
            yaml.allow_unicode = True
            yaml.default_flow_style = False
            with open(file_path, "w") as write:
                yaml.dump_all(
                    yaml_object,
                    write,
                )
        except yaml.YAMLError as e:
            with open(file_path, "w") as write:
                write.writelines(yaml_file_data)
            logger.error(f"Invalid YAML data in {file_path}: {e}")
        except Exception as e:
            logger.error(f"Error processing {file_path}: {e}")
    logger.info("Validation complete.")

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, stream=sys.stdout)
    validate_yaml_file_data()