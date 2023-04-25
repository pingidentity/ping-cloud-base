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
#TODO: add which helm so it's always executing the binary as expected
cmd="/usr/local/bin/helm --registry-config ~/.config/helm/registry/config.json $args"
echo "Running '$cmd' " >> /tmp/helm-debug
eval $cmd
