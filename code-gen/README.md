# ping-cloud-base (PCB) code-gen scripts

## Testing generate-cluster-state.sh

You should already have a file in your home directory called ~/YOUR_NAME-cluster.properties. This was created when you created your dev cluster.
Optionally, you can re-create this file to make sure it's up-to-date by running the following:

1. Go to the ping-cloud-tools repo and go to the create-cluster directory
2. Run `./CreateCluster PATH_TO_YOUR_CONFIG --prop-only` - you should already have a config used for your dev cluster, use this.
3. This will generate

Next, copy your properties file to something like test-generate.properties. Open the file an inspect the variables, specifically look for: 
K8S_GIT_BRANCH - change this to the branch you're on, especially if you want to actually build the uber yaml.
ENVIRONMENTS - change this to only build then environment(s) you need to build to test.

Finally, from the code-gen directory in PCB (this dir) run generate-cluster-state.sh after sourcing your file:
`source ~/test-generate.properties ./generate-cluster-state.sh`

## Testing push-cluster-state.sh

Generate cluster state will, by default, place all generated code into your `/tmp/sandbox` directory.

push-cluster-state.sh is responsible for massaging these files into a directory structure appropriate for a cluster-state-repo (CSR) and profile-repo.

We can test it by doing the following:

1. Create a new directory somewhere on your computer. NOTE: push-cluster-state.sh is very destructive so make sure you put this folder outside of a repo - something like ~/test-push-cluster should work
2. Run push-cluster-state.sh with the following options:
```
ENVIRONMENTS='test' IS_PRIMARY=true IS_PROFILE_REPO=false GENERATED_CODE_DIR=/tmp/sandbox DISABLE_GIT=true /tmp/sandbox/push-cluster-state.sh
```
Adjust the options as required to test (especially ENVIRONMENTS). Note DISABLE_GIT - this is an important one - it enables creation of a CSR/profile repo without git. This also means that only one ENVIRONMENT is supported at a time.