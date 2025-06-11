import unittest
from kubernetes import client, config

class TestApplicationStatus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        config.load_kube_config()
        cls.v1 = client.CoreV1Api()
        cls.all_pods = cls.v1.list_namespaced_pod(namespace='elastic-stack-logging', watch=False).items

    def test_opensearch_pods_running(self):
        pods = self.all_pods
        opensearch_hot_running = all( pod.status.phase == 'Running' for pod in pods if pod.metadata.name.startswith('opensearch-cluster-hot'))
        self.assertTrue(opensearch_hot_running, "opensearch-cluster-hot pod is not running")

    def test_logstash_pods_running(self):
        pods = self.all_pods
        logstash_running = all(pod.status.phase == 'Running' for pod in pods if pod.metadata.name.startswith == 'logstash-elastic' )
        self.assertTrue(logstash_running, "logstash pod is not running")

    def test_os_bootstrap_pod_running_or_completed(self):
        pods = self.all_pods
        for pod in pods:
            if pod.metadata.name.startswith('logstash-elastic'):
                init_statuses = pod.status.init_container_statuses or []
                is_running_or_completed = any(
                    init.name == 'opensearch-bootstrap' and (
                        (init.state.running is not None) or
                        (init.state.terminated is not None and init.state.terminated.exit_code == 0)
                    )
                    for init in init_statuses
                )
                self.assertTrue(
                    is_running_or_completed,
                    f"'opensearch-bootstrap' initContainer is neither running nor completed in pod {pod.metadata.name}"
                )

    def test_opensearch_cluster_dashboards_pods_running(self):
        pods = self.all_pods
        opensearch_cluster_dashboards_running = all(pod.status.phase == 'Running' for pod in pods if pod.metadata.name.startswith('opensearch-cluster-dashboards'))
        self.assertTrue(opensearch_cluster_dashboards_running, "opensearch-cluster-dashboards pods are not running")

    def test_os_controller_manager_pods_running(self):
        pods = self.all_pods
        os_controller_manager_running = all(pod.status.phase == 'Running' for pod in pods if pod.metadata.name.startswith('os-controller-manager'))
        self.assertTrue(os_controller_manager_running, "os-controller-manager pods are not running")

    def test_fluent_bit_pods_running(self):
        pods = self.all_pods
        fluent_bit_running = all(pod.status.phase == 'Running' for pod in pods if pod.metadata.name.startswith('fluent-bit'))
        self.assertTrue(fluent_bit_running, "fluent bit pods are not running")

if __name__ == '__main__':
    unittest.main()
