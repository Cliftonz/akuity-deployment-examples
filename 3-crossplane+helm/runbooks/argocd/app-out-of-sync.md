# Argo CD Application stuck OutOfSync

**Severity:** sev3 — production traffic still served by the previous revision; new changes blocked but no incident yet.

**Trigger:** Application has been `OutOfSync` for 600+ seconds.

## Symptoms

- Argo CD UI shows the Application yellow on the Sync column.
- A change was committed to git but Argo CD has not applied it.
- AutoSync is enabled but the Application reports a sync error or is not attempting.

## Diagnosis

```bash
# 1. What does Argo CD think is different?
kubectl -n argocd get application <app> -o jsonpath='{.status.sync}'

# 2. List drifted resources.
argocd app diff <app>
# (or kubectl-based equivalent if argocd CLI is unavailable)

# 3. Is autoSync enabled? Are there sync windows blocking?
kubectl -n argocd get application <app> -o jsonpath='{.spec.syncPolicy}'
kubectl -n argocd get appproject <project> -o jsonpath='{.spec.syncWindows}'
```

## Most common causes (tier-1 frequency order)

1. **Sync window in effect.** AppProject `syncWindows` includes a `kind: deny` window. Tier 1's platform.yaml defines a Friday 22:00 → Monday 10:00 freeze; OutOfSync over the weekend is expected. → wait for the window to lift, or break-glass via `manualSync: true`.
2. **AutoSync disabled on this Application.** Someone set `syncPolicy.automated: null` to halt deploys during a triage. → re-enable when triage is done; until then, manual syncs only.
3. **Drift introduced by a hand-edit.** Someone `kubectl apply`'d directly to the cluster. Argo CD compares against git and reports the difference. → revert the cluster change OR commit the change to git.
4. **ServerSideApply field-manager conflict.** Another controller wrote a field Argo CD wants to control. → narrow the chart's spec or grant the other controller priority via `managedFields` annotations.

## Remediation

```bash
# Manual sync (respects sync windows).
argocd app sync <app>

# Force sync (breaks glass on a sync window — only on real incidents).
argocd app sync <app> --force
```

If the OutOfSync is caused by hand-edits, the first principle is **the cluster is the lie, git is the truth.** Either fix git to match what's in the cluster, or let Argo CD revert the cluster.

## Verification

- Argo CD Application returns to `Sync = Synced`.
- Sync history shows the latest commit applied.

## What this looks like at higher tiers

Tier 3 adds Argo CD `resource.customizations.ignoreDifferences` for Crossplane managed resources (provider controllers mutate fields Argo CD shouldn't fight). Tier 4 adds per-region OutOfSync handling so a stuck region doesn't block fleet-wide promotion.
