"""Black-box PD-only taint contract test.

Asserts the scheduling contract around the PD-only node pool against a live
cluster using only workload pod-template specs and Node objects.

PD-only nodes are tainted so that only PingDirectory workloads schedule onto
them. The pool's taint and node label are discovered dynamically from the
karpenter `pd-only` NodePool when it exists, so a platform-side rename of
the taint/label does not require editing this test. On cluster-autoscaler
clusters there is no in-cluster object declaring the taint (managed
nodegroup taints are applied at nodegroup provisioning, outside the k8s
API), so the module constants are used as a fallback there.

The contract:

  1. Cluster sanity: at least one node carries a discovered PD-only taint
     (skipped when the pool declares none - a label-only contract).
  2. No workload other than a DaemonSet, or one running in kube-system /
     kube-public / kube-node-lease, may schedule onto PD-only nodes - by
     any mechanism:
       - a toleration matching any taint of the PD-only pool (a bare
         `operator: Exists` with no key matches every taint of that effect;
         a keyed toleration naming the pool's taint key likewise),
       - a nodeSelector or required nodeAffinity selecting any node label
         the PD-only pool applies,
       - an explicit `nodeName` targeting a node carrying a PD-only taint.
     DaemonSets are exempt: a DaemonSet must run on every node (including
     PD-only ones) to scrape/collect from them. The PD workloads themselves
     are allowlisted below.

Covers Deployments, StatefulSets, CronJobs, and Jobs. Bare Jobs from other
stacks are typically ephemeral installer noise, but the PingDirectory backup
Job (applied on demand by the backup CronJob's script, tolerating pd-only to
mount the PD PVC) is a legitimate PD workload and is allowlisted below.
Spec-level reads (pod templates, not pod status), so the test is valid while
pods are deploying or mid-rollout.
"""

import json
import unittest

import kubernetes as k8s

from k8s_utils import K8sUtils

# Fallback PD taint/label, used only when the karpenter `pd-only` NodePool
# cannot be read (cluster-autoscaler-only clusters: EKS managed nodegroup
# taints are defined in the cluster provisioning config - the
# cluster-state-repo eksctl/CloudFormation settings for customer clusters,
# the CDE factory worker-node config for internal ones - and are only
# reflected in-cluster on the Node objects themselves). Keep these in sync
# with the platform defaults if the CA-side contract ever changes.
PD_TAINT_KEY = "pingidentity.com/pd-only"
PD_TAINT_VALUE = "true"
PD_TAINT_EFFECT = "NoSchedule"
PD_NODE_LABEL = "pingidentity.com/pd"

# The karpenter NodePool whose node-template taints/labels define the PD
# scheduling contract. Its name is load-bearing across the platform
# (karpenter.sh/nodepool=pd-only is asserted by the scaling tests), so it is
# the stable anchor for discovery.
PD_POOL_NAME = "pd-only"

# Namespaces excluded from the contract. Workloads there are cluster-critical
# platform agents whose scheduling is managed outside this stack.
EXCLUDED_NAMESPACES = (
    "kube-system",
    "kube-public",
    "kube-node-lease",
)

# Workloads allowed to schedule onto PD-only nodes besides DaemonSets: the
# PD workloads themselves. They tolerate the pd-only taint deliberately and
# pin themselves to PD nodes via required affinity. Extend this set if a new
# PD-family workload is introduced.
ALLOWED_PD_WORKLOADS = {
    ("statefulset", "pingdirectory", "ping-cloud"),
    ("statefulset", "pingdirectoryproxy", "ping-cloud"),
    # The PingDirectory backup Job, applied on demand by the
    # pingdirectory-periodic-backup CronJob's script: it tolerates pd-only
    # and pins itself (podAffinity) to the PD pod's node so it can mount the
    # PD data PVC. Jobs may also carry a run-id suffix, hence prefix match.
    # The CronJob itself is deliberately NOT allowlisted: it has no PD
    # tolerations and runs on default nodes; if it ever grows a pd-only
    # toleration, this test should flag it.
    ("job", "pingdirectory-backup", "ping-cloud"),
}


class TestPdOnlyTaintContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kube = K8sUtils()
        cls.pd_taints, cls.pd_labels = cls._discover_pd_pool_spec()
        if not cls.pd_taints and not cls.pd_labels:
            # No karpenter PD pool: fall back to the module constants.
            cls.pd_taints = [
                {
                    "key": PD_TAINT_KEY,
                    "value": PD_TAINT_VALUE,
                    "effect": PD_TAINT_EFFECT,
                }
            ]
            cls.pd_labels = {PD_NODE_LABEL: PD_TAINT_VALUE}
        cls.pd_node_names = {
            node.metadata.name
            for node in cls.kube.core_client.list_node().items
            if any(
                taint.key == t["key"]
                and (taint.value or "") == (t.get("value") or "")
                and taint.effect == t["effect"]
                for taint in node.spec.taints or []
                for t in cls.pd_taints
            )
        }
        cls.pd_taint_summary = ", ".join(
            f"{t['key']}={t.get('value')}:{t['effect']}" for t in cls.pd_taints
        )

    @staticmethod
    def _discover_pd_pool_spec():
        """Read taints/labels from the karpenter `pd-only` NodePool.

        Returns (taints, labels) as plain dicts; ([], {}) when karpenter is
        absent, unreadable, or has no pool by that name - callers fall back
        to the module constants.
        """
        try:
            api_client = K8sUtils().core_client.api_client
            pools = []
            for version in ("v1", "v1beta1"):
                try:
                    response, _, _ = api_client.call_api(
                        f"/apis/karpenter.sh/{version}/nodepools",
                        "GET",
                        auth_settings=["BearerToken"],
                        response_type="object",
                        _preload_content=False,
                    )
                    pools = json.loads(response.data).get("items", [])
                    break  # API group exists; use this version's objects
                except k8s.client.exceptions.ApiException as e:
                    if e.status == 404:
                        continue  # API version absent; try the next
                    break
            for pool in pools:
                if pool.get("metadata", {}).get("name") != PD_POOL_NAME:
                    continue
                tmpl = pool.get("spec", {}).get("template", {})
                taints = [
                    {
                        "key": t.get("key"),
                        "value": t.get("value") or "",
                        "effect": t.get("effect"),
                    }
                    for t in (tmpl.get("spec", {}).get("taints") or [])
                ]
                labels = dict(tmpl.get("metadata", {}).get("labels") or {})
                return taints, labels
        except Exception:
            pass  # discovery unavailable; fall back to constants
        return [], {}

    def test_pd_only_taint_present(self):
        """At least one node carries a discovered PD-only taint."""
        if not self.pd_taints:
            self.skipTest(
                "pd-only NodePool declares no taints; label-only contract"
            )
        self.assertTrue(
            self.pd_node_names,
            f"no node carries any PD-only taint ({self.pd_taint_summary}); "
            "if the PD node pool taint was removed, update this test",
        )

    def test_no_deployment_schedules_onto_pd_nodes(self):
        """No Deployment may schedule or opt in to PD-only nodes."""
        self._assert_pd_contract("deployment")

    def test_no_statefulset_schedules_onto_pd_nodes(self):
        """No StatefulSet may schedule or opt in to PD-only nodes."""
        self._assert_pd_contract("statefulset")

    def test_no_cronjob_schedules_onto_pd_nodes(self):
        """No CronJob may schedule or opt in to PD-only nodes."""
        self._assert_pd_contract("cronjob")

    def test_no_job_schedules_onto_pd_nodes(self):
        """No Job may schedule or opt in to PD-only nodes."""
        self._assert_pd_contract("job")

    def _assert_pd_contract(self, kind: str):
        """Scan every non-exempt namespace's workloads of `kind`.

        Flags any non-allowlisted workload whose pod template matches a
        PD-only taint via a toleration, selects a PD-only node label via
        nodeSelector or required nodeAffinity, or sets an explicit nodeName
        on a PD node.
        """
        if kind == "deployment":
            workloads = self.kube.app_client.list_deployment_for_all_namespaces().items
        elif kind == "statefulset":
            workloads = self.kube.app_client.list_stateful_set_for_all_namespaces().items
        elif kind == "cronjob":
            workloads = self.kube.batch_client.list_cron_job_for_all_namespaces().items
        elif kind == "job":
            workloads = self.kube.batch_client.list_job_for_all_namespaces().items
        else:
            raise ValueError(f"Unsupported workload kind '{kind}'")

        checked = 0
        for wl in workloads:
            ns = wl.metadata.namespace
            if ns in EXCLUDED_NAMESPACES:
                continue
            name = wl.metadata.name
            if kind not in ("cronjob", "job"):
                # CronJobs/Jobs are scanned best-effort: an empty list is
                # normal on many clusters, so no coverage guard below.
                checked += 1
            if self._is_allowed_pd_workload(kind, name, ns):
                continue
            pod_spec = (
                wl.spec.job_template.spec.template.spec
                if kind == "cronjob"
                else wl.spec.template.spec
            )

            violations = []
            for toleration in pod_spec.tolerations or []:
                if self._toleration_matches_pd_taint(toleration):
                    violations.append(
                        f"toleration matches a PD-only taint "
                        f"({self.pd_taint_summary}) via "
                        f"key={toleration.key or '<none>'!r}, "
                        f"operator={toleration.operator!r}"
                    )
                    break
            if self._pinned_to_pd_nodes(pod_spec):
                violations.append(
                    "nodeSelector/affinity selects a PD-only node label "
                    f"({', '.join(sorted(self.pd_labels)) or 'none'})"
                )
            if pod_spec.node_name and pod_spec.node_name in self.pd_node_names:
                violations.append(
                    f"explicit nodeName '{pod_spec.node_name}' is a PD node"
                )

            if violations:
                self.fail(
                    f"{kind}/{ns}/{name} can schedule onto PD-only nodes: "
                    + "; ".join(violations)
                    + ". Non-DaemonSet workloads must not tolerate the "
                    "PD-only taints or select PD-only node labels (see "
                    "PDO-12087). If this workload is a legitimate PD "
                    "workload, add it to ALLOWED_PD_WORKLOADS."
                )

        if kind not in ("cronjob", "job"):
            # The scan must have seen workloads, else the contract was never
            # exercised (e.g. wrong cluster context).
            self.assertGreater(
                checked,
                0,
                f"no {kind} workloads found outside {EXCLUDED_NAMESPACES}; "
                "is the test pointed at a P1AS cluster?",
            )

    def _toleration_matches_pd_taint(self, toleration) -> bool:
        """True if the toleration matches any discovered PD-only taint.

        Kubernetes matching: the effect must match (empty matches all), and
        either the key matches with a compatible operator, or the key is
        empty with operator Exists (matches every taint of that effect).
        """
        for t in self.pd_taints:
            if getattr(toleration, "effect", None) not in (
                None,
                "",
                t["effect"],
            ):
                continue
            key = getattr(toleration, "key", None)
            operator = getattr(toleration, "operator", None)
            if not key:
                # A keyless toleration only matches when operator is Exists,
                # which matches every taint of the (matched) effect.
                if operator == "Exists":
                    return True
                continue
            if key != t["key"]:
                continue
            if operator == "Exists":
                return True  # matches this taint with any value
            if operator == "Equal":
                # Defaults to Equal in the API; empty operator reads as None.
                if (getattr(toleration, "value", None) or "") == t.get("value"):
                    return True
        return False

    def _pinned_to_pd_nodes(self, pod_spec) -> bool:
        """True if the pod spec pins scheduling to PD-only node labels."""
        selector = pod_spec.node_selector or {}
        for label_key, label_value in self.pd_labels.items():
            if selector.get(label_key) == label_value:
                return True
        affinity = pod_spec.affinity
        node_affinity = getattr(affinity, "node_affinity", None) if affinity else None
        required = (
            getattr(
                node_affinity,
                "required_during_scheduling_ignored_during_execution",
                None,
            )
            if node_affinity
            else None
        )
        # Preferred-only affinity does not pin; only required terms do.
        terms = required.node_selector_terms if required else []
        return any(self._term_selects_pd_nodes(term) for term in terms)

    def _term_selects_pd_nodes(self, term) -> bool:
        """True if a NodeSelectorTerm requires a PD-only node label."""
        for expr in term.match_expressions or []:
            for label_key, label_value in self.pd_labels.items():
                if expr.key != label_key:
                    continue
                if expr.operator == "In" and label_value in (expr.values or []):
                    return True
                if expr.operator == "Exists":
                    return True  # label present, any value
        for field in term.match_fields or []:
            for label_key, label_value in self.pd_labels.items():
                if field.key == f"metadata.labels['{label_key}']" and (
                    label_value in (field.values or [])
                ):
                    return True
        return False

    @staticmethod
    def _is_allowed_pd_workload(kind: str, name: str, ns: str) -> bool:
        """True if the workload is allowlisted as a legitimate PD workload.

        Jobs created on demand (e.g. pingdirectory-backup-<run-id>) carry a
        generated suffix, so Jobs match on name prefix.
        """
        if kind == "job":
            return any(
                k == "job" and n == ns and name.startswith(w)
                for k, w, n in ALLOWED_PD_WORKLOADS
            )
        return (kind, name, ns) in ALLOWED_PD_WORKLOADS


if __name__ == "__main__":
    unittest.main(verbosity=2)
