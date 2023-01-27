#!/bin/bash
#set -e

test "${VERBOSE}" && set -x

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

########################################################################################################################
# Finds an available ci-cd cluster to run on:
#
# If no cluster is available it will try again every 5 minutes for 30 minutes before timing out.
########################################################################################################################

find_cluster() {
  check_env_vars "CLUSTER_POSTFIXES"
  HAS_REQUIRED_VARS=${?}

  if test ${HAS_REQUIRED_VARS} -ne 0; then
    exit 1
  fi

  configure_aws

  cluster_postfixes=($CLUSTER_POSTFIXES)
  found_cluster=false
  sleep_wait_seconds=300
  current_check=1
  max_checks=7

  while [[ $found_cluster == false ]]; do
    for postfix in "${cluster_postfixes[@]}"; do
      export SELECTED_POSTFIX=$postfix
      export SELECTED_KUBE_NAME=$(echo "ci-cd$postfix" | tr '_' '-')
      configure_kube

      # TODO: consider removing this if we ever scale from 0 nodes
      # Typically, all CI/CD clusters should have at least 2 nodes ready (1 per AZ), then they will scale up when we
      # deploy the uber yaml
      min_nodes=2
      # Get nodes with ONLY 'Ready' state, count them
      num_nodes=$(kubectl get nodes | awk '{ print $2 }' | grep -c '^Ready$' )

      if [[ $? != 0 ]]; then
        log "There was a problem checking how many nodes are running on the cluster, continuing to next cluser"
        continue
      fi

      if [[ $num_nodes -lt $min_nodes ]]; then
        log "Cluster ${SELECTED_KUBE_NAME} does not have enough nodes available"
        log "CI/CD pipeline requires ${min_nodes} nodes but there were only ${num_nodes} nodes"
        log "Skipping this cluster and trying the next"
        continue
      else
        log "Found sufficient nodes are available on cluster ${SELECTED_KUBE_NAME}"
      fi

      log "INFO: Namespaces on cluster $SELECTED_KUBE_NAME: $(kubectl get ns)"
      # Check namespaces & break out of loop if cluster is available (i.e. no cluster-in-use-lock namespace)
      if ! kubectl get ns | grep cluster-in-use-lock > /dev/null; then
        # Add a cluster-in-use-lock namespace to make sure we lock this cluster for our use
        kubectl create namespace cluster-in-use-lock || continue
        found_cluster=true
        log "Found cluster $SELECTED_KUBE_NAME available to deploy to"
        echo "SELECTED_POSTFIX=$SELECTED_POSTFIX" > cluster.env
        echo "SELECTED_KUBE_NAME=$SELECTED_KUBE_NAME" >> cluster.env
        set_deploy_type_env_vars
        set_env_vars
        break
      fi
    done

    if [[ $found_cluster == false ]]; then
      if [[ $current_check -ge $max_checks ]]; then
        log "Could not find a cluster to run on - please check that the pipeline is not saturated and delete unused namespaces"
        exit 1
      fi
      log "No unused cluster found to run your changes on. Waiting for ${sleep_wait_seconds} seconds, then checking again."
      ((current_check=current_check+1))
      sleep $sleep_wait_seconds
    fi
  done
}

find_cluster
