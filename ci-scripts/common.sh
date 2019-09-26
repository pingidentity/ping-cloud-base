#!/bin/bash

##################################################################
# Common variables
##################################################################
[[ ${CI_COMMIT_REF_SLUG} != master ]] && export ENVIRONMENT=-${CI_COMMIT_REF_SLUG}

FQDN=${ENVIRONMENT}.${TENANT_DOMAIN}

# Common
LOGS_CONSOLE=https://logs.${TENANT_DOMAIN}

# Pingdirectory
PINGDIRECTORY_CONSOLE=https://pingdataconsole${FQDN}/console
PINGDIRECTORY_ADMIN=pingdirectory-admin${FQDN}

# Pingfederate
# admin services:
PINGFEDERATE_CONSOLE=https://pingfederate-admin${FQDN}/pingfederate/app
PINGFEDERATE_API=https://pingfederate-admin${FQDN}/pingfederate/app/pf-admin-api/api-docs

# runtime services:
PINGFEDERATE_AUTH_ENDPOINT=https://pingfederate${FQDN}
PINGFEDERATE_OAUTH_PLAYGROUND=https://pingfederate${FQDN}/OAuthPlayground

# Pingaccess
# admin services:
PINGACCESS_CONSOLE=https://pingaccess-admin${FQDN}
PINGACCESS_API=https://pingaccess-admin${FQDN}/pa-admin-api/v3/api-docs

# runtime services:
PINGACCESS_RUNTIME=https://pingaccess${FQDN}
PINGACCESS_AGENT=https://pingaccess-agent${FQDN}

# Source some utility methods.
. ${CI_PROJECT_DIR}/utils.sh