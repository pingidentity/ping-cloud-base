#!/bin/bash

#**********************************************************************************************************************
# This script is for validating the new microservice Helm apps in the Cluster-State-Repo
#   Note: This script does not work on the 'k8s-configs' directory, it is intended for the new microservice apps
#         that will be using Helm.
#   Note: If the script throws a "401 unauthorized error" when pulling the chart, try running
#         "helm registry logout public.ecr.aws" in case there is an expired token for the public ECR in the environment
#**********************************************************************************************************************

########################################################################################################################
# Prints script usage
########################################################################################################################
usage() {
  echo "Usage: ${0} --out-dir [OUT_DIR] --region [BUILD_REGION]
  where
    OUT_DIR => OPTIONAL directory to output the Kustomize built yaml files
    BUILD_REGION => OPTIONAL region to build & validate
  "
}

########################################################################################################################
# Pulls all helm charts in the provided directory, so that kustomize runs with locally pulled chart
# This is the workaround for https://github.com/kubernetes-sigs/kustomize/issues/4381
#
# Arguments
#   ${1} -> The directory that contains the helm chart(s) definition.
########################################################################################################################
pull_helm_charts() {
  local app_dir="${1}"

  # make the charts dir if it doesn't exist
  local chart_dir="${app_dir}/charts"
  mkdir -p "${chart_dir}"

  # find all files with "helmCharts" definitions and loop through them
  chart_files=$(grep -Rl "helmCharts:" "${app_dir}")
  for chart_file in ${chart_files}; do
    # determine the number of chart definitions in the kustomization.yaml file
    num_charts=$(yq ".helmCharts | length" "${chart_file}")

    # loop through chart definitions in the file
    for (( i=0; i<num_charts; i++ ))
    do
      # use yq to get the chart's information (repo, version)
      chart_version="$(INDEX="${i}" yq ".helmCharts[strenv(INDEX)].version" "${chart_file}")"
      chart_repo="$(INDEX="${i}" yq ".helmCharts[strenv(INDEX)].repo" "${chart_file}")"
      # pull the chart
      helm pull --untar --untardir "${chart_dir}" "${chart_repo}" --version "${chart_version}"
    done
  done
}

########################################################################################################################
# Removes "charts" directories
########################################################################################################################
cleanup_charts() {
  # find & delete all "charts" directories
  find . -type d -name "charts" -exec rm -rf {} +
}

########################################################################################################################
# Parses arguments passed into the script
########################################################################################################################
parseArgs() {
  # Credit: https://stackoverflow.com/a/14203146/5521736
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --out-dir)
        if test -n "${OUT_DIR}"; then
          echo "OUT_DIR already set"
          usage
          exit 1
        fi
        OUT_DIR="${2}"
        shift # past option
        shift # past value
        ;;
      --region)
        if test -n "${BUILD_REGION}"; then
          echo "BUILD_REGION already set"
          usage
          exit 1
        fi
        BUILD_REGION="${2}"
        echo "Running script on region ${BUILD_REGION}..."
        shift # past option
        shift # past value
        ;;
      -*)
        echo "Unknown option ${1}"
        usage
        exit 1
        ;;
    esac
  done
}

#### SCRIPT START ####

# if VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x
parseArgs "$@"

failures_list=""
RED="\033[0;31m"
NO_COLOR="\033[0m"

# delete any "charts" directories that exist from previous runs to force helm to pull new charts
cleanup_charts

# find all the apps in the CSR directory except k8s-configs, values-files, hidden ('.'), or base directories
app_region_paths=$(find . -maxdepth 2 -mindepth 2 -type d -path "./*${BUILD_REGION}" ! -path './k8s-configs*' ! -path './values-files*' ! -path './.*' ! -path './*/base')

if test -z "${app_region_paths}"; then
  echo "No microservices to validate!"
  exit 0
fi

echo "Validating the following app paths:"
echo "${app_region_paths}"

# validate kustomize build succeeds for each app
for app_path in ${app_region_paths}; do
  # pull the helm charts
  pull_helm_charts "${app_path}"
  
  # kustomize build
  if test -z "${OUT_DIR}"; then
    result=$( (kustomize build --load-restrictor LoadRestrictionsNone --enable-helm "${app_path}" ) 2>&1)
  else
    full_out_dir="${OUT_DIR}/${app_path#./}"
    mkdir -p "${full_out_dir}"
    result=$( (kustomize build --load-restrictor LoadRestrictionsNone --enable-helm --output "${full_out_dir}/uber.yaml" "${app_path}" ) 2>&1)
  fi
  # if kustomize build fails: add to failure list and output the error
  # note: this check needs to be immediately after the above "results=" command so that it can check the exit code
  if test $? -ne 0; then
    failures_list="${failures_list}kustomize build: ${app_path}\n"
    # Use printf to print in color
    printf "\n${RED}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    printf "Kustomize build validation for \"${app_path}\" failed with the below error:\n"
    printf "${result}\n"
    printf "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NO_COLOR}\n\n"
  fi
done

# delete the "charts" directories created from the test
cleanup_charts

# if there are failures fail the script overall
if [[ ${failures_list} != "" ]] ; then
  echo "The following validation checks failed! Please check above error output & fix!"
  printf "${failures_list}"
  exit 1
fi

echo ""
echo "All validations passed!"
