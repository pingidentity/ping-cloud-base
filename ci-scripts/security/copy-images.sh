#!/usr/bin/env bash

set -e

test "${VERBOSE}" && set -x

errors=()

function docker_command() {
  HOME=/tmp docker "${@:1}"
}

# login first so we can error immediately if this isn't going to work
# may also need to login to ECR or other repos that we need to pull images from before pushing
if [[ $DRY_RUN == true ]]; then
  echo "*DRY RUN* Logging into Artifactory repo"
else
  cat $ARTIFACTORY_REGISTRY_PW | docker_command login $ARTIFACTORY_URL -u $ARTIFACTORY_REGISTRY_USER --password-stdin
fi

# get unique image names
images=$(cat $YAML_OUT_DIR/*.yaml | grep "image:" | sed 's/[[:space:]]*\-*//g' | sed 's/^image://g' | sort | uniq | tr '\n' ' ')
echo $images
i=0
for image in $images; do
  name=""

  if [[ "$image" =~ ^public.ecr.aws ]]; then
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=3;i<=NF;i++) {printf $i"/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  elif [[ "$image" =~ ^([a-zA-Z]*(.[a-zA-Z]+)+)/ ]]; then
    name=$(echo "$image" | awk -F\/ 'BEGIN {OFS="/"}{for(i=2;i<=NF;i++) {printf $i"/"}}' | rev | cut -c2- | rev) # remove trailing / and space from string
  else                                                                                                           # dockerhub images without domain
    name="$image"
  fi

  if [[ $DRY_RUN == true ]]; then
    echo "*DRY RUN* Copied $image to location $ARTIFACTORY_URL/$BELUGA_VERSION/$name"
  else
    {
      output=$(docker_command pull $image &&
        docker_command tag $image $ARTIFACTORY_URL/$BELUGA_VERSION/$name &&
        docker_command push $ARTIFACTORY_URL/$BELUGA_VERSION/$name &&
        echo "Copied $image to location $ARTIFACTORY_URL/$BELUGA_VERSION/$name")
    } || {
      echo "Error copying $image"
      errors+=("$image")
    }
  fi

  # every 10 images, do a cleanup. This way we can try to take advantage of layer caching but won't fill the system
  if [[ $DRY_RUN != true && "$i" -eq 10 ]]; then
    docker rmi -f $(docker images -aq)
    i=-1
  fi
  i=$((i + 1))
done

if [[ "${#errors[@]}" -ne 0 ]]; then
  echo "Error when trying to copy the following: "
  for i in "${errors[@]}"; do
    echo "$image"
  done
  exit 1
fi
