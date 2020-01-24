#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"


#---------------------------------------------------------------------------------------------
# Main Script 
#---------------------------------------------------------------------------------------------

#
# Run script from known location 
#
currentDir="$(pwd)"
cd /opt/out/instance/bin

#
# Setup S3 bucket path components 
#
directory="$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')"
target="${BACKUP_URL}/${directory}"
bucket="${BACKUP_URL#s3://}"
masterKey="${BACKUP_URL}/${directory}/pf.jwk"

#
# Install AWS tools
#
installTools 

#
# Wait for Admin node to become ready so we can get configuration. If the engine comes up first
# and no other engine is already running then it will fail to obtain configuration as it is the
# first server to join the cluster. Another server joining the cluster does *not* trigger a
# a fresh attempt to obtain configuration and manual intervention is required to push the
# configuration from the admin server. This code attempts to minimize the chance of this 
# happening without completely blocking start-up.
# 
# The worst case scenario is an enging scaling event with the admin server down. In this case it
# could take the full timebox duration before the sever starts when it could get configuration
# from another engine. The admin server usually starts within 60-90 seconds.
#
echo "Waiting up to 3 minutes for admin server to become ready"
count=180
while [ "$(kubectl get pods|grep "pingfederate-admin"|awk '{print $2}'|grep "1/1" >/dev/null 2>&1;echo "$?")" != "0" ] &&  [ "${count}" -gt "0" ]; do
   sleep 1
   count=$(( count - 1 ))
done   

#
# If the Pingfederate folder does not exist in the s3 bucket, create it
# 
if [ "$(aws s3 ls ${BACKUP_URL} > /dev/null 2>&1;echo $?)" = "1" ]; then
   aws s3api put-object --bucket "${bucket}" --key "${directory}/"
fi

#
# We may already have a master key on disk if one was supplied through a secret or the 'in'
# volume. If that is the case we will use that key during obfuscation. If one does not 
# exist we check to see if one was previously uploaded to s3
#
if ! [ -f ../server/default/data/pf.jwk ]; then
   echo "No local master key found check s3 for a pre-existing key"
   result="$(aws s3 ls ${masterKey} > /dev/null 2>&1;echo $?)"
   if [ "${result}" = "0" ]; then
      echo "A master key does exist on S3 attempt to retrieve it"
      if [ "$(aws s3 cp "${masterKey}" ../server/default/data/pf.jwk > /dev/null 2>&1;echo $?)" != "0" ]; then
         echo "Retrieval was unsuccessful - crash the container to prevent spurious key creation"
         exit 1
      else
         echo "Pre-existing master key found - using it"
         obfuscatePassword
      fi
   elif [ "${result}" != "1" ]; then
      echo "Unexpected error accessing S3 - crash the container to prevent spurious key creation"
      aws s3 ls ${masterKey}
      exit 1
   else
      echo "No pre-existing master key found - crash the container to prevent spurious key creation"
      exit 1
   fi 
else
   echo "A pre-existing master key was found on disk - using it"
   obfuscatePassword
fi
cd "${currentDir}"
