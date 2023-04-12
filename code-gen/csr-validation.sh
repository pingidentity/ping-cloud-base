#!/bin/bash

#**********************************************************************************************************************
# This script is for validating the new microservice Helm apps in the Cluster-State-Repo
#   Note: This script does not work on the 'ks-configs' directory, it is intended for the new microservice apps
#         that will be using Helm.
#**********************************************************************************************************************

# if VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x

failures_list=""
RED="\033[0;31m"
NO_COLOR="\033[0m"

# delete any "charts" directories that exist from previous runs to force helm to pull new charts
find . -type d -name "charts" -exec rm -rf {} +

# find all the apps in the CSR directory except k8s-configs, hidden ('.'), or base directories
app_region_paths=$(find . -type d -depth 2 ! -path './k8s-configs*' ! -path './.*' ! -path './*/base')
echo "Validating the following app paths:"
echo "${app_region_paths}"

# validate kustomize build succeeds for each app
for app_path in ${app_region_paths}; do
  result=$( (kustomize build --load-restrictor LoadRestrictionsNone --enable-helm "${app_path}") 2>&1)
  # if kustomize build fails: add to failure list and output the error
  if test $? -ne 0; then
    failures_list="${failures_list}kustomize build: ${app_path}\n"
    # Use printf to print in color
    printf "\n${RED}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    printf "Kustomize build validation for \"${app_path}\" failed with the below error:\n"
    printf "${result}\n"
    printf "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NO_COLOR}\n\n"
  fi
done

# if there are failures fail the script overall
if [[ ${failures_list} != "" ]] ; then
  echo "The following validation checks failed! Please check above error output & fix!"
  printf "${failures_list}"
  exit 1
fi

echo ""
echo "All validations passed!"
