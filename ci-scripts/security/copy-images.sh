#!/usr/bin/env bash

set -e

test "${VERBOSE}" && set -x

declare -A errors

function docker_command() {
  HOME=/tmp docker "${@:1}"
}

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# login first so we can error immediately if this isn't going to work
# may also need to login to ECR or other repos that we need to pull images from before pushing
cat $ARTIFACTORY_REGISTRY_PW | docker_command login $ARTIFACTORY_URL -u $ARTIFACTORY_REGISTRY_USER --password-stdin

deploy_file=/tmp/deploy.yaml
build_dev_deploy_file "${deploy_file}"

i=0
for image in $(cat $deploy_file | grep "image:" | awk -F: 'BEGIN { OFS=":"} {print $2,$3}' | sort | uniq | tr '\n' ' '); do
  name=""
  
  if [[ "$image" =~ ^public.ecr.aws ]]; then
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=3;i<=NF;i++) {printf $i"/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  elif [[ "$image" =~ ^([a-zA-Z]*(.[a-zA-Z]+)+)/ ]]; then
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=2;i<=NF;i++) {printf $i"/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  else                                                                                                            # dockerhub images without domain
    name="$image"
  fi

  {
    output=$(docker_command pull $image &&
    docker_command tag $image $ARTIFACTORY_URL/$BELUGA_VERSION/$name &&
    docker_command push $ARTIFACTORY_URL/$BELUGA_VERSION/$name &&
    echo "Copied $image to location $ARTIFACTORY_URL/$BELUGA_VERSION/$name")
  } || {
    echo "Error copying $image"
    errors[$image]=$output
  }

  # every 10 images, do a cleanup. This way we can try to take advantage of layer caching but won't fill the system
  if [[ "$i" -eq 10 ]]; then
    docker rmi -f $(docker images -aq)
    i=-1
  fi
  i=$((i+1))
done

if [[ "${#errors[@]}" -ne 0 ]]; then
    for i in "${!errors[@]}"
    do
      echo "$image - ${errors[$i]}"
    done
    if [[ "$FAIL_ON_ERROR" == "false" ]]; then
      exit 0
    fi
    exit 1
fi