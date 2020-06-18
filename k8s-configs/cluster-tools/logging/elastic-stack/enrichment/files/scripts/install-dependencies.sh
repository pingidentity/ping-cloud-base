#!/usr/bin/env sh

# This installs required dependencies into the configure-es container. 
# These are REQUIRED for the enrichment script to work.

logger "INFO" "Dependencies installation started."

yum install -y epel-release
yum install -y python-pip
pip install requests

if [ $(grep -q requests <(pip freeze --disable-pip-version-check); echo $?) -eq 0 ] && \
   [ $(grep -q python-pip <(yum list); echo $?) -eq 0 ] && \
   [ $(grep -q epel-release <(yum list); echo $?) -eq 0 ]; then
    echo "Dependencies installation done.";
else
    echo "Dependencies installation failed."
    exit 1
fi