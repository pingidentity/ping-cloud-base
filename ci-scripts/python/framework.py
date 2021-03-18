from kubernetesHelper import KubernetesHelper

print('-' * 77)
print("PYTHON PROGRAM: Demo Test Framework k8s helper - list namespaces")
print('')
print("source code:")
print('\tfrom kubernetesHelper import KubernetesHelper')
print('')
print('\tk8s = KubernetesHelper()')
print('\tx = k8s.getNamespaces()')
print('')
print('\tfor y in x.items:')
print('\t    print(y.metadata.name)')
print('-' * 77)

k8s = KubernetesHelper()
x = k8s.getNamespaces()
for y in x.items:
    print(y.metadata.name)