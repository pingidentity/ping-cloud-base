import unittest
import subprocess
import os
import yaml
import tempfile

PCB_DIR = os.getenv("PROJECT_DIR", os.getenv("PCB_PATH", "ping-cloud-base"))
SEAL_SCRIPT_PATH = os.getenv(
    "SEAL_SCRIPT", ("%s/code-gen/seal-secret-values.py" % PCB_DIR)
)
VALUES_FILE_PATH = "values-files/base"

def get_valid_yaml():
    return {
        "global": {
            "sealedSecrets": False,
            "secrets": {
                "test-ns": {"valueone": "VGhpcyBpcyBhIHRlc3Q=", "valuetwo": "dGVzdDI="}
            },
            "customSecrets": {"test-ns": {"test-app": {"valuethree": "dGVzdDM=", "valuefour:": "dGVzdDQ="}}},
        }
    }


class TestSealScript(unittest.TestCase):
    def setUp(self) -> None:
        # Create unique temporary directory for each test
        self.tmp_dir = tempfile.mkdtemp(prefix="test_seal_script_")
        self.values_file = os.path.join(self.tmp_dir, "values.yaml")

        # Create unique cert file in temp directory
        self.cert_file = os.path.join(self.tmp_dir, "cert.pem")

        p1 = subprocess.run(
            args=["kubeseal", "--fetch-cert", "--controller-namespace", "kube-system"],
            capture_output=True,
            text=True,
        )
        if p1.returncode != 0:
            print(p1.stderr)
            raise Exception("Unable to get kubeseal cert. See output above.")
        else:
            with open(self.cert_file, "w") as file:
                try:
                    file.write(p1.stdout)
                except Exception as e:
                    print("Unable to write cert to file")
                    raise e

    def run_seal_script(self, cert) -> subprocess.CompletedProcess:
        p1 = subprocess.run(
            args=["python3", SEAL_SCRIPT_PATH, cert, self.values_file],
            capture_output=True,
            text=True,
        )
        return p1

    def write_values_file(self, values):
        with open(self.values_file, "w") as file:
            try:
                yaml.dump(values, file)
            except Exception as e:
                print("Unable to write values.yaml file")
                raise e

    def test_incorrect_usage(self):
        results = subprocess.run(
            args=["python3", SEAL_SCRIPT_PATH], capture_output=True, text=True
        )
        self.assertEqual(
            results.returncode, 1, "seal script succeeded when not passing in cert file"
        )
        self.assertIn(
            "Error in usage. No cert file passed in.",
            results.stderr,
            "seal script returned incorrect error message",
        )

    def test_values_file_not_exists(self):
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode,
            1,
            "seal script succeeded when values.yaml doesn't exist",
        )
        self.assertIn(
            ("Values file '%s' not found" % self.values_file),
            results.stderr,
            "seal script returned incorrect error message",
        )

    def test_secrets_already_sealed(self):
        # Seal some secrets initially
        self.write_values_file(get_valid_yaml())
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode, 0, "seal script failed when it should have succeeded"
        )
        self.assertIn(
            "secrets were successfully sealed",
            results.stdout,
            "seal script returned incorrect response",
        )

        # Add a secret & run seal script again
        p1 = subprocess.run(
            args=[
                "yq",
                "eval",
                "--inplace",
                '.global.secrets.test-ns += {"valuethree": "VGhpcyBpcyBhIHRlc3Q="} | .global.customSecrets.test-ns.test-app += {"valuefour": "dGVzdA=="}',
                self.values_file,
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            p1.returncode, 0, "could not add additional secret to values.yaml file"
        )
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode, 0, "seal script failed when it should have succeeded"
        )
        self.assertIn(
            "secrets were successfully sealed",
            results.stdout,
            "seal script returned incorrect response",
        )

    def test_secret_decode_error(self):
        self.write_values_file(
            {
                "global": {
                    "sealedSecrets": False,
                    "secrets": {"test-ns": {"valueone": "notbase64encoded"}},
                    "customSecrets": {"test-ns": {"test-app": {"valuetwo": "notbase64encoded"}}},
                }
            }
        )
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode,
            1,
            "seal script succeeded when non-base64encoded value passed",
        )
        self.assertIn(
            "Error sealing secret. See following output",
            results.stderr,
            "seal script returned incorrect error message",
        )

    def test_no_secrets_found(self):
        self.write_values_file({"global": {"sealedSecrets": False, "secrets": {}, "customSecrets": {}}})
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode, 0, "seal script failed when no secrets found"
        )
        self.assertIn(
            "No secrets found to seal",
            results.stdout,
            "seal script returned incorrect response",
        )

    def test_invalid_cert_file(self):
        self.write_values_file(get_valid_yaml())
        results = self.run_seal_script("invalidcert.pem")
        self.assertEqual(
            results.returncode, 1, "seal script succeeded when invalid cert file passed"
        )
        self.assertIn(
            "error: open invalidcert.pem: no such file or directory",
            results.stderr,
            "seal script returned incorrect error message",
        )

    def test_success(self):
        self.write_values_file(get_valid_yaml())
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode, 0, "seal script failed when it should have succeeded"
        )
        self.assertIn(
            "secrets were successfully sealed",
            results.stdout,
            "seal script returned incorrect response",
        )

    def test_empty_secret(self):
        self.write_values_file(
            {
                "global": {
                    "sealedSecrets": False,
                    "secrets": {
                        "test-ns": {
                            "valueone": "VGhpcyBpcyBhIHRlc3Q=",
                            "valuetwo": "",
                            "valuethree": "  ",
                        }
                    },
                    "customSecrets": {
                        "test-ns": {
                            "test-app": {
                                "valuefour": "", 
                                "valuefive": "  "
                            }
                        },
                    }
                }
            }
        )
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode, 0, "seal script failed when it should have succeeded"
        )
        self.assertIn(
            "secrets were successfully sealed",
            results.stdout,
            "seal script returned incorrect response",
        )

        # Get empty base secret value to check it's still empty
        p1 = subprocess.run(
            args=["yq", "-e", ".global.secrets.test-ns.valuetwo", self.values_file],
            capture_output=True,
            text=True,
        )
        self.assertEqual(p1.stdout.strip(), "", "empty secret not still empty")

        p1 = subprocess.run(
            args=["yq", "-e", ".global.secrets.test-ns.valuethree", self.values_file],
            capture_output=True,
            text=True,
        )
        self.assertEqual(p1.stdout.strip(), "", "empty secret not still empty")

        # Get empty custom secret value to check it's still empty
        p1 = subprocess.run(
            args=["yq", "-e", ".global.customSecrets.test-ns.test-app.valuefour", self.values_file],
            capture_output=True,
            text=True,
        )
        self.assertEqual(p1.stdout.strip(), "", "empty secret not still empty")

        p1 = subprocess.run(
            args=["yq", "-e", ".global.customSecrets.test-ns.test-app.valuefive", self.values_file],
            capture_output=True,
            text=True,
        )
        self.assertEqual(p1.stdout.strip(), "", "empty secret not still empty")        

    def test_secret_keys_missing(self):
        self.write_values_file({"global": {"sealedSecrets": False}})
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode, 0, "seal script failed when it should have succeeded"
        )
        self.assertIn(
            "No secrets found to seal",
            results.stdout,
            "seal script returned incorrect response",
        )

    def test_ns_missing_secrets(self):
        self.write_values_file(
            {
                "global": {
                    "sealedSecrets": False,
                    "secrets": {"test-ns": None},
                    "customSecrets": {"test-ns": None},
                }
            }
        )
        results = self.run_seal_script(self.cert_file)
        self.assertEqual(
            results.returncode,
            1,
            "seal script succeeded when secrets were missing under a namespace",
        )
        self.assertIn(
            "Error sealing secrets. See following output:\nNamespace 'test-ns' under key 'secrets' is empty.",
            results.stderr,
            "seal script returned incorrect error message",
        )