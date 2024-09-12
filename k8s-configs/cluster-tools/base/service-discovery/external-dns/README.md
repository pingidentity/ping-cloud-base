# External-dns Base Yaml Manifeests
The base yaml manifests are obtained from:
https://github.com/kubernetes-sigs/external-dns/tree/master/kustomize

Run `./update-external-dns.sh NEW_VERSION` to upgrade:
- serviceaccount.yaml
- clusterrole.yaml
- clusterrolebinding.yaml
- deployment.yaml