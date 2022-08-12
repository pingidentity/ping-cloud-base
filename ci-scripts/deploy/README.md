# Deploy Script for CI/CD

## Debugging Locally
*WARNING: For ci/cd debug purposes only - this should not be used as part of normal day-to-day development*

YOU are responsible for fixing the ci/cd cluster when testing in this fashion.

To run this script locally, set the following environment variables:
```
SELECTED_KUBE_NAME=ci-cd-CLUSTER_NUMBER KUBECONFIG=~/.kube/CONFIG_OF_CLUSTER_TO_RUN_AGAINST SKIP_CONFIGURE_AWS=true SKIP_CONFIGURE_KUBE=true CI_PROJECT_DIR=~/PATH_TO_REPO/ping-cloud-base CI_COMMIT_REF_SLUG="YOUR_NAME" ./ci-scripts/deploy/deploy.sh
```
