# Pod CrashLoopBackOff

**Severity:** sev2.

**Trigger:** a Pod has been in `CrashLoopBackOff` for 180+ seconds.

## Symptoms

- `kubectl get pods` shows status `CrashLoopBackOff` and a non-zero `RESTARTS` count climbing.
- Argo CD Application reports `Health = Degraded`.

## Diagnosis

```bash
# 1. Get the most recent crash output.
kubectl -n <ns> logs <pod> --previous --tail=100

# 2. If there is no previous output (the container failed before logging),
#    inspect the events.
kubectl -n <ns> describe pod <pod> | grep -A20 Events:

# 3. Check resource limits — OOM kills are silent at the application level.
kubectl -n <ns> get pod <pod> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'
```

## Most common causes (tier-0 frequency order)

1. **OOMKilled.** The container hit its memory limit. `lastState.terminated.reason: OOMKilled`. → bump `resources.limits.memory` in the chart's `values-<env>.yaml`, re-promote.
2. **Failed readiness/liveness probe.** New revision changed the probe path or port. → check `kubectl -n <ns> describe pod` for "Liveness probe failed" lines; reconcile the chart's probe config with what the app actually serves.
3. **Missing config / Secret.** The container needs `DATABASE_URL` (or similar) and the Secret was renamed. → confirm the Secret exists in the namespace and the Deployment's `envFrom` references the right name.
4. **Image is broken.** The new image has a real bug. → roll forward with a fixed image, or revert the env-branch commit.

## Remediation

The fix depends on the cause from above. The fastest *recovery* (regardless of cause) is to revert the env-branch commit and let Argo CD pull the previous revision back:

```bash
git checkout env/<env>
git revert HEAD
git push origin env/<env>
# Argo CD reconciles within ~30 seconds.
```

Then triage the bad revision off-business-hours.

## Verification

```bash
kubectl -n <ns> get pods
# RESTARTS column stops climbing; pods reach Running, Ready 1/1.
```

## What this looks like at higher tiers

Tier 1 adds a Kargo `verification.analysisTemplate` (HTTP probe) so freight that crashes the new pod never gets eligible for promotion to staging. Tier 3 adds an `over-provisioned-workloads-report` task that catches the inverse problem — pods that never crash but burn cluster budget.
