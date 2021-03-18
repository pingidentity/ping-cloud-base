import json
from os import popen

print('-' * 77)
print("PYTHON PROGRAM: Demo AWS CLI command execution")
print('')
print("source code:")
print('\tresult=popen("aws --profile csg s3 ls").read()')
print('\tprint(result)')
print('-' * 77)
result=popen("aws --profile csg s3 ls").read()
print(result)
print('-' * 77)
print("PYTHON PROGRAM: Demo 'kubectl' command execution")
print('')
print("source code:")
print('\tresult = popen("kubectl get pods -n {} -o json".format("ingress-nginx-private")).read().strip()')
print('\t' + r'for line in result.split("\n"):')
print('\t\tprint(line)')
print('-' * 77)
result = popen("kubectl get pods -n {} -o json".format("ingress-nginx-private")).read().strip()
for line in result.split('\n'):
    print(line)
