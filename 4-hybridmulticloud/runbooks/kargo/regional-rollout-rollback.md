# One regional prod stage went red mid-promotion

**Severity:** sev1 — production traffic in one region is degraded; other regions are fine.

**Trigger:** a Kargo Stage matching `prod-*` reports `Failed` for 60+ seconds during promotion.

## Why this is the headline tier-4 incident

Tier 4 promotes to three regions on independent gates. The defining failure mode is **partial rollout**: us-east promoted clean, eu-west's promotion failed half-way (some pods on the new revision, some on the old). The fleet is now inconsistent.

The runbook's job is to make the **decision tree** explicit: roll forward or roll back, and per-region (don't touch the regions that succeeded).

## Symptoms

- Kargo UI shows one of `prod-us-east`, `prod-eu-west`, `prod-ap-southeast` red.
- Argo CD reports the affected region's Application as `Degraded` or `OutOfSync`.
- The other two regions are `Healthy`.
- Notifications fired into `#deploys` for the failed region.

## Diagnosis

```bash
# 1. Which region failed?
kubectl -n kargo-simple get stages -l 'kargo.akuity.io/project=kargo-simple' \
  -o custom-columns=NAME:.metadata.name,LAST:.status.lastPromotion.phase,FREIGHT:.status.lastPromotion.freight

# 2. Why did the promotion fail? Pull the step that errored.
kubectl -n kargo-simple get stage prod-eu-west -o jsonpath='{.status.lastPromotion.steps}' | jq

# 3. Confirm the other regions are healthy.
kubectl -n kargo-simple get stages prod-us-east prod-ap-southeast \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.status.lastPromotion.phase}{"\n"}{end}'
```

## Decision tree

```
Did the failed region's Argo CD Application reach Synced=True before crashing?
├── YES — bytes landed, app is unhealthy
│   ├── Health regression localized to this region?    → roll forward (debug + hotfix)
│   ├── Health regression caused by region-specific
│   │   thing (data residency, regional dep)?           → roll back THIS region only
│   └── Health regression matches all 3 regions
│       (somehow only this one tripped)?                → roll back ALL regions, treat as bad freight
└── NO — render or push step failed, bytes never landed
    └── Re-run the Kargo promotion (idempotent — env branch will skip if already current)
```

## Remediation: roll back ONE region only

The whole point of independent regional gates is that you can roll back one without touching the others.

```bash
# 1. Find the previous good commit on the affected region's env branch.
git log --oneline origin/env/prod-eu-west | head -5

# 2. Revert to that commit.
git checkout env/prod-eu-west
git revert <bad-sha>
git push origin env/prod-eu-west

# 3. Argo CD reconciles within ~30s. Verify health on this region only:
kubectl --context=seed-eu-west -n guestbook-prod get pods
```

The other regions' Stages and env branches are untouched.

## Remediation: roll forward (when the bad freight has reached all regions)

If the bug is global and one region just hit it first:

```bash
# Promote the previous good freight to all three prod stages.
# Find the prior freight ID:
kubectl -n kargo-simple get freight -o custom-columns=NAME:.metadata.name,ALIAS:.alias,CREATED:.metadata.creationTimestamp

# Re-promote it:
for region in prod-us-east prod-eu-west prod-ap-southeast; do
  kubectl -n kargo-simple annotate stage "$region" \
    "kargo.akuity.io/promote=<freight-id>" --overwrite
done
```

## Verification

- The affected region's Argo CD Application is `Healthy`.
- The other regions are still `Healthy` (you did not regress them).
- Kargo's affected Stage's `lastPromotion.phase` is `Succeeded`.

## What this looks like at lower tiers

Tier 0–3 have one prod stage. The whole "roll back one region only" calculus does not exist. This is the runbook that genuinely only matters at tier 4 — and it's why per-region promotion gates are the load-bearing tier-4 design choice.
