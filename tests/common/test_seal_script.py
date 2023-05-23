import unittest
import subprocess
import os
import yaml

PCB_DIR = os.getenv("PROJECT_DIR", os.getenv("PCB_PATH", "ping-cloud-base"))
SEAL_SCRIPT_PATH = os.getenv("SEAL_SCRIPT", ("%s/code-gen/seal-secret-values.py" % PCB_DIR))


def run_seal_script(cert) -> subprocess.CompletedProcess:
    p1 = subprocess.run(args=["python3", SEAL_SCRIPT_PATH, cert], capture_output=True, text=True)
    return p1


def get_valid_yaml():
    return {'global': {'sealedSecrets': False, 'secrets': {
        'test-ns': {'test-secret': {'valueone': 'VGhpcyBpcyBhIHRlc3Q=', 'valuetwo': 'dGVzdDI='}}}}}


def write_values_file(values):
    with open("values.yaml", "w") as file:
        try:
            yaml.dump(values, file)
        except Exception as e:
            print("Unable to write values.yaml file")
            raise e


class TestSealScript(unittest.TestCase):
    cert_file = None
    tmp_dir = None

    @classmethod
    def setUpClass(cls) -> None:
        cls.cert_file = "cert.pem"
        p1 = subprocess.run(args=["kubeseal", "--fetch-cert", "--controller-namespace", "kube-system"],
                            capture_output=True, text=True)
        if p1.returncode != 0:
            print(p1.stderr)
            raise Exception("Unable to get kubeseal cert. See output above.")
        else:
            with open(cls.cert_file, "w") as file:
                try:
                    file.write(p1.stdout)
                except Exception as e:
                    print("Unable to write cert to file")
                    raise e

    @classmethod
    def tearDownClass(cls) -> None:
        # Delete cert.pem
        if os.path.exists("cert.pem"):
            os.remove("cert.pem")

    def tearDown(self) -> None:
        # Delete values.yaml
        if os.path.exists("values.yaml"):
            os.remove("values.yaml")

    def test_incorrect_usage(self):
        results = subprocess.run(args=["python3", SEAL_SCRIPT_PATH], capture_output=True, text=True)
        self.assertEqual(results.returncode, 1, "seal script succeeded when not passing in cert file")
        self.assertIn("Error in usage. No cert file passed in.", results.stderr,
                      "seal script returned incorrect error message")

    def test_values_file_not_exists(self):
        results = run_seal_script(self.cert_file)
        self.assertEqual(results.returncode, 1, "seal script succeeded when values.yaml doesn't exist")
        self.assertIn("Values file 'values.yaml' not found", results.stderr,
                      "seal script returned incorrect error message")

    def test_secrets_already_sealed(self):
        write_values_file({'global': {'sealedSecrets': True, 'secrets': {}}})
        results = run_seal_script(self.cert_file)
        self.assertEqual(results.returncode, 1, "seal script succeeded when secrets are already sealed")
        self.assertIn("Secrets have already been sealed", results.stderr, "seal script returned incorrect response")

    def test_no_secrets_found(self):
        write_values_file({'global': {'sealedSecrets': False, 'secrets': {}}})
        results = run_seal_script(self.cert_file)
        self.assertEqual(results.returncode, 0, "seal script failed when no secrets found")
        self.assertIn("No secrets found to seal", results.stdout, "seal script returned incorrect response")

    def test_invalid_cert_file(self):
        write_values_file(get_valid_yaml())
        results = run_seal_script("invalidcert.pem")
        self.assertEqual(results.returncode, 1, "seal script succeeded when invalid cert file passed")
        self.assertIn("error: open invalidcert.pem: no such file or directory", results.stderr,
                      "seal script returned incorrect error message")

    def test_success(self):
        write_values_file(get_valid_yaml())
        results = run_seal_script(self.cert_file)
        self.assertEqual(results.returncode, 0, "seal script failed when it should have succeeded")
        self.assertIn("Secrets successfully sealed!", results.stdout, "seal script returned incorrect response")
