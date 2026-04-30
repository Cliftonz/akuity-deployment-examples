# Argo CD Application Health = Degraded

**Severity:** sev2.

**Trigger:** Application health has been `Degraded` for 120+ seconds.

## Symptoms

- Sync succeeded (status `Synced`) but health check reports `Degraded`.
- Argo CD UI shows the Application in yellow/red on the Health column.
- Slack got the `on-health-degraded` notification.

## Diagnosis

```bash
# 1. Pull the message from health.lua / built-in health checks.
kubectl -n argocd get application <app> -o jsonpath='{.status.health.message}'

# 2. List the resources Argo CD reports as unhealthy.
kubectl -n argocd get application <app> -o jsonpath='{range .status.resources[?(@.health.status!="Healthy")]}{.kind}/{.name}: {.health.message}{"\n"}{end}'

# 3. Drill into the unhealthy resource.
kubectl -n <ns> describe <kind> <name>
```

## Most common causes

1. **Deployment has progressed but pods are not ready.** New ReplicaSet's pods are stuck `Pending` or `CrashLoopBackOff`. → cross-reference with `pod-health-issues.md`.
2. **Service has no Endpoints.** Selector typo or pods not matching. → `kubectl get endpoints <svc>` returns empty.
3. **PVC stuck Pending.** Storage class not provisioning. → `kubectl describe pvc` shows the provisioning error.
4. **HPA can't scale.** Metrics server unavailable, or pods don't have resource requests. → `kubectl get hpa` shows `<unknown>` in current/target.

## Remediation

Cause-specific. The recovery escape hatch is the same as a sync failure: revert the env-branch commit so Argo CD applies the previous (healthy) revision while the bad one is triaged.

```bash
git checkout env/<env>
git revert HEAD
git push origin env/<env>
```

## Verification

- Argo CD Application returns to `Health = Healthy`.
- Autoclose: condition `status.health.status == 'Healthy'` holds for 5 minutes.

## What this looks like at higher tiers

Tier 3 adds Crossplane composite-resource health surfaced in Argo CD via `resource-customizations` (so a stuck XDatabase claim triggers this runbook directly). Tier 4 distinguishes "degraded in one region" from "degraded everywhere" via per-region Application metrics.
