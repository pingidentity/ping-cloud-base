#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

if test -f "${STAGING_DIR}/artifacts/artifact-list.json"; then
  # Check to see if the artifact file is empty
  ARTIFACT_LIST_JSON=$(cat "${STAGING_DIR}/artifacts/artifact-list.json")
  if test ! -z "${ARTIFACT_LIST_JSON}"; then
    # Check to see if the source S3 bucket(s) are specified
    if test ! -z "${ARTIFACT_REPO_URL}" -o ! -z "${PING_ARTIFACT_REPO_URL}"; then

      echo "Private Repo : ${ARTIFACT_REPO_URL}"
      echo "Public Repo  : ${PING_ARTIFACT_REPO_URL}"

      if ! which jq > /dev/null; then
        echo "Installing jq"
        pip3 install --no-cache-dir --upgrade jq
      fi

      # Check to see if the artifact list is a valid json string
      echo ${ARTIFACT_LIST_JSON} | jq
      if test $(echo $?) == "0"; then
        if ! which unzip > /dev/null; then
          echo "Installing unzip"
          pip3 install --no-cache-dir --upgrade unzip
        fi

        # Install AWS CLI if the upload location is S3
        if test ! "${ARTIFACT_REPO_URL#s3}" == "${ARTIFACT_REPO_URL}" -o ! "${PING_ARTIFACT_REPO_URL#s3}" == "${PING_ARTIFACT_REPO_URL}"; then
          installTools
        fi

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

        for artifact in $(echo "${ARTIFACT_LIST_JSON}" | jq -c '.[]'); do
          _artifact() {
            echo ${artifact} | jq -r ${1}
          }

          ARTIFACT_NAME=$(_artifact '.name')
          ARTIFACT_VERSION=$(_artifact '.version')
          ARTIFACT_SOURCE=$(_artifact '.source')
          ARTIFACT_RUNTIME_ZIP=${ARTIFACT_NAME}-${ARTIFACT_VERSION}-runtime.zip

          # Check to see if artifact name and version are available
          if ( ( test ! "${ARTIFACT_NAME}" == "null" ) && ( test ! -z ${ARTIFACT_NAME} ) ); then
            if ( ( test ! "${ARTIFACT_VERSION}" == "null" ) && ( test ! -z ${ARTIFACT_VERSION} ) ); then

              # Check to see if the Artifact Source URL is available
              if ( ( test "${ARTIFACT_SOURCE}" == "private" ) && ( test -z ${ARTIFACT_REPO_URL} ) ) || ( ( test "${ARTIFACT_SOURCE}" == "public" ) && ( test -z ${PING_ARTIFACT_REPO_URL} ) ); then
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
                    ARTIFACT_LOCATION=${PUBLIC_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_RUNTIME_ZIP}
                  fi

                  echo "Download Artifact from ${ARTIFACT_LOCATION}"

                  # Use aws command if ARTIFACT_LOCATION is in s3 format otherwise use curl
                  if ! test ${ARTIFACT_LOCATION#s3} == "${ARTIFACT_LOCATION}"; then
                    aws s3 cp "${ARTIFACT_LOCATION}" ${DOWNLOAD_DIR}
                  else
                    curl "${ARTIFACT_LOCATION}" --output ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                  fi

                  # Unzip deploy and conf folders from the runtime zip
                  if test $(echo $?) == "0"; then
                    if ! unzip -o ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} "deploy/*" "conf/*" -d ${OUT_DIR}/instance/server/default
                    then
                        echo Artifact ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} could not be unzipped.
                        exit 1
                    fi
                  else
                    echo "Artifact download failed from ${ARTIFACT_LOCATION}"
                    exit 1
                  fi

                  # Cleanup
                  if test -f "${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}"; then
                    rm ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                  fi
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
        ls ${OUT_DIR}/instance/server/default/deploy
        ls ${OUT_DIR}/instance/server/default/conf/template
        ls ${OUT_DIR}/instance/server/default/conf/language-packs

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
