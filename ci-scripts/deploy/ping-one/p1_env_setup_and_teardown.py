#!/usr/bin/env python3
import os
import random
import sys
import pathlib
import subprocess
import time
import json
import inquirer
from oauthlib.oauth2 import BackendApplicationClient, InvalidClientError
from requests import Response
from requests.auth import HTTPBasicAuth
from requests_oauthlib import OAuth2Session

# PingOne organization variables
API_LOCATION = "https://api-staging.pingone.com/v1"
TOKEN_ENDPOINT = "https://auth-staging.pingone.com/as/token.oauth2"
# These values are based on the ORG ID (defaults are for the dev PingOne org)
ADMIN_ENV_ID = os.getenv("ADMIN_ENV_ID", "345cb89e-e8b7-4bd1-a3dc-03878c6e626b")
P1_LICENSE_ID = os.getenv("P1_LICENSE_ID", "e9972c10-ff9d-4296-b5a6-21ed069617b0")
WORKERAPP_CLIENT_ID = os.getenv("WORKERAPP_CLIENT_ID", "9b13de77-c499-4bd5-8419-88d3d3cbd814")
WORKERAPP_TOKEN_ENDPOINT = "https://auth-staging.pingone.com/" + ADMIN_ENV_ID + "/as/token"

# common constants
DEPLOYMENT_CLIENT = "DEPLOYMENT_CLIENT"
WORKERAPP_CLIENT = "WORKER_APP_CLIENT"
ADMIN_POP = "Administrators Population"
CUSTOMER = "Customer"
WORKFORCE = "Workforce"
SETUP = "Setup"
TEARDOWN = "Teardown"
PING_ID = "PING_ID"
APP_NAMES = ["PING_ACCESS", "PING_FEDERATE", "PING_DIRECTORY", "PING_CENTRAL"]
GET = "GET"
POST = "POST"
PUT = "PUT"
DELETE = "DELETE"
BASE_REQUIRED_ENV_VARS = ["DEPLOYMENTS_CLIENT_ID", "DEPLOYMENTS_CLIENT_SECRET", "WORKERAPP_CLIENT_SECRET",
                          "ORG_ID", "PINGCLOUD_CLIENT_ID", "PINGCLOUD_CLIENT_SECRET"]
CICD_REQUIRED_ENV_VARS = ["ADMIN_ENV_ID", "P1_LICENSE_ID", "WORKERAPP_CLIENT_ID", "CLUSTER_NAME"]


def api_call(token_session: OAuth2Session, call_type: str, endpoint: str, payload: dict = None,
             headers: dict = None) -> Response:
    if call_type == GET:
        response = token_session.get(url=endpoint, headers=headers)
    elif call_type == PUT:
        response = token_session.put(url=endpoint, data=json.dumps(payload), headers=headers)
    elif call_type == POST:
        response = token_session.post(url=endpoint, data=json.dumps(payload), headers=headers)
    elif call_type == DELETE:
        response = token_session.delete(url=endpoint, headers=headers)
    else:
        raise Exception("%s, %s, %s, & %s are the only supported api call types" % (GET, PUT, POST, DELETE))

    if response.status_code < 200 or response.status_code > 299:
        print("response code is not between 200-299")
        raise Exception(response.json())

    return response


def get_client(client_type: str) -> dict:
    if client_type == DEPLOYMENT_CLIENT:
        client_id = os.getenv("DEPLOYMENTS_CLIENT_ID")
        client_secret = os.getenv("DEPLOYMENTS_CLIENT_SECRET")
        token_endpoint = TOKEN_ENDPOINT
    elif client_type == WORKERAPP_CLIENT:
        client_id = WORKERAPP_CLIENT_ID
        client_secret = os.getenv("WORKERAPP_CLIENT_SECRET")
        token_endpoint = WORKERAPP_TOKEN_ENDPOINT
    else:
        raise Exception("Invalid Client Type")

    auth = HTTPBasicAuth(client_id, client_secret)
    client = BackendApplicationClient(client_id=client_id)
    oauth = OAuth2Session(client=client)
    try:
        token = oauth.fetch_token(
            token_url=token_endpoint, auth=auth
        )
        return {"client_id": client_id,
                "client_secret": client_secret,
                "token_endpoint": token_endpoint,
                "token": token}
    except (InvalidClientError, Exception) as e:
        print("Unable to get access token")
        raise Exception(e)
    finally:
        oauth.close()


