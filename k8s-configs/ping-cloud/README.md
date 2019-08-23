# Summary

This directory contains all the Kubernetes configuration files that may be used
to deploy the Ping Cloud software stack to a Kubernetes cluster.

# Variables

The configuration files contain variables so there are no collisions when they
are applied through the CI/CD pipeline.

If these Kubernetes configuration files are to be directly applied with
"kubectl apply -k" (e.g. kubectl apply -k overlays/prod), then all occurrences
of these variables must be replaced with unique values appropriate for the
Kubernetes cluster.

The following variables are currently used and sourced from .gitlab-ci.yml:

```
NAMESPACE_NAME - a unique name for the environment
```

The following sed command may be used on Unix systems to recursively replace
any variable (e.g. ${NAMESPACE_NAME}) with appropriate values:


```
find . -type f -exec sed -i.bak 's|\${NAMESPACE_NAME}|k8s-icecream|g' {} \;
```

where "k8s-icecream" is the namespace where the configuration files will be
applied on the Kubernetes cluster.

Alternatively, the consolidated Kubernetes manifest may be generated for the
production environment by running:

```
NAMESPACE=k8s-icecream kustomize build overlays/prod
```

# CI/CD Pipeline

The following command must be run on the  Gitlab runner to apply the
configuration files:

```
kustomize build overlays/${PROFILE} | envsubst | kubectl apply -f -
```

where PROFILE may be one of "prod" or "test" and set in .gitlab-ci.yml.
If PROFILE is not set, then "test" is automatically assumed.
