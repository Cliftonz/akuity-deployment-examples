# CNI / pod-network failure (regional)

**Severity:** sev1 — entire region's pods cannot communicate.

**Trigger:** any node in any regional cluster reports `NetworkUnavailable=True` for 60+ seconds.

## Why this is in the tier-4 set

CNI failures at tier 0–3 are rare and usually a single-cluster operational issue. At tier 4 the failure mode is regional — the eu-west fleet's Calico stops scheduling new pods because of a control-plane upgrade, while us-east is fine. The runbook needs to encode "is this one region or all regions" at the top.

## Symptoms

- `kubectl get nodes` (against the regional context) shows nodes with `Ready=False` or `NetworkUnavailable=True`.
- Pods on affected nodes are stuck `Pending` with events like "no IPs available."
- The Akuity ApplicationSet cluster generator stops marking apps Healthy in the affected region.

## Diagnosis

```bash
# 1. Which region is affected?
for ctx in seed-us-east seed-eu-west seed-ap-southeast; do
  echo "=== $ctx ==="
  kubectl --context="$ctx" get nodes \
    -o jsonpath='{range .items[?(@.status.conditions[?(@.type=="NetworkUnavailable")].status=="True")]}{.metadata.name}{"\n"}{end}'
done

# 2. CNI controller health (varies by CNI — Calico shown).
kubectl --context=<affected-region> -n kube-system get pods -l k8s-app=calico-node
kubectl --context=<affected-region> -n kube-system logs ds/calico-node --tail=100

# 3. IPAM exhaustion?
kubectl --context=<affected-region> -n kube-system get ippool
# Look for pools at >90% utilization.

# 4. BGP / overlay state.
calicoctl --context=<affected-region> node status
```

## Most common causes

1. **IPAM exhaustion.** Pod CIDR is too small for the cluster's actual size. → expand CIDR (cluster-lifecycle-team work) or evict idle pods.
2. **CNI controller upgrade gone wrong.** New version has a config-incompatibility. → roll back the CNI version in the cluster-lifecycle layer (Cluster API / Kubermatic).
3. **Cloud network upgrade.** AWS VPC CNI / GKE Dataplane V2 transient outage. → cloud provider page; wait for upstream resolution.
4. **Cross-region link broken.** ApplicationSet cluster generator times out reaching the affected region. Akuity's tunnel is fine; the agent-to-API connection inside the region is what failed. → check the regional load balancer / NAT health.

## Remediation

**Step 1: Stop the bleeding.** Pause the affected region's prod Kargo Stage so nothing tries to deploy into the broken region:
```bash
kubectl -n kargo-simple patch stage prod-eu-west \
  --type=merge -p '{"spec":{"requestedFreight":[]}}'
```

**Step 2: Confirm scope.** If only one region is affected, the other regions keep serving traffic.

**Step 3: Engage cluster-lifecycle team.** CNI is owned by them, not by the GitOps layer.

**Step 4: When healthy.** Re-enable the prod Stage:
```bash
kubectl -n kargo-simple patch stage prod-eu-west \
  --type=merge -p '{"spec":{"requestedFreight":[{"origin":{"kind":"Warehouse","name":"guestbook"},"sources":{"stages":["staging"]}}]}}'
```

## Verification

```bash
kubectl --context=<region> get nodes
# All Ready=True, NetworkUnavailable=False.

kubectl -n kargo-simple get stage prod-eu-west -o jsonpath='{.status.lastPromotion}'
# Latest promotion timestamps update.
```

## Why per-region escalation is the lesson

Tier-4 customers must accept that "one region is broken" is a NORMAL Monday-morning state, not an existential crisis. The fleet's job is to tolerate it. This runbook is about confirming the *other* regions are healthy and pausing only the affected one — not declaring a full-fleet incident.
