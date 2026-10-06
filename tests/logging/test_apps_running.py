import unittest
from datetime import datetime, timedelta, timezone

from kubernetes import client, config

# A pod that is not Running is acceptable while the cluster churns under it: Karpenter
# spot reclaims and consolidation replace nodes mid-run on the ci-cd clusters , and a
# DaemonSet pod on a dying/new node sits in Pending until its replacement starts. Those
# states are transient and skipped; a pod not Running on a healthy, settled node fails.
TRANSIENT_POD_AGE = timedelta(minutes=2)


class TestApplicationStatus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        config.load_kube_config()
        cls.v1 = client.CoreV1Api()
        cls.all_pods = cls.v1.list_namespaced_pod(namespace='elastic-stack-logging', watch=False).items
        cls.all_nodes = cls.v1.list_node(watch=False).items

    def _transient_reason(self, pod):
        """Why a non-Running pod's state is explained by node churn, or None if not."""
        age = datetime.now(timezone.utc) - pod.metadata.creation_timestamp.replace(tzinfo=timezone.utc)
        if age < TRANSIENT_POD_AGE:
            return f"pod created {age.total_seconds():.0f}s ago (mid-replacement)"
        node = next((n for n in self.all_nodes if n.metadata.name == pod.spec.node_name), None)
        if node is None:
            return "pod not scheduled to a node yet"
        if node.metadata.deletion_timestamp:
            return f"node {node.metadata.name} is terminating"
        if any(t.key == "karpenter.sh/disrupted" for t in (node.spec.taints or [])):
            return f"node {node.metadata.name} is draining (karpenter disruption)"
        ready = next((c for c in node.status.conditions if c.type == "Ready"), None)
        if ready is None or ready.status != "True":
            return f"node {node.metadata.name} is not Ready"
        return None

    def _assert_pods_running(self, prefix, label):
        not_running = [
            pod for pod in self.all_pods
            if pod.metadata.name.startswith(prefix) and pod.status.phase != 'Running'
        ]
        blocking = []
        for pod in not_running:
            reason = self._transient_reason(pod)
            if reason:
                print(f"  [SKIP] {pod.metadata.name} is {pod.status.phase}: {reason}")
            else:
                blocking.append(f"{pod.metadata.name} is {pod.status.phase}")
        self.assertFalse(
            blocking,
            f"{label} pods are not running on healthy nodes: {'; '.join(blocking)}"
        )

    def test_opensearch_pods_running(self):
        self._assert_pods_running('opensearch-cluster-hot', 'opensearch-cluster-hot')

    def test_logstash_pods_running(self):
        self._assert_pods_running('logstash-elastic', 'logstash')

    def test_os_bootstrap_pod_running_or_completed(self):
        pods = self.all_pods
        for pod in pods:
            if pod.metadata.name.startswith('logstash-elastic') and not pod.metadata.name.startswith('logstash-elastic-s3'):
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
        self._assert_pods_running('opensearch-cluster-dashboards', 'opensearch-cluster-dashboards')

    def test_os_controller_manager_pods_running(self):
        self._assert_pods_running('os-controller-manager', 'os-controller-manager')

    def test_fluent_bit_pods_running(self):
        self._assert_pods_running('fluent-bit', 'fluent bit')

if __name__ == '__main__':
    unittest.main()
