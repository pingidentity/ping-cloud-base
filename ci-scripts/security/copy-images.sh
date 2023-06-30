#!/usr/bin/env bash

set -e

test "${VERBOSE}" && set -x

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# login first so we can error immediately if this isn't going to work
# may also need to login to ECR or other repos that we need to pull images from before pushing
docker login $ARTIFACTORY_URL -u $ARTIFACTORY_REGISTRY_USER -p $ARTIFACTORY_REGISTRY_PW

deploy_file=/tmp/deploy.yaml
build_dev_deploy_file "${deploy_file}"

for image in $(cat $deploy_file | grep "image:" | awk -F: 'BEGIN { OFS=":"} {print $2,$3}' | tr '\n' ' '); do
  name=""
  
  if [[ "$image" =~ ^public.ecr.aws ]]; then
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=3;i<=NF;i++) {printf $i"/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  elif [[ "$image" =~ ^([a-zA-Z]*(.[a-zA-Z]+)+)/ ]]; then
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=2;i<=NF;i++) {printf $i"/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  else                                                                                                            # dockerhub images without domain
    name=$image
  fi
  
  docker pull $image
  docker tag $image $ARTIFACTORY_URL/$BELUGA_VERSION/$name
  docker push $ARTIFACTORY_URL/$BELUGA_VERSION/$name
  echo "Copied $image to location $ARTIFACTORY_URL/$BELUGA_VERSION/$name"
done