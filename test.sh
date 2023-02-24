#!/bin/bash -e

# This script copies the kustomization templates into a temporary directory, performs substitution into them using
# environment variables defined in an env_vars file and builds the uber deploy.yaml file. It is run by the CD tool on
# every poll interval.

# Developing this script? Check out https://confluence.pingidentity.com/x/2StOCw

LOG_FILE=/tmp/git-ops-command.log

########################################################################################################################
# Add the provided message to LOG_FILE.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
log() {
    msg="$1"

    echo "git-ops-command: ${msg}"

}

feature_flags() {
    cd "${1}/k8s-configs"

    # Map with the feature flag environment variable & the term to search to find the kustomization files
    flag_map="${RADIUS_PROXY_ENABLED}:ff-radius-proxy ${EXTERNAL_INGRESS_ENABLED}:remove-external-ingress"

    for flag in $flag_map; do
        enabled="${flag%%:*}"
        search_term="${flag##*:}"
        log "${search_term} is set to ${enabled}"

        if [[ ${search_term} != "remove-external-ingress" ]]; then
            # If the feature flag is disabled, comment the search term lines out of the kustomization files
            if [[ ${enabled} != "true" ]]; then
                for kust_file in $(git grep -l "${search_term}" | grep "kustomization.yaml"); do
                    log "Commenting out ${search_term} in ${kust_file}"
                    sed -i.bak \
                        -e "/${search_term}/ s|^#*|#|g" \
                        "${kust_file}"
                    rm -f "${kust_file}".bak
                done
            fi
        else
            cd "${1}/code-gen"
            if [[ ${enabled} != "true" ]]; then
                for kust_file in $(git grep -l "${search_term}" | grep "kustomization.yaml"); do
                    log "UnCommenting out ${search_term} in ${kust_file}"
                    sed -i.bak \
                        -e "/${search_term}/ s|^#*||g" \
                        "${kust_file}"
                    rm -f "${kust_file}".bak
                done
            fi
        fi
    done
}

feature_flags_extended() {
    cd "${1}/code-gen"

    # Map with the feature flag environment variable & the term to search to find the kustomization files
    flag_map="${EXTERNAL_INGRESS_ENABLED}:remove-external-ingress"

    for flag in $flag_map; do
        enabled="${flag%%:*}"
        search_term="${flag##*:}"
        log "${search_term} is set to ${enabled}"

        # If the feature flag is disabled, comment the search term lines out of the kustomization files
        if [[ ${enabled} == "true" ]]; then
            for kust_file in $(git grep -l "${search_term}" | grep "kustomization.yaml"); do
                log "Commenting out ${search_term} in ${kust_file}"
                sed -i.bak \
                    -e "/${search_term}/ s|^#*|#|g" \
                    "${kust_file}"
                rm -f "${kust_file}".bak
            done
        fi
    done
}

feature_flags /Users/abhalla/Desktop/P1AS_Workspace/PDO_4388/ping-cloud-base
