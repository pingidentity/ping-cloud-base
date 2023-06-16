# Ping Cloud Base Configuration

This directory contains all the base Kubernetes configuration files that may be
used to deploy the Ping Cloud software stack onto a Kubernetes cluster. It
allows anyone to set up a cookie-cutter Ping Software stack on a Kubernetes
cluster for evaluation purposes. Currently only AWS EKS clusters are supported.

# Disclaimer

>The software provided hereunder is provided on an "as is" basis, without
any warranties or representations express, implied or statutory; including,
without limitation, warranties of quality, performance, non-infringement,
merchantability or fitness for a particular purpose. Nor are there any
warranties created by a course or dealing, course of performance or trade
usage. Furthermore, there are no warranties that the software will meet
your needs or be free from errors, or that the operation of the software
will be uninterrupted. In no event shall the copyright holders or
contributors be liable for any direct, indirect, incidental, special,
exemplary, or consequential damages however caused and on any theory of
liability, whether in contract, strict liability, or tort (including
negligence or otherwise) arising in any way out of the use of this
software, even if advised of the possibility of such damage.

# Warning

This repository is still under active development and should not be used at this
time for production purposes due to potential breaking changes.

# Testing

The following tools must be set up and configured correctly:

- kubectl (>= v1.14)
- kustomize (>= v3.2)
- envsubst (>= 0.20)

To set up the environment, the following environment variables must be exported
at the very minimum:

- PING_IDENTITY_DEVOPS_USER
- PING_IDENTITY_DEVOPS_KEY
- BACKUP_URL
- TENANT_DOMAIN

The DEVOPS user and key may be obtained from the Ping DevOps GTE team here:

https://docs.google.com/forms/d/e/1FAIpQLSdgEFvqQQNwlsxlT6SaraeDMBoKFjkJVCyMvGPVPKcrzT3yHA/viewform

The TENANT_DOMAIN must be an AWS registered domain and hosted zone on Route53 in
the same AWS IAM role (e.g. arn:aws:iam::555555555555:role/ROLE) as your EKS
cluster. For example, if it is set to k8s-icecream.ping-devops.com, then
ping-devops.com must be a valid DNS domain registered by some registrar (e.g.
AWS Route53). There must also be a hosted zone created for it on AWS Route53.
Refer to the AWS online documentation on how to set these up.

The BACKUP_URL must point to an s3 bucket on AWS. PingFederate in clustered mode
(which is the default) requires an s3 bucket for high availability and fault tolerance. 

To build the environment, simply run:

```
kustomize build https://github.com/pingidentity/ping-cloud-base?ref=master |
  envsubst '
    ${PING_IDENTITY_DEVOPS_USER}
    ${PING_IDENTITY_DEVOPS_KEY}
    ${BACKUP_URL}
    ${TENANT_DOMAIN}' |
  kubectl apply -f -
```

Monitor it by running:

```
kubectl get pods -n ping-cloud
```

When all pods are ready, you should be able to access the following URLs:

```
Pingfederate console:
https://pingfederate-admin.k8s-icecream.ping-devops.com/pingfederate/app

Pingfederate API:
https://pingfederate-admin.k8s-icecream.ping-devops.com/pf-admin-api/api-docs

Pingfederate runtime endpoint:
https://pingfederate.k8s-icecream.ping-devops.com

Pingfederate oauth playground:
https://pingfederate.k8s-icecream.ping-devops.com/OAuthPlayground

Pingaccess console:
https://pingaccess-admin.k8s-icecream.ping-devops.com

Pingaccess API:
https://pingaccess-admin.k8s-icecream.ping-devops.com/pa-admin-api/v3/api-docs/

Pingaccess runtime endpoint:
https://pingaccess.k8s-icecream.ping-devops.com

Pingaccess WAS console:
https://pingaccess-was-admin.k8s-icecream.ping-devops.com

Pingaccess WAS API:
https://pingaccess-was-admin.k8s-icecream.ping-devops.com/pa-admin-api/v3/api-docs/

Pingaccess WAS runtime endpoint:
https://pingaccess-was.k8s-icecream.ping-devops.com

OpenSearch Dashboards console:
https://logs.k8s-icecream.ping-devops.com
```

Information on how to access the environments may be found here:

https://github.com/pingidentity/pingidentity-devops-getting-started/tree/master/11-docker-compose/03-full-stack

# Customization

The configuration in this repository may be used as a base for any customer
deployment by simply providing a kustomization.yaml file that looks like this:

```
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
- https://github.com/pingidentity/ping-cloud-base/k8s-configs?ref=master
```

In addition, some overrides must be provided (e.g. via secret and configmap
generators) for the DEVOPS user/key and the ingress URLs at a minimum. The
kustomization.yaml in the root of this repository shows an example of how this
can be done. More information on kustomize may be found here:

https://kustomize.io/

Then, a new environment may simply be created by running:

```
kustomize build . | kubectl apply -f -
```

Note that the manifest files only work with kustomize v3.1.0 or later. The
kustomize that's included in kubectl is of an older version. So the following
direct invocation from kubectl does not work at the moment.

~~kubectl apply -k .~~


# Gotchas
Make sure that your branch name is sufficiently short (<37 characters)

When automatically testing with CI/CD, the URLs created are based on the git branch name.
If this branch name is too long, AWS Route53 will not be able to generate the URLs and your tests will fail.

Gitlab push rules are set up to not allow you to push to the branch if this is the case, however, 
you can also add this git hook to prevent this from occurring before you even push to Gitlab:

```
❯ cat .git/hooks/pre-push
#!/bin/sh

CUR_BRANCH=$(git branch --show-current)

if [[ $(echo "${CUR_BRANCH}" | wc -c) -gt 37 ]]; then
  echo "Your branch name is too long. Please shorten to 37 characters or less to comply with route53 max length requirements"
  exit 1
fi
```
