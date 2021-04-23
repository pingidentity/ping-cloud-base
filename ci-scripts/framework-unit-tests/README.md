# Application Test Framework - Unit Tests
## Overview
The application test framework, while primarily intended for running hardening tests, can be used for unit and integration testing as well. Test using the framework need to live under a common root directory. It is possible to use multiple directories but each will need to be a separate invocation of the docker image. 

As initially deployed (April 2021) the framework is configured to only run unit tests located in ***ping-cloud-base/ci-scripts/framework-unit-tests***. The scrip ***ping-cloud-base/ci-scripts/run-framework-unit-tests*** is the driver that runs the docker container. The driver script requires that the tests directory (framework-unit-tests in this case) be in the same directory as the script itself. The framework does not impose any specific python framework but pytest is included in the image should developers wish to use it. The framework image does not enforce the use of python and can be used to run bash scripts as well.  

 
## The Demo Scripts

The initial deployment contains an orchestration script and two simple code samples, these test server no purpose other than demonstrating the test runner works, they can be deleted once real tests are in place. I expect the orchestration script, which is called by the containers entrypoint script, to be replaced with something more appropriate depending on how developers choose to use the framework.   


The initial deployment comprises this read-me file and the following demo files. 

|File |Purpose |
|:--- |:--- |
|**run-framework-unit-tests**|The script that configures and runs the docker container.
|**run.sh**|A shell script, called from the container's entrypoint script, that orchestrates the two demo tests below.
|**demo.py**|A demo Python Program, executed inside the container. This uses the framework abstraction layers to read a yaml jobspec from github and do some basic validation. List the pods in the ping-cloud namespace, list the s3 backup bucket, download and simulate validating a backup job, list the ocntents of the downloaded archive.
|**shell-sample.sh**|A demo Shell Script, executed inside the container. This demonstrates that AWS and Kubectl work inside the container.


## Workflow

This is the test runner script (**run-framework-unit-tests**) is called from the .gitlab-ci.yml file using the following unit-test stage fragment.

```
framework-unit-tests:
  stage: unit-test
  tags:
  - shell-runner
  script:
     - ./ci-scripts/run-framework-unit-tests
```

The script set up various environment variables and build the docker run command, a copy of the script follows, the comments in the script should provide enough explanation to create additional runners if needed. 

```
  1 #! /bin/bash
  2 pushd $(cd $(dirname ${0});pwd -P)/framework-unit-tests 2>&1 > /dev/null
  3 #
  4 # Program constants
  5 #
  6 declare -r image="pingcloud-docker.jfrog.io/pingidentity/pyaws:latest"
  7 declare -r profile=csg
  8 #
  9 # Trying to pass the KUBE_CA_PARAM environment variable via the docker run command
 10 # doesn't work due to the embedded newlines, the simplest solution is to create a
 11 # local file and map it into the container.
 12 #
 13 echo "${KUBE_CA_PEM}" > ./kube.ca.pem
 14 #
 15 # Build the docker run command. First the environment variables needed to create
 16 # the AWS config/credential & Kubernetes context files.
 17 #
 18 cmd=""
 19 cmd="${cmd} -e profile=${profile}"
 20 cmd="${cmd} -e region=${AWS_DEFAULT_REGION}"
 21 cmd="${cmd} -e role=${AWS_ACCOUNT_ROLE_ARN}"
 22 cmd="${cmd} -e key=${AWS_ACCESS_KEY_ID}"
 23 cmd="${cmd} -e secret=${AWS_SECRET_ACCESS_KEY}"
 24 cmd="${cmd} -e cluster=${EKS_CLUSTER_NAME}"
 25 cmd="${cmd} -e kubeurl=${KUBE_URL}"
 26 #
 27 # Next we need to map the tests into the container if using the generic container,
 28 # if a container with an embedded test suite is used this section can be omitted.
 29 # in this case we're mapping the current working directory onto the tests folder.
 30 #
 31 cmd="${cmd}  -v $(pwd -p):/home/pyuser/tests"
 32 #
 33 # Next the configuration for the entrypoint script. 'hostenv=${OSTYPE}' paases the
 34 # host operating system type to the container (may be used to decide whether to set
 35 # file permissions for example). 'cicd=true' tells the entrypoint  script to create
 36 # the AWS & Kubernetes context files. The volume mapping makes the  cluster's root
 37 # certificate available to kubectl in order to create the .kube/context file. And
 38 # finally 'target=./test/test-scheduler.sh' tells the container which file to run.
 39 #
 40 cmd="${cmd} -e hostenv=${OSTYPE}"
 41 cmd="${cmd} -e cicd=true"
 42 cmd="${cmd} -v $(pwd)/kube.ca.pem:/home/pyuser/kube.ca.pem"
 43 cmd="${cmd} -e target=./tests/run.sh"
 44 #
 45 # Finally pipeline specific data needed by the tests. The content will be highly
 46 # dependent on the tests being run, the following is illustrative rather than
 47 # prescriptive.
 48 #
 49 if [[ ${CI_COMMIT_REF_SLUG} != master ]]; then
 50    cmd="${cmd} -e NAMESPACE=ping-cloud-${CI_COMMIT_REF_SLUG}"
 51 else
 52    cmd="${cmd} -e NAMESPACE=ping-cloud"
 53 fi
 54 cmd="${cmd} -e ARTIFACT_REPO_URL=s3://${EKS_CLUSTER_NAME}-artifacts-bucket"
 55 cmd="${cmd} -e PING_ARTIFACT_REPO_URL=https://ping-artifacts.s3-us-west-2.amazonaws.com"
 56 cmd="${cmd} -e LOG_ARCHIVE_URL=s3://${EKS_CLUSTER_NAME}-logs-bucket"
 57 cmd="${cmd} -e BACKUP_URL=s3://${EKS_CLUSTER_NAME}-backup-bucket"
 58 cmd="${cmd} -e CLUSTER_BUCKET_NAME="${EKS_CLUSTER_NAME}-cluster-bucket""
 59 #cmd="${cmd} "
 60 #
 61 # For testing ensure latest image, not needed in actual tests.
 62 #
 63 docker pull pingcloud-docker.jfrog.io/pingidentity/pyaws
 64 echo ""
 65 docker run ${cmd} ${image}
 66 echo ""
 67 popd 2>&1 > /dev/null
```
  
