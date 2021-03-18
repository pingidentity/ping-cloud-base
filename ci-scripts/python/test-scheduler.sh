#! /bin/bash
cd ${HOME}/tests
#
# run the shell sample
#
./shell-sample.sh
#
# run the kubectl python sample
#
python ./python-sample.py
#
# run the python k8s client example.
#
python ./framework.py
