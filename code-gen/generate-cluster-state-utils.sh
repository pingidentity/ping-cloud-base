#!/bin/bash

# The list of variables in the template files that will be substituted by default.
# Note: DEFAULT_VARS is a superset of ENV_VARS_TO_SUBST within update-cluster-state.sh. These variables should be kept
# in sync with the following exceptions: LAST_UPDATE_REASON, and NEW_RELIC_LICENSE_KEY_BASE64 should only be found
# within DEFAULT_VARS
# Note: only secret variables are substituted into YAML files. Environments variables are just written to an env_vars
# file and substituted at runtime by the continuous delivery tool running in cluster.
# shellcheck disable=SC2016
DEFAULT_VARS='${LAST_UPDATE_REASON}
${PING_IDENTITY_DEVOPS_USER}
${PING_IDENTITY_DEVOPS_KEY}
${NEW_RELIC_LICENSE_KEY_BASE64}
${LEGACY_LOGGING}
${TENANT_NAME}
${SSH_ID_KEY_BASE64}
${IS_MULTI_CLUSTER}
${PLATFORM_EVENT_QUEUE_NAME}
${ORCH_API_SSM_PATH_PREFIX}
${SERVICE_SSM_PATH_PREFIX}
${REGION}
${REGION_NICK_NAME}
${PRIMARY_REGION}
${TENANT_DOMAIN}
${PRIMARY_TENANT_DOMAIN}
${PRIMARY_TENANT_DOMAIN_DERIVED}
${SECONDARY_TENANT_DOMAINS}
${GLOBAL_TENANT_DOMAIN}
${ARTIFACT_REPO_URL}
${PING_ARTIFACT_REPO_URL}
${LOG_ARCHIVE_URL}
${BACKUP_URL}
${PING_CLOUD_NAMESPACE}
${K8S_GIT_URL}
${K8S_GIT_BRANCH}
${ECR_REGISTRY_NAME}
${KNOWN_HOSTS_CLUSTER_STATE_REPO}
${CLUSTER_STATE_REPO_URL}
${CLUSTER_STATE_REPO_BRANCH}
${CLUSTER_STATE_REPO_PATH_DERIVED}
${SERVER_PROFILE_URL}
${SERVER_PROFILE_BRANCH_DERIVED}
${SERVER_PROFILE_PATH}
${ENV}
${ENVIRONMENT_TYPE}
${KUSTOMIZE_BASE}
${LETS_ENCRYPT_SERVER}
${USER_BASE_DN}
${ADMIN_CONSOLE_BRANDING}
${ENVIRONMENT_PREFIX}
${NEW_RELIC_ENVIRONMENT_NAME}
${PF_PD_BIND_PORT}
${PF_PD_BIND_PROTOCOL}
${PF_PD_BIND_USESSL}
${PF_MIN_HEAP}
${PF_MAX_HEAP}
${PF_MIN_YGEN}
${PF_MAX_YGEN}
${PA_WAS_MIN_HEAP}
${PA_WAS_MAX_HEAP}
${PA_WAS_MIN_YGEN}
${PA_WAS_MAX_YGEN}
${PA_WAS_GCOPTION}
${PA_MIN_HEAP}
${PA_MAX_HEAP}
${PA_MIN_YGEN}
${PA_MAX_YGEN}
${PA_GCOPTION}
${MYSQL_SERVICE_HOST}
${MYSQL_USER}
${MYSQL_PASSWORD}
${MYSQL_DATABASE}
${CLUSTER_NAME}
${CLUSTER_NAME_LC}
${DNS_ZONE}
${DNS_ZONE_DERIVED}
${PRIMARY_DNS_ZONE}
${PRIMARY_DNS_ZONE_DERIVED}
${METADATA_IMAGE_TAG}
${BOOTSTRAP_IMAGE_TAG}
${P14C_INTEGRATION_IMAGE_TAG}
${ANSIBLE_BELUGA_IMAGE_TAG}
${PINGCENTRAL_IMAGE_TAG}
${PINGACCESS_IMAGE_TAG}
${PINGACCESS_WAS_IMAGE_TAG}
${PINGFEDERATE_IMAGE_TAG}
${PINGDIRECTORY_IMAGE_TAG}
${PINGDELEGATOR_IMAGE_TAG}
${IRSA_PING_ANNOTATION_KEY_VALUE}
${NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE}'

