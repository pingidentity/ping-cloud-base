#!/bin/bash

if [[ $@ = pull* ]]; then
    # If the command is `helm pull (..)` skips --repo flag and chartName
    # from command line args to make helm pull run

    # For explanation:
    # https://github.com/kubernetes-sigs/kustomize/issues/4381
    arr=(${@//--repo/});  # Skipping --repo
    args="${arr[@]:0:5} ${arr[@]:6}";  # Skipping chartName
else
    args="$@"
fi

helm_install=$(which helm)

if [ $? != 0 ]; then
  echo "Helm is not installed on this system, exiting."
  exit 1
fi

cmd="${helm_install} --registry-config /helm-working-dir/registry/config.json $args"
echo "Running '$cmd' " >> /tmp/helm-debug
eval $cmd
