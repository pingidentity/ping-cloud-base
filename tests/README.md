## How to run tests locally

To run tests in this directory locally follow the below steps:
- Clone the k8s-deploy-tools repo
- export SHARED_CI_SCRIPTS_DIR=<path to k8s-deploy-tools repo>/ci-scripts
- export PROJECT_DIR=<path to this repo root>
- run `./${SHARED_CI_SCRIPTS_DIR}/test/run-tests.sh <INSERT TEST DIRECTORY>`


### Note: If you would like to add a method that can be shared by multiple tests, add it to the ci-scripts/test/test_utils.sh in the k8s-deploy-tools so that it can be shared everywhere.