#!/usr/bin/env sh

${VERBOSE} && set -x
source ./util.sh

# Set PATH - since this is executed from within the server process, it may not have all we need on the path
export PATH="${PATH}:${SERVER_ROOT_DIR}/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${JAVA_HOME}/bin"

CURRENT_DIRECTORY=$(pwd)

# Allow overriding theArtifact Source URL with an arg
test ! -z "${1}" && ARTIFACT_SOURCE_URL="${1}"
echo "Downloading Artifact ${ARTIFACT_SOURCE_URL}"

# Allow overriding the Artifact Repo Bucket with an arg
test ! -z "${2}" && ARTIFACT_REPO_BUCKET="${2}"
echo "Downloading from location ${ARTIFACT_REPO_BUCKET}"

# Install AWS CLI if the upload location is S3
if test "${ARTIFACT_REPO_BUCKET#s3}" == "${ARTIFACT_REPO_BUCKET}"; then
    echo "Upload location is not S3"
    exit 0
elif ! which aws > /dev/null; then
    echo "Installing AWS CLI"
    apk --update add python3
    pip3 install --no-cache-dir --upgrade pip
    pip3 install --no-cache-dir --upgrade awscli
fi

if [ -z "${ARTIFACT_REPO_BUCKET##*/pingfederate*}" ] ;then
    TARGET_BASE_URL="${ARTIFACT_REPO_BUCKET}"
else
    TARGET_BASE_URL="${ARTIFACT_REPO_BUCKET}/pingfederate"
fi

ARTIFACT_FILE_NAME="${ARTIFACT_SOURCE_URL##*/}"
echo ${ARTIFACT_FILE_NAME}
ARTIFACT_NAME="${ARTIFACT_FILE_NAME%-*}"
echo ${ARTIFACT_NAME}
ARTIFACT_NAME_WITH_VERSION="${ARTIFACT_FILE_NAME%.*}"
echo ${ARTIFACT_NAME_WITH_VERSION}
ARTIFACT_VERSION="${ARTIFACT_NAME_WITH_VERSION##*-}"
echo ${ARTIFACT_VERSION}
ARTIFACT_EXTENSION="${ARTIFACT_FILE_NAME##*.}"
echo ${ARTIFACT_EXTENSION}

# Cleanup artifact folder if it exists
if [ -f "/tmp/${ARTIFACT_NAME_WITH_VERSION}" ]
then
    rm -rf "/tmp/${ARTIFACT_NAME_WITH_VERSION}"
fi
mkdir /tmp/${ARTIFACT_NAME_WITH_VERSION}

# Download artifact zip
curl -f ${ARTIFACT_SOURCE_URL} --output /tmp/${ARTIFACT_FILE_NAME} && echo "Artifact successfully downloaded." || exit 1
cd /tmp/instance/server/default
#unzip ${ARTIFACT_LOCATION}/${ARTIFACT_FILE_NAME}
if [ ! -f "/tmp/${ARTIFACT_FILE_NAME}" ]
then
    echo Artifact could not be downloaded from ${ARTIFACT_SOURCE_URL}
    exit 1
fi

if ! unzip -o /tmp/${ARTIFACT_FILE_NAME} -d /tmp/${ARTIFACT_NAME_WITH_VERSION}
then
    echo Artifact /tmp/${ARTIFACT_FILE_NAME} could not be unzipped.
    exit 1
fi

if [ -d "/tmp/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME}" ]
then
    ARTIFACT_LOCATION="/tmp/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME}"
elif [ -d "/tmp/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME_WITH_VERSION}" ]
then
    ARTIFACT_LOCATION="/tmp/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME_WITH_VERSION}"
else
    # Sub folder is not the artifact name so enumerate and get the dynamic value
    cd /tmp/${ARTIFACT_NAME_WITH_VERSION}
    ARTIFACT_SUB_FOLDER=$(find . -mindepth 1 -maxdepth 1 -type d  \( ! -iname ".*" \) | sed 's|^\./||g')
    ARTIFACT_LOCATION="/tmp/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_SUB_FOLDER}"
    cd ${CURRENT_DIRECTORY}
fi

mkdir ${ARTIFACT_LOCATION}/work
mkdir ${ARTIFACT_LOCATION}/work/deploy
mkdir ${ARTIFACT_LOCATION}/work/conf
mkdir ${ARTIFACT_LOCATION}/work/conf/language-packs
mkdir ${ARTIFACT_LOCATION}/work/conf/template

cp ${ARTIFACT_LOCATION}/dist/*.jar ${ARTIFACT_LOCATION}/work/deploy
cp ${ARTIFACT_LOCATION}/dist/*.war ${ARTIFACT_LOCATION}/work/deploy

if [ -d "${ARTIFACT_LOCATION}/dist/vip-adapter-security-code-challenge.war" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/*.war ${ARTIFACT_LOCATION}/work/deploy
fi

if [ -d "${ARTIFACT_LOCATION}/dist/duo-web" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/duo-web ${ARTIFACT_LOCATION}/work/deploy
fi

if [ -d "${ARTIFACT_LOCATION}/dist/ds-pcv" ]
then
    cp ${ARTIFACT_LOCATION}/dist/ds-pcv/*.jar ${ARTIFACT_LOCATION}/work/deploy
fi

if [ -d "${ARTIFACT_LOCATION}/dist/provisioner" ]
then
    cp ${ARTIFACT_LOCATION}/dist/provisioner/*.jar ${ARTIFACT_LOCATION}/work/deploy
fi

cp ${ARTIFACT_LOCATION}/dist/*.html ${ARTIFACT_LOCATION}/work/conf/template

# Upload conf folder for PingOne for Customers Integration Kit as it exists inside a specific sub folder
if [ -d "${ARTIFACT_LOCATION}/dist/ds-pcv/conf" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/ds-pcv/conf/* ${ARTIFACT_LOCATION}/work/conf
fi

if [ -d "${ARTIFACT_LOCATION}/dist/template" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/template/* ${ARTIFACT_LOCATION}/work/conf/template
fi

if [ -d "${ARTIFACT_LOCATION}/conf/template" ]
then
    cp -r ${ARTIFACT_LOCATION}/conf/template/* ${ARTIFACT_LOCATION}/work/conf/template
fi

if [ -d "${ARTIFACT_LOCATION}/dist/language-packs" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/language-packs/* ${ARTIFACT_LOCATION}/work/conf/language-packs
fi

if [ -d "${ARTIFACT_LOCATION}/conf/language-packs" ]
then
    cp -r ${ARTIFACT_LOCATION}/conf/language-packs/* ${ARTIFACT_LOCATION}/work/conf/language-packs
fi

ARTIFACT_RUNTIME_ZIP=${ARTIFACT_NAME_WITH_VERSION}-runtime.zip

cd ${ARTIFACT_LOCATION}/work
zip -r  ${ARTIFACT_LOCATION}/${ARTIFACT_RUNTIME_ZIP} *
cd ${CURRENT_DIRECTORY}

echo ${ARTIFACT_LOCATION}/${ARTIFACT_FILE_NAME}
aws s3 cp "${ARTIFACT_LOCATION}/${ARTIFACT_RUNTIME_ZIP}" "${TARGET_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/"
check_for_error "Could not upload artifact(s) to ${TARGET_BASE_URL}"

rm /tmp/${ARTIFACT_FILE_NAME}
rm -rf /tmp/${ARTIFACT_NAME_WITH_VERSION}