class PingOneSetup:

    def __init__(self, action_type: str, deployment: str, app_selection: list[str] = None):
        self.deploy_type = deployment
        self.apps = app_selection
        self.deploymentIds = {}
        self.envId = None
        self.entitlements = None
        self.metadata = None
        self.environment_name = os.getenv("CLUSTER_NAME", os.getenv("USER", "unknown") + "_" + self.deploy_type.lower())
        self.products = None
        workerapp_client = get_client(WORKERAPP_CLIENT)
        self.workerapp_client_session = OAuth2Session(workerapp_client["client_id"],
                                                      token=workerapp_client["token"])
        deployment_client = get_client(DEPLOYMENT_CLIENT)
        self.deployment_client_session = OAuth2Session(deployment_client["client_id"],
                                                       token=deployment_client["token"])

        if action_type == SETUP:
            self.setup()
        else:
            self.teardown()

    def setup(self):
        # check if environment already exists
        if self.get_environment() is not None:
            raise Exception("Environment already exists. Please teardown before proceeding.")

        try:
            self.create_deployment_ids()
            self.create_bom()
            self.create_environment()
        except Exception as e:
            print(e)
            print("Something went wrong... trying to delete any deployment IDs created")
            print("DeploymentIDs: " + str(self.deploymentIds))
            self.delete_deployment_ids()
            sys.exit(1)

        if "CI_SERVER" not in os.environ:
            self.create_admin_user()

        self.create_ssm_params()

    def teardown(self):
        # get environment id
        self.envId = self.get_environment()
        if self.envId is None:
            raise Exception("Environment does not exist.")

        self.get_bom()
        self.undeploy_deployment_ids()
        self.delete_environment()
        self.delete_deployment_ids()

        if "CI_SERVER" not in os.environ:
            self.delete_admin_user()

    def create_deployment_ids(self):
        create_deployment_endpoint = API_LOCATION + "/organizations/" + os.getenv("ORG_ID") + "/deployments"

        # if workforce use case create PingId deployment
        if self.deploy_type == WORKFORCE:
            response = api_call(self.deployment_client_session, POST, create_deployment_endpoint, {
                "deploymentType": "PING_ENTERPRISE",
                "productType": PING_ID,
                "status": "UNINITIALIZED"
            })
            self.deploymentIds[PING_ID] = response.json()["id"]

        # create deploymentIds for selected apps
        for app in self.apps:
            response = api_call(self.deployment_client_session, POST, create_deployment_endpoint, {
                "deploymentType": "PING_CLOUD",
                "productType": app,
                "settings": {
                    "useCaseInstanceType": "DEVELOPMENT"
                },
                "status": "UNDEPLOYED"
            })
            self.deploymentIds[app] = response.json()["id"]

    def delete_deployment_ids(self):
        delete_deployment_endpoint = API_LOCATION + "/organizations/" + os.getenv("ORG_ID") + "/deployments/"

        # delete deployments ids
        for product in self.products:
            if "deployment" in product.keys() and product["type"] != PING_ID:
                try:
                    api_call(self.deployment_client_session, DELETE,
                             delete_deployment_endpoint + product["deployment"]["id"])
                except Exception as e:
                    print("Could not delete " + product["type"] + " " + product["deployment"]["id"])
                    print(e)

    def undeploy_deployment_ids(self):
        reset_deployment_endpoint = API_LOCATION + "/organizations/" + os.getenv("ORG_ID") + "/deployments/"

        for product in self.products:
            if "deployment" in product.keys():
                api_call(self.deployment_client_session, PUT, reset_deployment_endpoint + product["deployment"]["id"],
                         {"status": "UNDEPLOYED"})

    def get_bom(self):
        bom_endpoint = API_LOCATION + "/environments/" + self.envId + "/billOfMaterials"

        response = api_call(self.workerapp_client_session, GET, bom_endpoint)
        self.products = response.json()["products"]

    def create_bom(self):
        self.products = [{"type": "PING_ONE_BASE"}, {"type": "PING_ONE_RISK"}, {"type": "PING_ONE_VERIFY"}]
        if self.deploy_type == WORKFORCE:
            self.products.append({
                "type": PING_ID,
                "description": PING_ID,
                "deployment": {
                    "id": self.deploymentIds[PING_ID]
                },
                "console": {
                    "href": "https://ort-admin.pingone.com/web-portal/cas/config/pingid"
                }
            })
        else:
            self.products.append({"type": "PING_ONE_MFA"})

        for app in self.apps:
            self.products.append({
                "type": app,
                "description": app,
                "deployment": {
                    "id": self.deploymentIds[app]
                }
            })

    def get_admin_user(self):
        get_user_endpoint = API_LOCATION + "/environments/" + ADMIN_ENV_ID + "/users/"

        response = api_call(self.workerapp_client_session, GET, get_user_endpoint)
        for user in response.json()["_embedded"]["users"]:
            if user["name"]["given"] == self.environment_name:
                return user["id"]

        return None

    def create_admin_user(self):
        user_id = self.get_admin_user()
        if user_id is not None:
            return

        # get population ID
        get_pop_endpoint = API_LOCATION + "/environments/" + ADMIN_ENV_ID + "/populations"
        response = api_call(self.workerapp_client_session, GET, get_pop_endpoint)
        pop_id = None
        for population in response.json()["_embedded"]["populations"]:
            if population["name"] == ADMIN_POP:
                pop_id = population["id"]

        if pop_id is None:
            raise Exception("Error getting population ID")

        # get admin role ID
        response = api_call(self.workerapp_client_session, GET, API_LOCATION + "/roles")
        role_id = None
        for role in response.json()["_embedded"]["roles"]:
            if role["name"] == "Environment Admin":
                role_id = role["id"]

        if role_id is None:
            raise Exception("Error Environment Admin Role ID")

        # create unique user
        create_user_endpoint = API_LOCATION + "/environments/" + ADMIN_ENV_ID + "/users"
        api_call(self.workerapp_client_session, POST, create_user_endpoint, {
            "email": self.environment_name + "@example.com",
            "name": {
                "given": self.environment_name,
                "family": "User"
            },
            "population": {
                "id": pop_id
            },
            "username": self.environment_name,
            "password": {
                "value": "2FederateM0re!",
                "forceChange": "true"
            }
        }, {"Content-Type": "application/vnd.pingidentity.user.import+json"})

        time.sleep(5)

        user_id = self.get_admin_user()
        if user_id is None:
            print("Unable to create admin user")
            return

        print("Admin User: " + self.environment_name)

        # assign user admin env role
        assign_role_endpoint = API_LOCATION + "/environments/" + ADMIN_ENV_ID + "/users/" + user_id + "/roleAssignments"
        api_call(self.workerapp_client_session, POST, assign_role_endpoint, {
            "role": {
                "id": role_id
            },
            "scope": {
                "id": ADMIN_ENV_ID,
                "type": "ENVIRONMENT"
            }
        })

        # assign user env role
        assign_role_endpoint = API_LOCATION + "/environments/" + ADMIN_ENV_ID + "/users/" + user_id + "/roleAssignments"
        api_call(self.workerapp_client_session, POST, assign_role_endpoint, {
            "role": {
                "id": role_id
            },
            "scope": {
                "id": self.envId,
                "type": "ENVIRONMENT"
            }
        })

    def delete_admin_user(self):
        user_id = self.get_admin_user()
        if user_id is None:
            return

        delete_user_endpoint = API_LOCATION + "/environments/" + ADMIN_ENV_ID + "/users/"

        api_call(self.workerapp_client_session, DELETE, delete_user_endpoint + user_id)

    def get_environment(self):
        # get pingcloud client
        response = api_call(self.workerapp_client_session, GET, API_LOCATION + "/environments")
        for env in response.json()["_embedded"]["environments"]:
            if env["name"] == self.environment_name:
                print("Environment: " + self.environment_name + " ID: " + env["id"])
                return env["id"]

        return None

    def create_environment(self):
        create_environment_endpoint = API_LOCATION + "/bootstraps"

        # create environment
        api_call(self.workerapp_client_session, POST, create_environment_endpoint, {
            "inputs": {
                "environment": {
                    "name": self.environment_name,
                    "region": "NA",
                    "type": "SANDBOX",
                    "license": {
                        "id": P1_LICENSE_ID,
                        "supportedRegions": ["EU", "NORTH_AMERICA", "AP"]
                    },
                    "organization": {
                        "id": os.getenv("ORG_ID")
                    },
                    "billOfMaterials": {
                        "products": self.products
                    },
                    "description": "P1 dev env auto created"
                }
            },
            "type": "SAMPLE_DATA_TWO_POPULATIONS"
        })

        time.sleep(5)

        # get environment id
        self.envId = self.get_environment()

        if self.envId is None:
            raise Exception("Error getting environment ID")

    def delete_environment(self):
        delete_environment_endpoint = API_LOCATION + "/environments/"

        api_call(self.workerapp_client_session, DELETE, delete_environment_endpoint + self.envId)

    def set_ssm_jsons(self):
        entitlement_apps = self.deploymentIds.copy()
        if self.deploy_type == WORKFORCE:
            entitlement_apps.pop(PING_ID)

        self.entitlements = json.dumps(
            {
                app.replace('_', '').lower(): {"licenseType": "trial"} for app in entitlement_apps
            }
        )

        print("Entitlements: " + self.entitlements)

        self.metadata = json.dumps(
            {
                app.replace('_', '').lower(): self.deploymentIds[app] for app in entitlement_apps
            }
        )

        print("DeploymentIDs: " + self.metadata)

    def create_ssm_params(self):
        self.set_ssm_jsons()
        if self.entitlements is None or self.metadata is None:
            raise Exception("Error setting entitlements or environment metadata")

        os.environ["ENV_ID"] = self.envId
        os.environ["PRODUCT_ENTITLEMENTS"] = self.entitlements
        os.environ["DEPLOYMENT_IDS"] = self.metadata

        command = "bash " + str(pathlib.Path(__file__).parent) + "/setup-pingone-bootstrap-aws-config.sh"
        result = subprocess.call(command, env=None, shell=True)
        if result != 0:
            message = "setup-pingone-bootstrap-aws-config.sh script failed with exit code " + str(result)
            raise Exception(message)


