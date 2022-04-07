# PingOne Bootstrap Setup/Teardown

PingOne integration to P1AS requires several setup steps. In this directory there are scripts to automatically setup or teardown a new environment and/or scripts to just update the SSM Parameters.

`p1_setup_and_teardown.py` for dev setup will create a P1 environment for a given use case (Workforce or CIAM), as well as deployment ids for the selected apps, a unique admin user (ex: <$USER>_workforce), and update the SSM parameters.

`p1_setup_and_teardown.py` for CICD setup will create a P1 environment for a randomly chosen use case (Workforce or CIAM), as well as deployment ids for all the apps, and update the SSM parameters.

`p1_setup_and_teardown.py` for dev teardown will delete the P1 environment for a given use case (Workforce or CIAM), as well as the deployments ids and unique admin user. It leaves the SSM parameters as is.

`p1_setup_and_teardown.py` for CICD teardown will delete the P1 environment for the cluster and the deployments ids. It leaves the SSM parameters as is.

`setup-pingone-bootstrap-aws-config.sh` will only update SSM parameters

## CI/CD Script Setup
* Note: The CI/CD code path with only execute while running in gitlab
1. Export all required variables
   1. DEPLOYMENTS_CLIENT_ID, DEPLOYMENTS_CLIENT_SECRET, PINGCLOUD_CLIENT_ID, PINGCLOUD_CLIENT_SECRET,
   WORKERAPP_CLIENT_SECRET, WORKERAPP_CLIENT_ID, ORG_ID, ADMIN_ENV_ID, P1_LICENSE_ID, CLUSTER_NAME
2. Run `pip3 install -r requirements.txt`
3. Run `python3 p1_setup_and_teardown.py Setup`


## Dev Script Setup
1. Copy .dev.env.sample to .env and replace the `required` variables with appropriate values
2. Source the .env file
3. Run `./setup.sh` to install a venv and install python modules (if needed)
4. Run `python3 p1_setup_and_teardown.py` from this directory
5. Select `Setup` to create a new environment
6. Select your Environment use case. **Note: while using the scripts you can only have 1 environment for each use case at a time**
7. Check or uncheck each app you would like for your environment
8. Confirm your selection
9. Login to PingOne UI to view your environment


## Dev Manual Setup
1. Follow instructions here: https://docs.google.com/document/d/1b0kVWkKM6D4MUZ0aJSlY0FQFeBIXtAbqXQ-5qFPQvII/edit
2. For Step 4 from the doc:
   1. Copy .dev.env.sample to .env and replace the `required` and `optional` variables with appropriate values
   2. Source the .env file
   3. Run `./setup-pingone-bootstrap-aws-config.sh`

## Dev Script Teardown
1. Copy .dev.env.sample to .env and replace the `required` variables with appropriate values
2. Source the .env file
3. Run `python3 p1_setup_and_teardown.py` from this directory
4. Select `Teardown` to delete an existing environment
5. Select the environment's use case
6. Confirm your selection
7. Login to PingOne UI to confirm your environment is deleted


## CI/CD Script Teardown
* Note: The CI/CD code path with only execute while running in gitlab
1. Export all required variables
   1. DEPLOYMENTS_CLIENT_ID, DEPLOYMENTS_CLIENT_SECRET, PINGCLOUD_CLIENT_ID, PINGCLOUD_CLIENT_SECRET,
      WORKERAPP_CLIENT_SECRET, WORKERAPP_CLIENT_ID, ORG_ID, ADMIN_ENV_ID, P1_LICENSE_ID, CLUSTER_NAME
2. Run `pip3 install -r requirements.txt`
3. Run `python3 p1_setup_and_teardown.py Teardown`
