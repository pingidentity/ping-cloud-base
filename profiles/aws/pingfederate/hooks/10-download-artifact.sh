#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

# Check and export environment variable(s) for PF artifacts
test -f "${STAGING_DIR}/solutions_artifacts" && SOLUTIONS_ARTIFACTS=$(cat "${STAGING_DIR}/solutions_artifacts")

# Check to see if the artifact file exists, or if solutions artifacts are specified
if test -f "${STAGING_DIR}/artifacts/artifact-list.json" || test ! -z "${SOLUTIONS_ARTIFACTS}" || test -f "${STAGING_DIR}/artifacts/IK.json"; then

  ARTIFACT_LIST_JSON=$(cat "${STAGING_DIR}/artifacts/artifact-list.json")
  IK_LIST_JSON=$(cat "${STAGING_DIR}/artifacts/IK.json")
  beluga_log "ARTIFACT_LIST_JSON : ${ARTIFACT_LIST_JSON}"

  beluga_log "SOLUTIONS_ARTIFACTS : ${SOLUTIONS_ARTIFACTS}"

  _is_invalid_json() {
    test $(echo ${1} | jq >/dev/null 2>&1; echo $?) -ne "0"
  }

  if _is_invalid_json "${ARTIFACT_LIST_JSON}"; then
    beluga_log "Artifacts will not be deployed as the artifact-list.json could not be parsed."
    exit 1
  elif _is_invalid_json "${SOLUTIONS_ARTIFACTS}"; then
    beluga_log "Artifacts will not be deployed as the solutions artifact list could not be parsed."
    exit 1
  elif _is_invalid_json "${IK_LIST_JSON}"; then
    beluga_log "Artifacts will not be deployed as the IK.json could not be parsed."
    exit 1
  fi

  # Combine the artifacts specified in artifact-list.json with the ones specified in SOLUTIONS_ARTIFACTS
  MERGED_ARTIFACT_LIST=$(echo $(echo "${ARTIFACT_LIST_JSON}" | jq '.[]') $(echo "${SOLUTIONS_ARTIFACTS}" | jq '.[]') | jq -s '.')

  if test ! -z "${MERGED_ARTIFACT_LIST}" -o $(echo "${IK_LIST_JSON}" | jq 'any') == "true"; then

    # Check to see if the source S3 bucket(s) are specified or integration kits list isn't empty
    if test ! -z "${ARTIFACT_REPO_URL}" -o ! -z "${PING_ARTIFACT_REPO_URL}" -o $(echo "${IK_LIST_JSON}" | jq 'any') == "true"; then

      beluga_log "Private Repo : ${ARTIFACT_REPO_URL}"
      beluga_log "Public Repo  : ${PING_ARTIFACT_REPO_URL}"

      # Check to see if the artifact list is a valid json string
      beluga_log "${MERGED_ARTIFACT_LIST}"
      if _is_invalid_json "${MERGED_ARTIFACT_LIST}"; then
        beluga_log "Artifacts will not be deployed as the combined list of artifiacts from artifact_list.json and solutions_artifacts could not be parsed."
        exit 1
      else

        # Check to see if there are any duplicate artifacts
        # This is needed to avoid issues with multiple plugin versions
        duplicate_artifacts=$(echo ${MERGED_ARTIFACT_LIST} | jq 'group_by(.name) | map(select(length>1) | .[0])')
        if test $(echo ${duplicate_artifacts} | jq 'any') = "true"; then
         for duplicate in $(echo "${duplicate_artifacts}" | jq -c '.[]'); do
           artifact_name=$(echo ${duplicate} | jq -r '.name')

           in_solutions_artifacts=$(echo "${SOLUTIONS_ARTIFACTS}" | jq --arg name "${artifact_name}" '.[] | select(.name==$name) | any')
           in_artifact_list=$(echo "${ARTIFACT_LIST_JSON}" | jq --arg name "${artifact_name}" '.[] | select(.name==$name) | any')

           if test "${in_artifact_list}" = "true" && test "${in_solutions_artifacts}" = "true"; then
             beluga_log "Artifact ${artifact_name} is specified in both ${STAGING_DIR}/artifacts/artifact-list.json and SOLUTIONS_ARTIFACTS"
           elif test "${in_artifact_list}" = "true"; then
             beluga_log "Artifact ${artifact_name} is specified more than once in ${STAGING_DIR}/artifacts/artifact-list.json"
           elif test "${in_solutions_artifacts}" = "true"; then
             beluga_log "Artifact ${artifact_name} is specified more than once in SOLUTIONS_ARTIFACTS"
           fi
         done
         exit 1
        fi

        _is_in_ik_list() {
          artifact_name=$(echo ${1} | cut -d '-' -f 2- | sed 's/-/ /g')
          test $(echo "${IK_LIST_JSON}" | jq --arg name "${artifact_name}" '.[] | select(.name | ascii_downcase | contains($name)) | any') = "true"
        }

        for name in $(echo "${MERGED_ARTIFACT_LIST}" | jq '.[].name'); do
          if _is_in_ik_list "${name}"; then
            beluga_log "Artifact ${name} is specified in IK.json and somewhere in ${STAGING_DIR}/artifacts/artifact-list.json or SOLUTIONS_ARTIFACTS"
            exit 1
          fi
        done

        DOWNLOAD_DIR=$(mktemp -d)
        DIRECTORY_NAME=$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')

        PUBLIC_BASE_URL="${PING_ARTIFACT_REPO_URL}"
        if test ! -z "${PING_ARTIFACT_REPO_URL}"; then
          if ! test -z "${PING_ARTIFACT_REPO_URL##*/pingfederate*}"; then
            PUBLIC_BASE_URL="${PING_ARTIFACT_REPO_URL}/${DIRECTORY_NAME}"
          fi
        fi

        PRIVATE_BASE_URL="${ARTIFACT_REPO_URL}"
        if test ! -z "${ARTIFACT_REPO_URL}"; then
          if ! test -z "${ARTIFACT_REPO_URL##*/pingfederate*}"; then
            PRIVATE_BASE_URL="${ARTIFACT_REPO_URL}/${DIRECTORY_NAME}"
          fi
        fi

        for artifact in $(echo "${MERGED_ARTIFACT_LIST}" | jq -c '.[]'); do
          _artifact() {
            echo ${artifact} | jq -r ${1}
          }

          ARTIFACT_NAME=$(_artifact '.name')
          ARTIFACT_VERSION=$(_artifact '.version')
          ARTIFACT_SOURCE=$(_artifact '.source')
          ARTIFACT_RUNTIME_ZIP=${ARTIFACT_NAME}-${ARTIFACT_VERSION}-runtime.zip

          # Use default source of public if source is not specified
          if ( ( test "${ARTIFACT_SOURCE}" = "null" ) || ( test -z ${ARTIFACT_SOURCE} ) ); then
            ARTIFACT_SOURCE="public"
          fi

          # Check to see if artifact name and version are available
          if ( ( test ! "${ARTIFACT_NAME}" = "null" ) && ( test ! -z ${ARTIFACT_NAME} ) ); then
            if ( ( test ! "${ARTIFACT_VERSION}" = "null" ) && ( test ! -z ${ARTIFACT_VERSION} ) ); then

              # Check to see if the Artifact Source URL is available
              if ( ( test "${ARTIFACT_SOURCE}" = "private" ) && ( test -z ${ARTIFACT_REPO_URL} ) ) || ( ( test "${ARTIFACT_SOURCE}" = "public" ) && ( test -z ${PING_ARTIFACT_REPO_URL} ) ); then
                beluga_log "${ARTIFACT_NAME} cannot be deployed as the ${ARTIFACT_SOURCE} source repo is not defined. "
                exit 1
              else
                # Get artifact source location
                if test "${ARTIFACT_SOURCE}" = "private"; then
                  ARTIFACT_LOCATION=${PRIVATE_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_RUNTIME_ZIP}
                elif test "${ARTIFACT_SOURCE}" = "public"; then
                  ARTIFACT_LOCATION=${PUBLIC_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_RUNTIME_ZIP}
                else
                  beluga_log "${ARTIFACT_NAME} cannot be deployed as the artifact source '${ARTIFACT_SOURCE}' is invalid. "
                  exit 1
                fi

                beluga_log "Download Artifact from ${ARTIFACT_LOCATION}"

                # Use skbn if source is cloud storage otherwise use curl
                if test ${ARTIFACT_LOCATION#s3} != "${ARTIFACT_LOCATION}"; then

                  # Set required environment variables for skbn
                  initializeSkbnConfiguration "${ARTIFACT_LOCATION}"

                  beluga_log "Copying: '${ARTIFACT_LOCATION}' to '${SKBN_K8S_PREFIX}${DOWNLOAD_DIR}'"

                  if ! skbnCopy "${SKBN_CLOUD_PREFIX}" "${SKBN_K8S_PREFIX}${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}"; then
                    exit 1
                  fi

                else
                  curl -sS "${ARTIFACT_LOCATION}" --output ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                fi

                # Unzip deploy and conf folders from the runtime zip
                if test $(echo $?) = "0"; then
                  if ! unzip -o ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} -d ${OUT_DIR}/instance/server/default
                  then
                      beluga_log Artifact ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} could not be unzipped.
                      exit 1
                  fi
                else
                  beluga_log "Artifact download failed from ${ARTIFACT_LOCATION}"
                  exit 1
                fi

                # Cleanup
                if test -f "${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}"; then
                  rm ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                fi
              fi
            else
              beluga_log "Artifact Version for ${ARTIFACT_NAME} could not be retrieved from ${STAGING_DIR}/artifacts/artifact-list.json"
              exit 1
            fi
          else
            beluga_log "Missing Artifact Name within ${STAGING_DIR}/artifacts/artifact-list.json"
            exit 1
          fi

        done
        # Set Internal Field Separator to newline to iterate over lines, ignoring whitespaces
        IFS=$'\n'

        for artifact in $(echo "${IK_LIST_JSON}" | jq -c '.[]'); do
          _artifact() {
            echo ${artifact} | jq -r ${1}
          }

          ARTIFACT_NAME=$(_artifact '.name')
          ARTIFACT_DOWNLOAD_NAME=$(echo "${ARTIFACT_NAME}" | sed 's/ /-/g')
          ARTIFACT_VERSION=$(_artifact '.version')
          ARTIFACT_RUNTIME_ZIP=${ARTIFACT_DOWNLOAD_NAME}-${ARTIFACT_VERSION}-runtime.zip

          # Check to see if artifact name and version are available
          if ( ( test ! "${ARTIFACT_NAME}" = "null" ) && ( test ! -z ${ARTIFACT_NAME} ) ); then
            if ( ( test ! "${ARTIFACT_VERSION}" = "null" ) && ( test ! -z ${ARTIFACT_VERSION} ) ); then

              # Get IK Service API URL
              api_url=$(kubectl get configmap p14c-environment-metadata -o json | jq -r '.data."information.json"'| jq -r '.pingOneInformation.webhookBaseUrl')
              # Get Env ID to work with IK Service
              env_id=$(kubectl get configmap p14c-environment-metadata -o json | jq -r '.data."information.json"'| jq -r '.pingOneInformation.environmentId')

              # Get Bearer token to communicate with IK Service
              token=$(curl -s --location \
              --header "Content-Type: application/x-www-form-urlencoded"  \
              --data-raw "grant_type=client_credentials" \
              -u "${IK_CLIENT_ID}":"${IK_CLIENT_SECRET}" \
              "${IK_TOKEN_URL}" | jq -r '.access_token')

              # Get Artifact ID from IK Service
              ARTIFACT_ID=$(curl -s --location --header "Authorization: Bearer ${token}" \
                "${api_url}/v1/environments/${env_id}/integrations?filter=pingProductNames%20eq%20%22${PING_PRODUCT}%22" |
                jq -r --arg name "${ARTIFACT_NAME}" '._embedded.integrations[] | select(.name | ascii_downcase | contains($name) | .id)')

              # Get artifact version ID if artifact exists in IK Service
              if ( ( test ! -z ${ARTIFACT_ID} ) ); then

                VERSION_ID=$(curl -s --location --header "Authorization: Bearer ${token}" \
                  "${api_url}/v1/environments/${env_id}/integrations/${ARTIFACT_ID}/versions" |
                   jq -r --arg version "${ARTIFACT_VERSION}" '._embedded.versions[] | select(.number==$version) | .id')

                if ( ( test ! -z ${VERSION_ID} ) ); then
                  beluga_log "Download Artifact from IK Service"

                  curl -sS --location "${api_url}/v1/environments/${env_id}/integrations/${ARTIFACT_ID}/versions/${VERSION_ID}/asset" --output ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}

                  if test $(echo $?) = "0"; then
                  # Unzip artifact to tmp dir because it can have different unneeded folders in archive
                  if ! unzip -o ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} */dist/* -d ${DOWNLOAD_DIR}/${ARTIFACT_DOWNLOAD_NAME}
                  then
                      beluga_log "Artifact ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} could not be unzipped."
                      exit 1
                  fi
                  # Copy only needed folders
                  cp -r ${DOWNLOAD_DIR}/${ARTIFACT_DOWNLOAD_NAME}/*/dist/* ${OUT_DIR}/instance/server/default
                  else
                    beluga_log "Artifact download failed from IK Service"
                    exit 1
                  fi

                  # Cleanup
                  if test -f "${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}"; then
                    rm ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                  fi
                  if test -d "${DOWNLOAD_DIR}/${ARTIFACT_DOWNLOAD_NAME}"; then
                    rm -rf ${DOWNLOAD_DIR}/${ARTIFACT_DOWNLOAD_NAME}
                  fi

                else
                  beluga_log "Version ${ARTIFACT_VERSION} of ${ARTIFACT_NAME} missing in IK Service"
                fi
              else
                beluga_log "Artifact ${ARTIFACT_NAME} missing in IK Service"
              fi
            else
              beluga_log "Artifact Version for ${ARTIFACT_NAME} could not be retrieved from ${STAGING_DIR}/artifacts/IK.json"
              exit 1
            fi
          else
            beluga_log "Missing Artifact Name within ${STAGING_DIR}/artifacts/IK.json"
            exit 1
          fi
        done

        # Reset Internal Field Separator to default value
        unset IFS

        # Print listed files from deploy and conf to a single line so we don't spam logs
        ls ${OUT_DIR}/instance/server/default/deploy | xargs
        ls ${OUT_DIR}/instance/server/default/conf/template | xargs
        ls ${OUT_DIR}/instance/server/default/conf/language-packs | xargs
      fi
    else
      beluga_log "Artifacts will not be deployed as the environment variable ARTIFACT_REPO_URL and PING_ARTIFACT_REPO_URL are empty and no artifacts specified in ${STAGING_DIR}/artifacts/IK.json."
      exit 0
    fi
  else
    beluga_log "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json and ${STAGING_DIR}/artifacts/IK.json are empty and no artifacts were specified in SOLUTIONS_ARTIFACTS."
    exit 0
  fi
else
  beluga_log "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json and ${STAGING_DIR}/artifacts/IK.json don't exist and no artifacts were specified in SOLUTIONS_ARTIFACTS."
  exit 0
fi


# Find all pf-authn-api-sdk jars that may have been unzipped into /deploy and move them into /lib
find ${OUT_DIR}/instance/server/default/deploy -name 'pf-authn-api-sdk*.jar' -exec mv "{}" ${OUT_DIR}/instance/server/default/lib \;

# Keep only the highest version of the pf-authn-api-sdk jar
LIB_PF_AUTHN_API_SDK_JARS=$(find ${OUT_DIR}/instance/server/default/lib -name 'pf-authn-api-sdk*.jar')
PF_AUTHN_API_SDK_COUNT=$(echo "${LIB_PF_AUTHN_API_SDK_JARS}" | wc -l | xargs)

if test $PF_AUTHN_API_SDK_COUNT -gt 1; then
  HIGHEST_VERSION_JAR=$(echo "${LIB_PF_AUTHN_API_SDK_JARS}" | sort -V | tail -1)
  beluga_log "Multiple versions of the pf-authn-api-sdk jar detected. The highest version ${HIGHEST_VERSION_JAR} will be kept."
  for pf_authn_api_sdk_jar in $(echo "${LIB_PF_AUTHN_API_SDK_JARS}" | sort -V | head -n -1); do
    beluga_log "Deleting ${pf_authn_api_sdk_jar}"
    rm "${pf_authn_api_sdk_jar}"
  done
fi
