#!/bin/sh -ex

### git-remote-codecommit ###
pip install --upgrade pip
pip3 install git-remote-codecommit --no-warn-script-location

cp /usr/local/bin/git-remote-codecommit /tools
cp /usr/local/lib/python3.9/site-packages/git_remote_codecommit/__init__.py /tools

# On the ArgoCD container, python3 is available under /usr/bin/python3
sed -i 's|/usr/local/bin/python|/usr/bin/python3|' /tools/git-remote-codecommit
chmod a+x /tools/git-remote-codecommit

### envsubst and wget ###
apt-get update
apt-get -y install gettext-base wget
apt-get clean
rm -rf /var/lib/apt/lists/*
cp /usr/bin/envsubst /tools

### Install specific Kustomize versions - one for backwards compatibility as well as a new version ###
KUSTOMIZE_COMPATIBILITY_VERSION="5.0.3"
KUSTOMIZE_VERSION="5.5.0"

if [ "`uname -m`" = "aarch64" ] ; then
    ARCH="linux_arm64"
else
    ARCH="linux_amd64"
fi

wget -qO /tools/kustomize_5_0_3 \
    "https://ping-artifacts.s3.us-west-2.amazonaws.com/pingcommon/kustomize/${KUSTOMIZE_COMPATIBILITY_VERSION}/${ARCH}/kustomize"
chmod a+x /tools/kustomize_5_0_3

wget -qO /tools/kustomize \
    "https://ping-artifacts.s3.us-west-2.amazonaws.com/pingcommon/kustomize/${KUSTOMIZE_VERSION}/${ARCH}/kustomize"
chmod a+x /tools/kustomize