# Variables to replace in the generated bootstrap code
BOOTSTRAP_VARS='${K8S_GIT_URL}
${K8S_GIT_BRANCH}
${CLUSTER_STATE_REPO_URL}
${CLUSTER_STATE_REPO_BRANCH}
${REGION_NICK_NAME}
${TENANT_NAME}
${PING_CLOUD_NAMESPACE}
${KNOWN_HOSTS_CLUSTER_STATE_REPO}
${SSH_ID_KEY_BASE64}'

########################################################################################################################
# Export some derived environment variables.
########################################################################################################################
add_derived_variables() {
  # The directory within the cluster state repo for the region's manifest files.
  export CLUSTER_STATE_REPO_PATH_DERIVED="\${REGION_NICK_NAME}"

  # Server profile branch. The directory is in each app's env_vars file.
  export SERVER_PROFILE_BRANCH_DERIVED="\${CLUSTER_STATE_REPO_BRANCH}"

  # Zone for this region and the primary region.
  export DNS_ZONE_DERIVED="\${DNS_ZONE}"
  export PRIMARY_DNS_ZONE_DERIVED="\${PRIMARY_DNS_ZONE}"

  # Zone for this region and the primary region.
  if "${IS_BELUGA_ENV}" || test "${ENV}" = "${CUSTOMER_HUB}"; then
    export DNS_ZONE="\${TENANT_DOMAIN}"
    export PRIMARY_DNS_ZONE="\${PRIMARY_TENANT_DOMAIN}"
  else
    export DNS_ZONE="\${REGION_ENV}-\${TENANT_DOMAIN}"
    export PRIMARY_DNS_ZONE="\${ENV}-\${PRIMARY_TENANT_DOMAIN}"
  fi

  export PRIMARY_TENANT_DOMAIN_DERIVED="\${PRIMARY_TENANT_DOMAIN}"

  # This variable's value will make it onto the branding for all admin consoles and
  # will include the name of the environment and the region where it's deployed.
  export ADMIN_CONSOLE_BRANDING="\${ENV}-\${REGION}"

  # This variable's value will be used as the prefix to distinguish between worker apps for different CDEs for a
  # single P14C tenant. All of these apps will be created within the "Administrators" environment in the tenant.
  export ENVIRONMENT_PREFIX="\${TENANT_NAME}-\${CLUSTER_STATE_REPO_BRANCH}-\${REGION_NICK_NAME}"

  # The name of the environment as it will appear on the NewRelic console.
  export NEW_RELIC_ENVIRONMENT_NAME="\${TENANT_NAME}_\${ENV}_\${REGION_NICK_NAME}_k8s-cluster"
}

########################################################################################################################
# Export IRSA annotation for the provided environment.
#
# Arguments
#   ${1} -> The SSM path prefix which stores CDE account IDs of Ping Cloud environments.
#   ${2} -> The environment name.
########################################################################################################################
add_irsa_variables() {
  if test "${IRSA_PING_ANNOTATION_KEY_VALUE}"; then
    export IRSA_PING_ANNOTATION_KEY_VALUE="${IRSA_PING_ANNOTATION_KEY_VALUE}"
    return
  fi

  local ssm_path_prefix="$1"
  local env="$2"

  # Default empty string
  IRSA_PING_ANNOTATION_KEY_VALUE=''

  if [ "${ssm_path_prefix}" != "unused" ]; then

    # Getting value from ssm parameter store.
    if ! ssm_value=$(get_ssm_value "${ssm_path_prefix}/${env}"); then
      echo "Error: ${ssm_value}"
      exit 1
    fi

    # IRSA for ping product pods. The role name is predefined as a part of the interface contract.
    IRSA_PING_ANNOTATION_KEY_VALUE="eks.amazonaws.com/role-arn: arn:aws:iam::${ssm_value}:role/pcpt/irsa-roles/irsa-ping"
  fi

  export IRSA_PING_ANNOTATION_KEY_VALUE="${IRSA_PING_ANNOTATION_KEY_VALUE}"
}

