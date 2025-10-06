import tempfile
import os
import sys
import unittest
import requests
import json
import subprocess
import urllib3
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from kubernetes import client, config, stream

# Delegated Admin User
DELEGATED_ADMIN_USER = "admin"
DELEGATED_ADMIN_PASSWORD = "password"
# User that will be added to PingDirectory. The Delegated Admin can search and look this user up.
JOHN_THE_TEST_USER = "john.0"

class TestAccessTokenFlow(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Disable only InsecureRequestWarning warnings
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        # ----------------------------
        # Kubernetes Pre-Test Setup
        # ----------------------------
        # Load the Kubernetes configuration and set the active context to desired
        config.load_kube_config()
        cls.core_v1 = client.CoreV1Api()

        # ----------------------------
        # Selenium Setup
        # ----------------------------
        # Configure Chrome options for headless mode
        chrome_options = Options()

        # Note, I decided to make headless but if another dev is interested.
        # Comment line below if you are running locally. Python will open your Chrome browser and perform test in UI.
        chrome_options.add_argument("--headless=new")  # Run in headless mode in CICD

        # Force Chrome to ignore certificate errors
        # Delegated Admin UI verifies that the browser is trusting the certificate.
        # Delegated Admin will fail if you use a unverified certificate. P1AS actually deploy a fake Lets Encrypt cert
        # in dev CICD. The Fake Lets Encrypt Certificate is what PingDelegator, PingFederate, and PingDirectory UI.
        # are using.
        chrome_options.add_argument("--ignore-certificate-errors")
        chrome_options.add_argument("--no-sandbox")  # Run in Docker
        chrome_options.add_argument("--disable-dev-shm-usage")  # Run in Docker

        # Initialize the Selenium Wire WebDriver
        cls.driver = webdriver.Chrome(options=chrome_options)

    @classmethod
    def tearDownClass(cls):
        # Clean up the Selenium driver and ensure the session is terminated properly
        cls.driver.quit()

    def setUp(self):
        # Define the pod and namespace you want to exec into.
        # Adjust these values as needed.
        self.pingdirectory_pod_name = "pingdirectory-0"
        self.namespace = os.environ.get("PING_CLOUD_NAMESPACE")
        self.assertIsNotNone(self.namespace, "PING_CLOUD_NAMESPACE is None")
        self.pingdirectory_container_name = "pingdirectory"

        # Get PingFederate Admin ConfigMap
        # Assert that the configmap is truthy (i.e., not None and not an empty string)
        pingfederate_admin_configmap_key_value = self.get_pingfederate_admin_value_from_configmap()
        self.assertTrue(pingfederate_admin_configmap_key_value, "Unable to retrieve configmap pingfederate-admin-environment-variables")

        # Get PingDelegator URL e.g. https://pingdelegator.customerName.dev.ping-demo.com
        self.PD_DELEGATOR_PUBLIC_HOSTNAME = pingfederate_admin_configmap_key_value.data.get('PD_DELEGATOR_PUBLIC_HOSTNAME')
        self.assertIsNotNone(self.PD_DELEGATOR_PUBLIC_HOSTNAME, "PD_DELEGATOR_PUBLIC_HOSTNAME is None")
        self.assertNotEqual(self.PD_DELEGATOR_PUBLIC_HOSTNAME, "", "PD_DELEGATOR_PUBLIC_HOSTNAME is empty")
        self.PD_DELEGATOR_PUBLIC_HOSTNAME = f"https://{self.PD_DELEGATOR_PUBLIC_HOSTNAME}"

        # Get PingDirectory HTTPS URL e.g. https://pingdirectory.customerName.dev.ping-demo.com
        # Assert that PD_HTTP_PUBLIC_HOSTNAME is truthy (i.e., not None and not an empty string)
        self.PD_HTTP_PUBLIC_HOSTNAME = pingfederate_admin_configmap_key_value.data.get('PD_HTTP_PUBLIC_HOSTNAME')
        self.assertIsNotNone(self.PD_HTTP_PUBLIC_HOSTNAME, "PD_HTTP_PUBLIC_HOSTNAME is None")
        self.assertNotEqual(self.PD_HTTP_PUBLIC_HOSTNAME, "", "PD_HTTP_PUBLIC_HOSTNAME is empty")
        self.PD_HTTP_PUBLIC_HOSTNAME = f"https://{self.PD_HTTP_PUBLIC_HOSTNAME}"

        # Get PingFederate Engine HTTPS URL e.g. https://pingfederate.customerName.dev.ping-demo.com
        # Assert that PF_ENGINE_PUBLIC_HOSTNAME is truthy (i.e., not None and not an empty string)
        self.PF_ENGINE_PUBLIC_HOSTNAME = pingfederate_admin_configmap_key_value.data.get('PF_ENGINE_PUBLIC_HOSTNAME')
        self.assertIsNotNone(self.PF_ENGINE_PUBLIC_HOSTNAME, "PF_ENGINE_PUBLIC_HOSTNAME is None")
        self.assertNotEqual(self.PF_ENGINE_PUBLIC_HOSTNAME, "", "PF_ENGINE_PUBLIC_HOSTNAME is empty")
        self.PF_ENGINE_PUBLIC_HOSTNAME = f"https://{self.PF_ENGINE_PUBLIC_HOSTNAME}"

        # Copy local file templates/add-users.ldif to pingdirectory-0 pod
        pingdirectory_add_users_local_file = "./templates/add-users.ldif"
        pingdirectory_pod_add_users_remote_file_path = "/tmp/add-users.ldif"
        self.copy_ldap_users_to_pingdirectory_pod(pingdirectory_add_users_local_file, pingdirectory_pod_add_users_remote_file_path)

        # Execute ldapmodify on pingdirectory-0 pod which will add users
        self.add_users(pingdirectory_pod_add_users_remote_file_path)

    def tearDown(self):
        # Copy local file templates/delete-users.ldif to pingdirectory-0 pod
        pingdirectory_delete_users_local_file = "./templates/delete-users.ldif"
        pingdirectory_pod_delete_users_remote_file_path = "/tmp/delete-users.ldif"
        self.copy_ldap_users_to_pingdirectory_pod(pingdirectory_delete_users_local_file, pingdirectory_pod_delete_users_remote_file_path)

        # Execute ldapdelete on pingdirectory-0 pod which will add users
        self.delete_users(pingdirectory_pod_delete_users_remote_file_path)

    def get_pingfederate_admin_value_from_configmap(self):
        return self.core_v1.read_namespaced_config_map(name="pingfederate-admin-environment-variables", namespace=self.namespace)

    def copy_ldap_users_to_pingdirectory_pod(self, local_file_path, pingdirectory_pod_remote_file_path):

        # Get the directory where test.py resides
        base_dir = os.path.dirname(os.path.abspath(__file__))

        # Construct the absolute path of the local file.
        local_ldap_file = os.path.join(base_dir, local_file_path)

        # Verify the file exists.
        if not os.path.exists(local_ldap_file):
            raise FileNotFoundError(f"File not found: {local_ldap_file}")

        # Construct the kubectl cp command
        cmd = [
            "kubectl", "cp", local_ldap_file, f"{self.pingdirectory_pod_name}:{pingdirectory_pod_remote_file_path}",
            "-c", self.pingdirectory_container_name,
            "-n", self.namespace
        ]
        # Run the command
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise Exception(f"kubectl cp failed: {result.stderr}")

    def add_users(self, add_users_file):
        # Execute 'ldapmodify' in the pingdirectory-0 pod using Kubernetes exec API.
        # No need to worry about doing this in other PingDirectory pods because PingDirectory will replicate users to
        # the other pods automatically.
        try:
            resp = stream.stream(
                self.core_v1.connect_get_namespaced_pod_exec,
                self.pingdirectory_pod_name,
                self.namespace,
                container=self.pingdirectory_container_name,
                command=["ldapmodify", "--defaultAdd", "--ldifFile", f"{add_users_file}", "-c"],
                stderr=True,
                stdin=False,
                stdout=True,
                tty=False,
                _preload_content=False
            )

            # This call will block until the command finishes, or the timeout is reached.
            resp.run_forever(timeout=60)

            pod_output = resp.read_stdout()

            # Enable print when needed: stdout of PingDirectory pod for adding users
            # print(f"Output of adding users:\n{pod_output}")
        except Exception as e:
            raise Exception(f"Failed to exec into pod {self.pingdirectory_pod_name} and add users: {e}")

    def delete_users(self, delete_users_file):
        # Execute 'ldapdelete' in the pingdirectory-0 pod using Kubernetes exec API.
        # No need to worry about doing this in other PingDirectory pods because PingDirectory will replicate changes to
        # the other pods automatically.
        try:
            pod_output = stream.stream(
                self.core_v1.connect_get_namespaced_pod_exec,
                self.pingdirectory_pod_name,
                self.namespace,
                container=self.pingdirectory_container_name,
                command=["ldapdelete", "--filename", f"{delete_users_file}", "-c"],
                stderr=True,
                stdin=False,
                stdout=True,
                tty=False
            )

            # Enable print when needed: stdout of PingDirectory pod for deleting users
            # print(f"Output of deleting users:\n{pod_output}")

        except Exception as e:
            raise Exception(f"Failed to exec into pod {self.pingdirectory_pod_name} and delete users: {e}")

    def test_log_into_delegated_admin(self):

        # Step 1: Make a request to Delegated Admin
        self.driver.get(self.PD_DELEGATOR_PUBLIC_HOSTNAME)

        # Use WebDriverWait to wait until Delegated Admin redirect of PingFederate endpoint '/as/authorization.oauth2' is returned.
        wait = WebDriverWait(self.driver, 10)  # wait up to 10 seconds
        wait.until(lambda d: f"{self.PF_ENGINE_PUBLIC_HOSTNAME}/as/authorization.oauth2" in d.current_url)

        self.assertIn(f"{self.PF_ENGINE_PUBLIC_HOSTNAME}/as/authorization.oauth2", self.driver.current_url,
                      f"The browser did not navigate to a URL containing '{self.PF_ENGINE_PUBLIC_HOSTNAME}/as/authorization.oauth2'")


        # After redirect. Wait until the form is done loading in UI.
        form_element = wait.until(EC.presence_of_element_located((By.TAG_NAME, "form")))

        # At this point you should have been redirected to https://PF_ENGINE_PUBLIC_HOSTNAME/as/authorization.oauth2
        # The PingFederate HTML form requires a username and password.
        # This user is the delegated admin that is configured in PingDirectory by default.

        # There's essentially 2 things that configures this default admin user.
        # 1) User is automatically configured as the dedicated admin in P1AS OOTB.
        #    See file: profile-repo/profiles/pingdirectory/pd.profile/dsconfig/12-delegated-admin.dsconfig
        #    Where the default admin user is configured using 'dsconfig':
        #    dsconfig create-delegated-admin-rights \
        #        --set "admin-user-dn:uid=admin,${USER_BASE_DN}"

        # 2) User has to be added to PingDirectory.
        #    This is not done OOTB but this unit test has added 'admin' user to PingDirectory.
        #    See 'add_users' method which was called beforehand in setupClass method.

        # Step 2: Fill out the login form that's presented by PingFederate.
        # Find the <input name="pf.username"> element that is present in PingFederate HTML form to fill in the username.
        self.driver.find_element(By.NAME, "pf.username").clear()
        self.driver.find_element(By.NAME, "pf.username").send_keys(DELEGATED_ADMIN_USER)

        # Find the <input name="pf.pass"> element that is present in PingFederate HTML form to fill in the password.
        self.driver.find_element(By.NAME, "pf.pass").clear()
        self.driver.find_element(By.NAME, "pf.pass").send_keys(DELEGATED_ADMIN_PASSWORD)

        # Step 3: Submit login form.
        # Submit the form element directly.
        form_element.submit()

        # Step 4: Wait for authentication check of PingFederate and redirect back to Delegated Admin UI.
        wait.until(lambda d: f"{self.PD_DELEGATOR_PUBLIC_HOSTNAME}/delegator#/callback" in d.current_url)

        self.assertIn(f"{self.PD_DELEGATOR_PUBLIC_HOSTNAME}/delegator#/callback", self.driver.current_url,
                      f"The browser did not navigate to a URL containing '{self.PD_DELEGATOR_PUBLIC_HOSTNAME}/delegator#/callback'")

        wait.until(lambda d: f"{self.PD_DELEGATOR_PUBLIC_HOSTNAME}/delegator#/search/users" in d.current_url)

        self.assertIn(f"{self.PD_DELEGATOR_PUBLIC_HOSTNAME}/delegator#/search/users", self.driver.current_url,
                      f"The browser did not navigate to a URL containing '{self.PD_DELEGATOR_PUBLIC_HOSTNAME}/delegator#/search/users'")

        # At this point you will be successfully in Delegated Admin UI app.
        # We are now extending the test to do 1 more thing.
        # There's an access_token that PingFederate gives us. We can use that access_token to make requests to PingDirectory HTTP API.
        # Using the PingDirectory API we can search for users within the PingDirectory server using HTTP (note this isn't LDAP).

        # This can be done in Delegated Admin UI. But for simple testing we just want to ensure that a valid access token that was
        # provisioned by PingFederate can be used to retrieve user data from PingDirectory HTTP API.


        # From Delegated Admin UI retrieve the session storage value for the key "oidc.user:PF_ENGINE_PUBLIC_HOSTNAME:dadmin"
        session_value = self.driver.execute_script(
            f"return window.sessionStorage.getItem('oidc.user:{self.PF_ENGINE_PUBLIC_HOSTNAME}:dadmin');"
        )
        self.assertIsNotNone(session_value, "Delegated Admin failed to set Session Storage in web page")

        # Parse the JSON stored in session storage. Retrieve its access token which in this case is a JWT Token.
        data = json.loads(session_value)
        access_token = data.get("access_token")
        self.assertIsNotNone(access_token, "Delegated Admin failed to get access_token from Session Storage in web page")

        # Make a request to PD_HTTP_PUBLIC_HOSTNAME user API.
        # We will query john.0 which this user was added beforehand in setUpClass method
        url = f"{self.PD_HTTP_PUBLIC_HOSTNAME}/dadmin/v2/users?filter={JOHN_THE_TEST_USER}"

        # Create the headers with the Authorization header which will include the access_token/JWT token.
        headers = {
            "Authorization": f"Bearer {access_token}"
        }

        # Make the GET request with the headers.
        response = requests.get(url, headers=headers, verify=False)

        self.assertEqual(response.status_code, 200,
                         f"Resource request failed with status code {response.status_code}")

        print("Delegated Admin login was successful")
        # Only needed for troubleshooting locally
        # print(response.text)

if __name__ == "__main__":
    unittest.main()
