#!/usr/bin/env sh

. "./logger.lib.sh"

# Constants.
PA_ADMIN_SERVER_NAME='pingaccess-admin-0'
PA_ADMIN_SERVICE_NAME='pingaccess-admin'
PA_ADMIN_WAIT_PORT=9000

PA_WAS_ADMIN_SERVER_NAME='pingaccess-was-admin-0'
PA_WAS_ADMIN_SERVICE_NAME='pingaccess-was-admin'
PA_WAS_ADMIN_WAIT_PORT=9000

PF_ADMIN_SERVER_NAME='pingfederate-admin-0'
PF_ADMIN_SERVICE_NAME='pingfederate-admin'
PF_ADMIN_WAIT_PORT=9999

PD_STS_NAME='pingdirectory'
PD_ADMIN_SERVER_NAME="${PD_STS_NAME}-0"
PD_ADMIN_SERVICE_NAME='pingdirectory'
PD_ADMIN_WAIT_PORT=1636

SHORT_HOSTNAME="$(hostname)"


########################################################################################################################
# Determines if the environment is set up in the primary cluster.
#
# Returns
#   true if primary cluster; false if not.
########################################################################################################################
is_primary_cluster() {
  test "${TENANT_DOMAIN}" = "${PRIMARY_TENANT_DOMAIN}"
}

########################################################################################################################
# Determines if the environment is set up in a secondary cluster.
#
# Returns
#   true if secondary cluster; false if not.
########################################################################################################################
is_secondary_cluster() {
  ! is_primary_cluster
}

########################################################################################################################
# Determines if the local server is a pingdirectory server.
#
# Returns
#   true if the local server is a pingdirectory server; false if not.
########################################################################################################################
is_a_pingdirectory_server() {
  echo "${SHORT_HOSTNAME}" | grep -q "${PD_STS_NAME}"
}

########################################################################################################################
# Determines if the local server is pingdirectory-0.
#
# Returns
#   true if the local server is pingdirectory-0; false if not.
########################################################################################################################
is_pingdirectory_server0() {
  test "${SHORT_HOSTNAME}" = "${PD_ADMIN_SERVER_NAME}"
}