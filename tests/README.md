## How to run tests locally
Ensure you have installed:
- Python3.9 `brew install python@3.9`
- Docker https://www.docker.com/products/docker-desktop/
- kubeseal `brew install kubeseal`

To run tests in this directory locally follow the below steps:
- Clone the k8s-deploy-tools repo
- export SHARED_CI_SCRIPTS_DIR=<path to k8s-deploy-tools repo>/ci-scripts
- export PROJECT_DIR=<path to this repo root>
- export ENV_TYPE=<your environment name (dev test stage prod customer-hub)>
# This list of tests has to be skipped for now as they require some fixes.
- export SKIP_TESTS=<tests set in repo gitlab-ci.yml (BRANCH_SKIP_TESTS)>

- run `${SHARED_CI_SCRIPTS_DIR}/test/run-tests.sh <INSERT TEST DIRECTORY> <PATH TO PROPERTIES FILE>`


### Note: If you would like to add a method that can be shared by multiple tests, add it to the ci-scripts/test/test_utils.sh in the k8s-deploy-tools so that it can be shared everywhere.