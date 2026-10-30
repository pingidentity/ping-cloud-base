"""Black-box pod priority tier test.

Asserts the priority-tier contract against a live cluster using only
workload pod-template specs and PriorityClass objects. Class names are
resolved from the workloads and values from the API; no class values are
hardcoded:

  1. The tier's PriorityClasses exist in the cluster: both vital classes
     and the PingDirectory class.
  2. The PingDirectory, PingDirectoryProxy, New Relic, and Fluent Bit
     workloads are assigned a priorityClassName. Workloads that are not
     deployed on the cluster are skipped - this is a tier-contract test,
     not an existence test.
  3. The New Relic and Fluent Bit class values are less than the
     PingDirectory and PingDirectoryProxy class values.

Spec-level reads (pod templates, not pod status), so the test is valid while
pods are deploying or mid-rollout.
"""

import unittest

import kubernetes as k8s

from k8s_utils import K8sUtils

# The PriorityClasses the tier model requires in every cluster. The vital
# classes follow the p1as-vital naming convention; PingDirectory's class
# predates the convention, so its name is hardcoded here.
REQUIRED_CLASSES = (
    "p1as-vital-fluentbit",
    "p1as-vital-observability",
    "pingdirectory-high-priority",
)

# The workloads covered by the tier model, as (kind, name, namespace).
# PingDirectory and PingDirectoryProxy are the Critical tier;
# Fluent Bit and the New Relic infrastructure workloads are the Vital tier
# The nri-bundle chart applies one priorityClassName across
# the newrelic-infrastructure subchart, so the ksm Deployment carries the
# class alongside the kubelet DaemonSet and is asserted too. Any workload
# not deployed on the cluster is skipped
WORKLOADS = {
    "PingDirectory": ("statefulset", "pingdirectory", "ping-cloud"),
    "PingDirectoryProxy": ("statefulset", "pingdirectoryproxy", "ping-cloud"),
    "fluent-bit": ("daemonset", "fluent-bit", "elastic-stack-logging"),
    "newrelic-kubelet": ("daemonset", "nri-bundle-nrk8s-kubelet", "newrelic"),
    "newrelic-ksm": ("deployment", "nri-bundle-nrk8s-ksm", "newrelic"),
}

# Workloads ranked below PingDirectory/PingDirectoryProxy in the Vital tier.
VITAL_WORKLOADS = ("fluent-bit", "newrelic-kubelet", "newrelic-ksm")

# Workloads ranked at the top of the tier model (the Critical tier).
CRITICAL_WORKLOADS = ("PingDirectory", "PingDirectoryProxy")


class TestPodPriorityTiers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kube = K8sUtils()
        cls.class_names = {}
        cls.class_values = {}
        for wl, (kind, name, ns) in WORKLOADS.items():
            try:
                class_name = cls.kube.get_workload_priority_class_name(kind, name, ns)
            except k8s.client.exceptions.ApiException as e:
                if e.status == 404:
                    print(f"{wl} not deployed on this cluster; skipping")
                    continue
                raise
            cls.class_names[wl] = class_name
            if class_name:
                cls.class_values[wl] = cls.kube.get_priority_class_value(class_name)

    def test_required_classes_exist(self):
        """The vital classes and the PingDirectory class exist in the cluster."""
        class_names = self.kube.get_priority_class_names()
        for name in REQUIRED_CLASSES:
            with self.subTest(priority_class=name):
                self.assertIn(
                    name,
                    class_names,
                    f"required PriorityClass '{name}' not found in cluster",
                )

    def test_workloads_assigned_priority_class(self):
        """PD, PDP, NR, and FLB workloads are assigned a priorityClassName."""
        if not self.class_names:
            self.fail("none of the expected workloads were found on this cluster")
        for wl, class_name in self.class_names.items():
            with self.subTest(workload=wl):
                self.assertTrue(
                    class_name,
                    f"{wl} has no priorityClassName assigned",
                )

    def test_vital_values_below_critical(self):
        """The NR and FLB class values are less than the PD and PDP values."""
        critical = [
            wl for wl in CRITICAL_WORKLOADS if wl in self.class_names
        ]
        if not critical:
            self.skipTest(
                "neither PingDirectory nor PingDirectoryProxy deployed on "
                "this cluster"
            )
        for vital in VITAL_WORKLOADS:
            with self.subTest(workload=vital):
                if vital not in self.class_names:
                    self.skipTest(f"{vital} not deployed on this cluster")
                for critical_wl in critical:
                    with self.subTest(critical=critical_wl):
                        self.assertLess(
                            self.class_values[vital],
                            self.class_values[critical_wl],
                            f"{vital} ({self.class_names[vital]}="
                            f"{self.class_values[vital]}) is not below "
                            f"{critical_wl} ({self.class_names[critical_wl]}="
                            f"{self.class_values[critical_wl]})",
                        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
