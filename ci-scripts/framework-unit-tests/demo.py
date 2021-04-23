#! /usr/bin/python

import requests
import yaml
import hashlib
import zipfile
import io

from os import environ as env
from dotmap import DotMap
from kubernetesAbstraction import KubernetesProvider
from configurationHelper import ConfigHelper
from cloudProviderAbstraction import CloudProvider
from clusterStateAbstraction import ClusterStateProvider



class DemoYaml(object):
    def __init__(self):
        pass

    def loadJob(self):
        url = "https://raw.githubusercontent.com/pingidentity/ping-cloud-base/v1.9-release-branch/k8s-configs/ping-cloud/base/pingdirectory/server/aws/backup.yaml"
        response = requests.get(url)
        assert response is not None
        assert response.status_code == 200
        content = list(yaml.load_all(response.text, Loader=yaml.FullLoader))
        assert content is not None
        assert len(content) == 1
        jobspec = DotMap(content[0])
        assert jobspec is not None
        assert 'kind' in jobspec
        assert jobspec['kind'] == 'Job'
        assert jobspec.kind == 'Job'
        return jobspec

class DemoPods(object):
     def __init__(self):
        self.namespace=env.get("NAMESPACE") 

     def listPods(self):
         k8s = KubernetesProvider()
         pods = k8s.getPodsInNamespace(namespace=self.namespace)
         for i, pod in enumerate(pods.items):
             print("{}:   {}".format(i,pod.metadata.name))


class DemoBucket(object):
     def __init__(self):
        self.cloud =  CloudProvider()

     def listBucket(self):
        bucket = "s3://ci-cd-backup-bucket/pingfederate"
        objectStore = self.cloud.getObjectStore()
        objectKeys = objectStore.getKeys(path=bucket)
        for i, entry in  enumerate(objectKeys):
            print("{}:  {}  {}".format(i,entry[1],entry[0]))

     def validateArchive(self):
        os = self.cloud.getObjectStore() 
        path = "s3://ci-cd-backup-bucket/pingfederate/latest.zip"
        #
        # Pretend we have the data-MM-DD-YYYY.HH.MM.SS.zip file from running the backup
        #
        body1 = os.getObject(path=path)
        #
        # Get the latest.zip file
        #
        body2 = os.getObject(path=path)
        #
        # print a teaser
        #
        print("body1: " + str(body1[0:20]))
        print("body2: " + str(body2[0:20]))
        print()
        #
        # Compare them, this could be done direct rather than via a hash.
        #
        hash1 = hashlib.sha256()
        hash1.update(body1)
        hash2 = hashlib.sha256()
        hash2.update(body2)
        assert hash1.digest() == hash2.digest()
        #
        # List one of the archives
        #
        filenames = []
        archive = zipfile.ZipFile(io.BytesIO(body1), "r")
        print("Zipfile Contents")
        print("================")
        print()
        for fileinfo in archive.infolist():
            print(fileinfo.filename)


if __name__ == "__main__":
    print("-" * 100)
    print("Read And Validate Job from Github URL")
    print("-" * 100)
    jobspec = DemoYaml().loadJob()
    print("JobName: {}".format(jobspec.metadata.name))
    print("-" * 100)
    print("List Pods in {} namespace".format(env.get("NAMESPACE")))
    print("-" * 100)
    DemoPods().listPods()
    print("-" * 100)
    print("List the PingFederate Backup Bucket Contents")
    print("-" * 100)
    cloud = DemoBucket()
    cloud.listBucket()
    print("-" * 100)
    print("Get Latest backup & latest.zip file, compare them & list archive contents")
    print("-" * 100)
    cloud.validateArchive()
    print("-" * 100)
