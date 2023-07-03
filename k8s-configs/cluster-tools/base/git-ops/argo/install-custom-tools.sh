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

### Install specific Kustomize version ###
KUSTOMIZE_VERSION=5.0.3

wget -qO /tools/kustomize \
    "https://ping-artifacts.s3.us-west-2.amazonaws.com/pingcommon/kustomize/${KUSTOMIZE_VERSION}/linux_amd64/kustomize"
chmod a+x /tools/kustomize