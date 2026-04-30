# Helm value `database.secretName` drifted from Terraform output

**Severity:** sev1 — production app cannot start.

**Trigger:** Pod in `CreateContainerConfigError` with reason containing `secret "guestbook-postgres-...":` not found.

## Why this is the headline tier-2 incident

Tier 2's whole point is the **wild west** between GitOps and Terraform-managed infrastructure. The Helm chart's `envFrom: secretRef.name` references a Kubernetes Secret created by `terraform apply` — outside Argo CD's view, outside Kargo's freight machinery, outside any PR review process.

When the two values drift (someone renames the chart's `database.secretName`, or someone re-runs Terraform with a different `var.secret_name`), the deployment crashes with no clear error pointing at the seam. This runbook is the seam.

## Symptoms

- Pod in `CreateContainerConfigError`.
- `kubectl describe pod` shows: `Error: secret "guestbook-postgres-<env>" not found` (or whatever the chart's value is).
- Argo CD reports the chart's manifests applied successfully, but the Pod cannot start.

## Diagnosis

```bash
# 1. What does the chart think the Secret is named?
kubectl -n <ns> get deployment guestbook -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].secretRef.name}'

# 2. Does that Secret exist?
kubectl -n <ns> get secret <name>

# 3. What Secrets DO exist in the namespace?
kubectl -n <ns> get secrets

# 4. What did Terraform create? (Run from the operator's machine — this is
#    NOT in any GitOps loop.)
cd 2-terraform+helm/terraform/postgres
terraform output secret_name
```

## Most common causes

1. **Helm value changed but Terraform didn't run.** Someone bumped `database.secretName` in `env/values-prod.yaml`; Argo CD applied the new chart pointing at a Secret that doesn't exist. → either revert the values change OR re-run Terraform with a matching `var.secret_name`.
2. **Terraform variable changed but Helm didn't.** Team re-ran `terraform apply` with `var.secret_name=guestbook-pg-<env>` (renamed); the chart still references the old name. → align them, then re-promote the chart.
3. **Terraform applied to the wrong namespace.** `var.namespace` was set to `guestbook-staging` instead of `guestbook-prod`. Secret exists, just not where the deployment expects. → re-apply Terraform with the right namespace.

## Remediation

The fastest recovery is to bring the chart's expectation back in line with what's actually in the cluster:

```bash
# Find the actual Secret.
ACTUAL=$(kubectl -n guestbook-prod get secret -l app=guestbook -o jsonpath='{.items[0].metadata.name}')

# Edit the chart values to match.
# 2-terraform+helm/env/values-prod.yaml: database.secretName: <ACTUAL>

# Commit, push, let Kargo re-promote.
git commit -am "fix: align database.secretName with terraform output"
git push
```

For permanent fix: agree on a naming convention between the platform team (who runs Terraform) and the teams (who edit Helm values) and put it in a CONTRIBUTING.md. **This is the brittle process tier 3 fixes by handing the abstraction to Crossplane.**

## Verification

```bash
kubectl -n <ns> rollout restart deployment guestbook
kubectl -n <ns> get pods -w
# Pod transitions Pending → ContainerCreating → Running.
```

## What this looks like at higher tiers

**This runbook does not exist at tier 3+.** The Crossplane XDatabase Composition produces the connection Secret in the same namespace as the consuming chart, with a deterministic name driven by the claim's `spec.name`. The whole class of "Helm and Terraform got out of sync" failure is gone.
