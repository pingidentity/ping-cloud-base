#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

if test -f "${STAGING_DIR}/artifacts/artifact-list.json"; then
  # Check to see if the artifact file is empty
  ARTIFACT_LIST_JSON=$(cat "${STAGING_DIR}/artifacts/artifact-list.json")
  if test ! -z "${ARTIFACT_LIST_JSON}"; then
    # Check to see if the source is specified
    if test ! -z "${ARTIFACT_REPO_URL}"; then

      echo "Private Repo : ${ARTIFACT_REPO_URL}"

      # Check to see if the artifact list is a valid json string
      echo ${ARTIFACT_LIST_JSON} | jq
      if test $(echo $?) == "0"; then

        DOWNLOAD_DIR=$(mktemp -d)
        UNZIP_DOWNLOAD_DIR=$(mktemp -d)
        DIRECTORY_NAME=$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')

        PRIVATE_BASE_URL="${ARTIFACT_REPO_URL}"
        if test ! -z "${ARTIFACT_REPO_URL}"; then
          if ! test -z "${ARTIFACT_REPO_URL##*/pingaccess*}"; then
            PRIVATE_BASE_URL="${ARTIFACT_REPO_URL}/${DIRECTORY_NAME}"
          fi
        fi

        for artifact in $(echo "${ARTIFACT_LIST_JSON}" | jq -c '.[]'); do
          _artifact() {
            echo ${artifact} | jq -r ${1}
          }

          ARTIFACT_NAME=$(_artifact '.name')
          ARTIFACT_VERSION=$(_artifact '.version')
          ARTIFACT_SOURCE=$(_artifact '.source')
          ARTIFACT_OPERATION=$(_artifact '.operation')
          ARTIFACT_RUNTIME_ZIP=${ARTIFACT_NAME}-${ARTIFACT_VERSION}-runtime.zip

          # Use default source of private if source is not specified
          if ( ( test "${ARTIFACT_SOURCE}" == "null" ) || ( test -z ${ARTIFACT_SOURCE} ) ); then
            ARTIFACT_SOURCE="private"
          fi

          # Use default operation of add if operation is not specified
          if ( ( test "${ARTIFACT_OPERATION}" == "null" ) || ( test -z ${ARTIFACT_OPERATION} ) ); then
            ARTIFACT_OPERATION="add"
          fi

          # Check to see if artifact name and version are available
          if ( ( test ! "${ARTIFACT_NAME}" == "null" ) && ( test ! -z ${ARTIFACT_NAME} ) ); then
            if ( ( test ! "${ARTIFACT_VERSION}" == "null" ) && ( test ! -z ${ARTIFACT_VERSION} ) ); then

              # Check to see if the Artifact Source URL is available
              if ( ( test "${ARTIFACT_SOURCE}" == "private" ) && ( test -z ${ARTIFACT_REPO_URL} ) ); then
                echo "${ARTIFACT_NAME} cannot be deployed as the ${ARTIFACT_SOURCE} source repo is not defined. "
                exit 1
              else
                # Make sure there aren't any duplicate entries for the artifact.
                # This is needed to avoid issues with multiple plugin versions
                ARTIFACT_NAME_COUNT=$(echo "${ARTIFACT_LIST_JSON}" | grep -iEo "${ARTIFACT_NAME}" | wc -l | xargs)

                if test "${ARTIFACT_NAME_COUNT}" == "1"; then

                  # Get artifact source location
                  if test "${ARTIFACT_SOURCE}" == "private"; then
                    ARTIFACT_LOCATION=${PRIVATE_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_RUNTIME_ZIP}
                  else
                    echo "${ARTIFACT_NAME} cannot be deployed as the artifact source '${ARTIFACT_SOURCE}' is invalid. "
                    exit 1
                  fi

                  echo "Download Artifact from ${ARTIFACT_LOCATION}"

                  # Use skbn command if ARTIFACT_LOCATION is in s3 format otherwise use curl
                  if ! test ${ARTIFACT_LOCATION#s3} == "${ARTIFACT_LOCATION}"; then

                    # Set required environment variables for skbn
                    initializeSkbnConfiguration "${ARTIFACT_LOCATION}"

                    echo "Copying: '${ARTIFACT_RUNTIME_ZIP}' to '${SKBN_K8S_PREFIX}'"

                    if ! skbnCopy "${SKBN_CLOUD_PREFIX}" "${SKBN_K8S_PREFIX}${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}"; then
                      echo "Failed to copy ${ARTIFACT_RUNTIME_ZIP}"
                      exit 1
                    fi

                  else
                    curl "${ARTIFACT_LOCATION}" --output ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                  fi

                  if test $(echo $?) == "0"; then

                    # Unzip artifact plugin
                    if ! unzip -o ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} -d ${UNZIP_DOWNLOAD_DIR}; then
                        echo Artifact ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} could not be unzipped.
                        exit 1
                    fi

                    # Validate /lib directory is included in the zip and the artifact jar
                    ! test -d ${UNZIP_DOWNLOAD_DIR}/lib && echo "Artifact required lib directory could not be found." && exit 1
                    ! test -f ${UNZIP_DOWNLOAD_DIR}/lib/*jar && echo "Artifact required jar file could not be found." && exit 1

                    # Extend the permissions of all detected jars
                    find ${UNZIP_DOWNLOAD_DIR} -name *.jar -exec chmod 777 {} \;

                    # If exist remove any previous versions of artifact plugin
                    test -f ${OUT_DIR}/instance/lib/${ARTIFACT_NAME}-[0-9]*.jar && \
                    rm ${OUT_DIR}/instance/lib/${ARTIFACT_NAME}-[0-9]*.jar

                    # Deploy artifact plugin to server
                    cp -prf ${UNZIP_DOWNLOAD_DIR}/* ${OUT_DIR}/instance

                    echo "Artifact ${ARTIFACT_RUNTIME_ZIP} successfully deployed"

                  else
                    echo "Artifact download failed from ${ARTIFACT_LOCATION}"
                    exit 1
                  fi

                  # Cleanup
                  test -f "${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}" && rm ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                  test -d "${UNZIP_DOWNLOAD_DIR}" && rm -rf "${UNZIP_DOWNLOAD_DIR}"

                else
                  echo "Artifact ${ARTIFACT_NAME} is specified more than once in ${STAGING_DIR}/artifacts/artifact-list.json"
                  exit 1
                fi
              fi
            else
              echo "Artifact Version for ${ARTIFACT_NAME} could not be retrieved from ${STAGING_DIR}/artifacts/artifact-list.json"
              exit 1
            fi
          else
            echo "Missing Artifact Name within ${STAGING_DIR}/artifacts/artifact-list.json"
            exit 1
          fi

        done

        # Print listed files from deploy and conf
        ls ${OUT_DIR}/instance/lib

      else
        echo "Artifacts will not be deployed as could not parse ${STAGING_DIR}/artifacts/artifact-list.json."
        exit 1
      fi
    else
      echo "Artifacts will not be deployed as the environment variable ARTIFACT_REPO_URL and PING_ARTIFACT_REPO_URL are empty."
      exit 0
    fi
  else
    echo "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json is empty."
    exit 0
  fi
else
  echo "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json doesn't exist."
  exit 0
fi
