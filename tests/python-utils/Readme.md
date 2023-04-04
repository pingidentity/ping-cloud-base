# Python Utils Readme

1/. This directory is set in the PYTHONPATH for any python source code meant to be shared between integration tests.
Any source code outside of this directory must live completely within the python file being executed in order to be 
successful.

2/. Add all python dependency requirements to the `requirements.txt` file in this directory. 
Note: If installing these dependencies start to take a significant amount of time, we should move this install to the 
Dockerfile for the image instead of doing it here during the integration tests. 
