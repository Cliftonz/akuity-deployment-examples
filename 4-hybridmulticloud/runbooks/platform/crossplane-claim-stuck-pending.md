# Crossplane XDatabase claim stuck Pending / Synced=False

**Severity:** sev1 — production app waiting on infrastructure that is not arriving.

**Trigger:** an `XDatabase` resource has been in `Pending` (or `Synced=False`) for 300+ seconds.

## Why this is the headline tier-3 incident

Tier-3 customers run claim-based self-service infrastructure. App teams file an `XDatabase` claim; Crossplane's composition pipeline expands it into managed resources. **Most tier-3 customer pages start here** — a claim that won't reach Ready blocks the app deployment that depends on the connection Secret.

The two-hop nature (claim → managed resource → actual cloud thing) makes this harder than tier-2 RDS debugging because the failure can be at any of three layers.

## Symptoms

- `kubectl get xdatabase -A` shows status `Synced=False` or `Ready=Unknown`.
- The app deployment that mounts the connection Secret is stuck `Pending` waiting for it.
- Argo CD reports the claim Application synced, but the underlying resources are unhealthy.

## Diagnosis (top-to-bottom)

```bash
# 1. Claim status conditions.
kubectl get xdatabase <name> -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}: {.message}){"\n"}{end}'

# 2. Composite-managed resources.
kubectl get xdatabase <name> -o jsonpath='{.spec.resourceRefs[*].kind}'
# For each kind in the output:
kubectl get <kind> -l crossplane.io/composite=<name> -o yaml | head -80

# 3. Provider health (the most common root cause).
kubectl get providers
# All providers should show INSTALLED=True, HEALTHY=True. Anything else is the cause.

# 4. Provider controller logs.
kubectl -n crossplane-system logs deployment/<provider-deployment> --tail=100
# e.g. provider-aws-rds, provider-helm, provider-kubernetes

# 5. EnvironmentConfig (tier-4 multi-cloud concern).
kubectl get environmentconfig -A
# Confirm the config selecting the right Composition exists and is parseable.
```

## Most common causes (tier-3 frequency order)

1. **Provider's ProviderConfig has invalid creds.** `provider-aws-rds` ProviderConfig points at a Secret that doesn't exist or contains expired creds. → recreate the Secret with current creds; provider re-reconciles.
2. **Composition function failed.** `function-patch-and-transform` errored on a missing patch source (e.g. claim's `spec.networkRef` is nil but the composition assumes it). → fix the composition or fix the claim.
3. **Cloud-side quota.** AWS RDS instance limit hit. → claim sits in `Pending` until quota frees. Bump quota.
4. **Two providers fighting.** `provider-helm` and `provider-kubernetes` both manage the same resource (rare; usually a Composition mistake). → one of them gets `crossplane.io/external-name` and the other should be removed from the pipeline.
5. **EnvironmentConfig missing or mis-labeled.** Tier-4-specific. The seed cluster's EnvironmentConfig declares `provider: aws` but the claim's compositionSelector matches `provider: gcp`. → fix the claim's selector or the EnvironmentConfig labels.

## Remediation

Cause-specific. The fastest *recovery* is rarely useful here — Crossplane's reconciliation loop is the path; force-deleting the claim usually leaks the cloud resources.

The pattern that works:
1. Identify the failing layer (claim / managed-resource / actual cloud thing).
2. Fix the layer's input (provider creds, composition patch, claim spec).
3. Wait for Crossplane to reconcile (1–5 minutes typically).
4. Confirm the connection Secret arrives in the app namespace; the app will then deploy.

If the claim must be torn down completely:
```bash
# Use --cascade=foreground so managed resources are cleaned up too.
kubectl delete xdatabase <name> --cascade=foreground
# Wait for cleanup before re-applying the claim.
```

## Verification

```bash
kubectl get xdatabase <name> -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Returns "True".

# The connection Secret should be in the app namespace within 30 seconds.
kubectl -n <app-ns> get secret <name>-postgres
```

Autoclose: condition `status.conditions[?(@.type=='Ready')].status == 'True'` holds for 5 minutes; Akuity Intelligence closes the incident.

## What this looks like at higher tiers

Tier 4 extends this with regional dimensions — a claim stuck in `eu-west` doesn't necessarily mean the abstraction is broken; the regional seed's EnvironmentConfig might be wrong while `us-east` is fine. The tier-4 version of this runbook starts with "which seed cluster is the claim landing on?"