def interactive_execution():
    # Check that all required env vars are set
    if any(env_var not in os.environ for env_var in BASE_REQUIRED_ENV_VARS):
        print("Error... Required Environment Variables are not set")
        sys.exit(1)

    questions = [
        inquirer.List("action_type", message="What would you like to do?", choices=[SETUP, TEARDOWN]),
    ]

    answers = inquirer.prompt(questions)
    action = answers["action_type"]

    if action == TEARDOWN:
        questions = [
            inquirer.List("deploy_answer", message="Environment Type", choices=[CUSTOMER, WORKFORCE]),
        ]

        answers = inquirer.prompt(questions)
        deploy_type = answers["deploy_answer"]
        apps = None

        print("Deleting %s environment for %s" % (deploy_type, os.getenv("USER")))
    else:
        questions = [
            inquirer.List("deploy_answer", message="Environment Use Case", choices=[CUSTOMER, WORKFORCE]),
            inquirer.Checkbox("apps_answer", message="App Selection",
                              choices=APP_NAMES,
                              default=APP_NAMES),
        ]

        answers = inquirer.prompt(questions)
        deploy_type = answers["deploy_answer"]
        apps = answers["apps_answer"]

        print("Creating %s environment with %s apps" % (deploy_type, str(apps)))

    questions = [
        inquirer.Confirm("continue", message="Is this correct?")
    ]

    answers = inquirer.prompt(questions)

    if answers["continue"]:
        print("Starting...")
        PingOneSetup(action, deploy_type, apps)


