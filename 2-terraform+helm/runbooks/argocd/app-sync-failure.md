# Argo CD Application sync failed

**Severity:** sev2 — production traffic still served by the previous revision; new changes blocked.

**Trigger:** an Argo CD Application has reported `Sync = Failed` for 60+ seconds.

## Symptoms

- Argo CD UI shows the Application in red with sync status `Failed`.
- The Slack channel just received the `on-sync-failed` notification (see argocd-notifications-cm).

## Diagnosis

```bash
# 1. Get the failure reason directly from the Application status.
kubectl -n argocd get application <app> -o jsonpath='{.status.operationState.message}'

# 2. Inspect failed resources.
kubectl -n argocd get application <app> -o jsonpath='{range .status.operationState.syncResult.resources[?(@.status=="Failed")]}{.kind}/{.name}: {.message}{"\n"}{end}'

# 3. If the failure is "ServerSideApply", check for field-manager conflicts.
kubectl -n <target-namespace> get <resource> <name> -o yaml | grep -A3 managedFields
```

## Most common causes (tier-0 frequency order)

1. **Image tag does not exist.** Kargo wrote a digest the registry rejects (rare on GHCR, common when ECR repos lag). → re-tag and re-push, or revert the env-branch commit.
2. **NetworkPolicy blocks something the new revision needs.** A new chart version added a sidecar that needs egress the policy doesn't allow. → check the rendered NetworkPolicy on the env branch vs. the previous commit.
3. **Namespace not provisioned.** AppProject `clusterResourceWhitelist` is missing the kind. → add the kind to the AppProject (rare on tier 0; the projects already whitelist Namespace).

## Remediation

**If the bad change came from a recent promotion:** revert the env-branch commit.

```bash
# Find the commit on the env branch.
git log --oneline -3 origin/env/<env>

# Revert it. Argo CD will re-sync to the previous revision.
git checkout env/<env>
git revert <bad-sha>
git push origin env/<env>
```

**If the bad change came from a chart edit on main:** the env branch hasn't been re-rendered yet. Force a Kargo re-promotion of the previous freight, or roll forward with a fixed chart.

## Verification

- Argo CD Application returns to `Sync = Synced, Health = Healthy`.
- The autoclose condition (`status.sync.status == 'Synced'`) holds for 5 minutes; Akuity Intelligence closes the incident automatically.

## What this looks like at higher tiers

Tier 1 adds an AnalysisRun that fails freight before Argo CD ever applies it; tier 3 adds a Crossplane claim health gate; tier 4 adds region-aware routing so a sync failure in `us-east` does not block `eu-west` rollouts.