In brief the script changes to the test directory (line 2) and map it into the container at /home/pyuser/tests (line 31). The run.sh script is configured as the target (line 43). It explicitly pulls the docker image (line 63) and runs it (line 65). this hands off control to the entrypoint script in the container which is responsible for setting up the AWS & Kubernetes configuration files and then executing the run.sh script.  
  
The run.sh script can be replaces with a test driver script in either bash or python that runs the actual test suite.
## Test Development
### Overview
Since we're using a Docker container as the python environment you need an IDE that supports in-container development, we've tested both vscode & Pycharm during framework development, please see the test framework documentation on how to set up for development.  

## Framework Abstraction Layers
### Overview
The framework uses abstraction layers to protect the test code investment from the execution environment; specifically we abstract the AWS CLI, the Cluster-State-Repo (although it is assumed to be git) and the k8s API. The AWS abstraction breaks down into a number of abstract concepts like 'Parameter Store', 'Object Store' and 'CLI'. If the need to deploy on a non-AWS platform we will provide a different implentation of the Abstraction API. 

The k8s Abstraction serves a different purpose in that the kubernetes API is rapidly evolving with code moving from alpha through beta to the versioned api, as things move the calling mechanism changes so the k8a abstraction centralizes those details to a single point of maintenance.

Both the AWS & K8S APIs are so large that attempting to build the abstractions up front is not practical so we've adopted an approach of build as needed. This will require updating the abstraction layers as new requirements are identified.

### Abstraction layer implementation
The abstraction layers exist as python modules, in the docker images they are deployed to the path `/home/pyuser/.local/lib/python3.9/site-packages` but this location is not suitable for module development. That needs to be done in the ping-cloud-test-framework repository. 

The approach we've taken with the abstraction layers is to use keyword arguments so every abstraction layer method/function has the signature method(self, **kwargs) and is called using the general pattern method(arg1=...[, argn=...]\*) This approach allows us to extend the parameter list without changing the method signature. For example; if we have an AWS implementation of a method with a signature like method(path="/.../") and we have to provide an Azure implementation that requires a signature method(path="/.../", drive="c:") then there is no change to the underlying signature, the AWS implementation will extract the path parameter and ignore the drive parameter while the Azure implementation will use both. 
  

To facilitate unit test development I suggest that initially we allow direct calls to the underlying API (even if we had an Azure implementation most development would likely occur on AWS anyway) BUT it needs to be done in a way compatible with the framework. This is what I suggest.

The new method be places in a separate class and use the signature pattern described above. This will facilitate moving the method into the abstraction layers at a later date and will only require a change to the object on which the method is called in the original test. Such method **must** be documented using the python in-source documentation syntax as described in the test framework documentation. 