def cluster_execution():
    # Check that we are running in gitlab
    if "CI_SERVER" not in os.environ:
        print("Error... Must be running in Gitlab CI/CD to execute the script this way")
        sys.exit(1)

    # Check that all required env vars are set
    if any(env_var not in os.environ for env_var in BASE_REQUIRED_ENV_VARS) \
            or any(env_var not in os.environ for env_var in CICD_REQUIRED_ENV_VARS):
        print("Error... Required Environment Variables are not set")
        sys.exit(1)

    # Check that action arg is valid
    action = sys.argv[1]
    if action != SETUP and action != TEARDOWN:
        print("Invalid action in parameters. Must be 'Setup' or 'Teardown'")
        sys.exit(1)

    # Choose random deployment type
    ran_num = random.randint(0, 1)
    if ran_num == 1:
        deploy_type = WORKFORCE
    else:
        deploy_type = CUSTOMER
    print("%s: %s environment with %s apps" % (action, os.getenv("CLUSTER_NAME"), str(APP_NAMES)))
    PingOneSetup(action, deploy_type, APP_NAMES)


if __name__ == "__main__":
    if len(sys.argv) == 1:
        interactive_execution()
    elif len(sys.argv) == 2:
        cluster_execution()
    else:
        print("Error in usage:")
        print("Usage for CI/CD: p1_setup_and_teardown.py <'Setup' or 'Teardown'>")
        print("Usage for devs: p1_setup_and_teardown.py")
