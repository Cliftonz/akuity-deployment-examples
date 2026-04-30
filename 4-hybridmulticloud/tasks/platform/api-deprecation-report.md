# Deprecated Kubernetes API usage

**Audience:** Platform team.

**What it produces:** A monthly report listing every chart, ApplicationSet, or rendered manifest in any env branch that uses an API version Kubernetes has deprecated. Catches "the next minor version upgrade is going to break us" months before the upgrade, not the day of.

## Why this matters at tier 3

Tier 3 customers run multiple clusters across multiple cloud accounts. Cluster lifecycle is often managed by a separate team (or product, like Cluster API or Kubermatic). When the platform team kicks off a Kubernetes minor upgrade, the cluster team rolls forward and the platform team finds out three weeks later that one of their charts referenced `policy/v1beta1` and is silently broken in `prod-eu-west`.

This task is the early warning. It reads:

1. Every chart in `framework/composites/`, `1-helm/charts/`, `3-crossplane+helm/charts/`.
2. Every rendered manifest on every `env/<stage>` branch.
3. Cross-references against the Kubernetes API deprecation table (built into the `pluto` tool).

## Sample output

```
Akuity API-deprecation report — 2026-04-01

🚨 Removed in v1.30 (Kubernetes 1.30 is GA — these break NOW):
  (none)

⚠️ Deprecated, removed in next minor:
  - 3-crossplane+helm/charts/guestbook/templates/pdb.yaml
    uses policy/v1beta1 PodDisruptionBudget
    → migrate to policy/v1 (no field changes required)

ℹ️ Deprecated, removed in 2 minors:
  - framework/platform/compositions/database-aws.cue
    HelmRelease references helm.crossplane.io/v1beta1
    → upstream provider-helm v0.20+ exposes /v1beta2

✅ All other manifests use current API versions.
```

## Data sources

- `kubectl api-resources --verbs=list -o name`: live API surface
- `pluto detect-files`: lints helm charts + raw YAML against the deprecation table
- env-branch git refs: `git ls-remote origin 'env/*'` then `pluto detect-files <env-branch-tree>`

## What this looks like at higher tiers

Tier 4 extends this report to span every regional cluster's actually-deployed version (because regions can lag the upgrade cadence). The tier-4 version of this task ranks deprecations by *highest cluster version they survive*, so the platform team knows which regions to upgrade first.