########################################################################################################################
# Export NLB EIP annotation for the provided environment.
#
# Arguments
#   ${1} -> The SSM path prefix which stores CDE account IDs of Ping Cloud environments.
#   ${2} -> The environment name.
########################################################################################################################
add_nlb_variables() {
  local ssm_path_prefix="$1"
  local env="$2"

  if test "${NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE}"; then
    export NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE="${NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE}"
  else
    # Default empty string
    NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE=''

    if [ "${ssm_path_prefix}" != "unused" ]; then

      # Getting value from ssm parameter store.
      if ! ssm_value=$(get_ssm_value "${ssm_path_prefix}/${env}/nginx-public"); then
        echo "Error: ${ssm_value}"
        exit 1
      fi

      NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE="service.beta.kubernetes.io/aws-load-balancer-eip-allocations: ${ssm_value}"
    fi

    export NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE="${NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE}"
  fi
}

########################################################################################################################
# Export the IS_GA environment variable for the provided customer. If it's already present as a boolean environment
# variable, then export it as is. Otherwise, if the SSM path prefix for it is not 'unused', then try to retrieve it out
# of SSM. On error, print a warning message, but default the value to false. On success, use the value from SSM, if it
# is a valid boolean. Otherwise, default it to false.
#
# Arguments
#   ${1} -> The value of the IS_GA flag.
########################################################################################################################
get_is_ga_variable() {
  if test "${IS_GA}" = 'true' || test "${IS_GA}" = 'false'; then
    export IS_GA="${IS_GA}"
    return
  fi

  local ssm_path_prefix="$1"
  
  # Default false
  IS_GA='false'

  if [ "${ssm_path_prefix}" != "unused" ]; then
    # Getting value from ssm parameter store.
    if ! ssm_value=$(get_ssm_value "${ssm_path_prefix}"); then
      echo "Warn: ${ssm_value}"
      echo "Defaulting IS_GA=false."
    else
      IS_GA="${ssm_value}"
    fi
  fi

  if test "${IS_GA}" = 'true' || test "${IS_GA}" = 'false'; then
    export IS_GA="${IS_GA}"
  else
    export IS_GA='false'
  fi
}

########################################################################################################################
# Export the IS_MY_PING environment variable for the provided customer. If it's already present as a boolean environment
# variable, then export it as is. Otherwise, if the SSM path prefix for it is not 'unused', then try to retrieve it out
# of SSM. On error, print a warning message, but default the value to false. On success, use the value from SSM.
# Otherwise, default it to false.
#
# Arguments
#   ${1} -> The value of the IS_MY_PING flag.
########################################################################################################################
get_is_myping_variable() {
  if test "${IS_MY_PING}" = 'true' || test "${IS_MY_PING}" = 'false'; then
    export IS_MY_PING="${IS_MY_PING}"
    return
  fi

  local ssm_path_prefix="$1"

  # Default false
  IS_MY_PING='false'

  if [ "${ssm_path_prefix}" != "unused" ]; then
    # Getting value from ssm parameter store.
    if ! ssm_value=$(get_ssm_value "${ssm_path_prefix}"); then
      echo "Warn: ${ssm_value}"
      echo "Defaulting IS_MY_PING=false."
    else
      IS_MY_PING="${ssm_value}"
    fi
  fi

  if test "${IS_MY_PING}" = 'true' || test "${IS_MY_PING}" = 'false'; then
    export IS_MY_PING="${IS_MY_PING}"
  else
    export IS_MY_PING='false'
  fi
}
