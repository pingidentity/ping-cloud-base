import sys
from kubernetesHelper import KubernetesHelper


k8s = KubernetesHelper()
x = k8s.getNamespaces()
for y in x.items:
    print(y.metadata.name)