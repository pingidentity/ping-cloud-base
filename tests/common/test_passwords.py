import unittest
from k8s_utils import K8sUtils
import os
import base64


class TestPasswords(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.k8s = K8sUtils()

    def test_check_passwords(self):
        ns = os.getenv("PING_CLOUD_NAMESPACE", "ping-cloud")
        password_list = self.get_password_list(ns)
        self.assertEqual(
            0,
            len(password_list),
            f"Error. Found passwords in the logs. Verify once."
            )

    def get_password_list(self, ns):
        """
        Get list of passwords found in the container_logs
        of any pod in the given namespace
        :param ns: Name of the namesapce
        :return: [str] 
        """
        pods = self.k8s.core_client.list_namespaced_pod(ns)
        pod_name = None
        volumes = None
        volume_mounts = None
        container_name = None
        password_list = []
        container_statuses = []
        is_container_started = False
        # iterate through list of pods in the namespace
        for pod in pods.items:
            pod_name = pod.metadata.name
            volumes = pod.spec.volumes
            container_statuses = pod.status.container_statuses
            # iterate through the list of containers inside the current pod
            for container in pod.spec.containers:
                volume_mounts = container.volume_mounts
                container_name = container.name
                is_container_started = self.check_container_status(container_statuses, container_name)
                if is_container_started : 
                    # get the container logs
                    container_logs = self.get_container_logs(ns, pod_name, container_name)
                    # validate the container logs for any passwords
                    self.validate_container_logs(ns, volumes, volume_mounts,
                        pod_name, container_name, password_list, container_logs)
        return password_list

    def validate_container_logs( 
            self,ns,volumes,volume_mounts,
            pod_name,container_name,password_list,container_logs ):
        """
        Iterate through container volume_mounts
        and check if any of the secrets are 
        present in the container logs of given pod
        """
        try:
            for volume_mount in volume_mounts:
                secret_volume = None
                for volume in volumes:
                    if volume.name == volume_mount.name:
                        secret_volume = volume
                        break
                if secret_volume and secret_volume.secret:
                    secret_name = secret_volume.secret.secret_name
                    secret_data = self.get_secret_data(ns, secret_name)
                    # check secret_data is not empty
                    if secret_data.data and secret_data.data.items:
                        try:
                        # iterate through items and check for decoded value
                        # in the container_logs
                            for key, value in secret_data.data.items():
                                if 'keystore' in key or value is None:
                                    continue
                                decoded_value = base64.b64decode(value).decode("utf-8")
                                if container_logs and decoded_value in container_logs:
                                    password_list.append(key)
                                    print(f"{key} found in {container_name} logs in {pod_name}")

                        except UnicodeDecodeError as error:
                                print(f"Error decoding {key} : {error}")

        except Exception as e:
            print(f"Error checking volume_mounts on container {container_name} : {e}")

    def get_secret_data(self, ns, secret_name):
        """
        Get the specified secret from given namespace 
        """
        return self.k8s.core_client.read_namespaced_secret(secret_name, ns)

    def get_container_logs(self, ns, pod_name, container_name):
        """
        Get the container_logs from given pod and namespace 
        """
        return str(
            self.k8s.core_client.read_namespaced_pod_log(
                name=pod_name, container=container_name, namespace=ns, pretty=True
            )
        )
    
    def check_container_status(self, container_statuses, container_name):
        """
        Check the container status 
        """
        container_started = False
        for container_status in container_statuses:
            if container_status.name == container_name:
                if container_status.started == True:
                    container_started = True
        return container_started
