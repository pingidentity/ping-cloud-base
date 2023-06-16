#!/usr/bin/env bash

set -e

test "${VERBOSE}" && set -x

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

deploy_file=/tmp/deploy.yaml
build_dev_deploy_file "${deploy_file}"

docker version

for image in $(cat $deploy_file | grep "image:" | awk -F: 'BEGIN { OFS=":"} {print $2,$3}' | tr '\n' ' '); do
  name=""
  
  if [[ "$image" =~ "^public.ecr.aws" ]]; then
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=3;i<=NF;i++) {printf $i"\/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  elif [[ "$image" =~ "^\w*(\.\w*){1,}.*:.*" ]]; then                                                             # if other repo
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=2;i<=NF;i++) {printf $i"\/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  else                                                                                                            # dockerhub images without domain
    name=$image
  fi
  #docker pull $image
  #docker tag $image $ARTIFACTORY_URL/$BELUGA_VERSION/$name
  #docker push $ARTIFACTORY_URL/$BELUGA_VERSION/$name
  echo "Copied $image to location $ARTIFACTORY_URL/$BELUGA_VERSION/$name"
done