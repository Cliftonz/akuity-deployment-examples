# Tasks and runbooks

These two kinds of artifact are how **Akuity Intelligence** consumes a customer's operational knowledge — they're the difference between an Argo CD console you stare at and a GitOps control plane that proactively reports and remediates.

The user explicitly called this out as the most game-changing differentiator on the bonus list. Every tier in this repo ships its own tasks/ and runbooks/ directories with tier-appropriate scope.

## What each kind is

**Tasks** are scheduled, recurring reports. They run on a cron, gather data from the Argo CD / Kargo / Kubernetes API, and post the result to a Slack channel (or, more generally, to a `deliverTo` sink). Examples:

- Weekly Argo CD sync-failure summary
- Quarterly platform integrity report (deprecated APIs, over-provisioned workloads)
- Monthly image-vulnerability scan summary

**Runbooks** are event-triggered playbooks. They watch for a specific resource state (a Pod stuck in `ImagePullBackOff`, an Argo CD Application `OutOfSync`, a Crossplane claim with `Synced=False`) and surface the remediation steps to whoever's on-call. Examples:

- Pod stuck in `ImagePullBackOff` → check pull secret, registry credentials
- Argo CD Application `Degraded` → check controller logs, deployment events
- Crossplane claim stuck pending → check provider health, EnvironmentConfig binding

## Repo layout

```
.schemas/
  task-manifest.json                 # JSON Schema for tasks/MANIFEST.yaml
  runbook-manifest.json              # JSON Schema for runbooks/MANIFEST.yaml
scripts/
  register-intelligence.sh           # walks each tier, upserts manifests via the akuity CLI
0-kustomize/tasks/MANIFEST.yaml      # 1 task: argocd-sync-status-report
0-kustomize/runbooks/MANIFEST.yaml   # 3 runbooks: argocd sync failure, image-pull, pod health
1-helm/tasks/MANIFEST.yaml           # tier 0 + expiring-certificates
1-helm/runbooks/MANIFEST.yaml        # tier 0 + argocd app-degraded, app-out-of-sync, security/rbac-denials
2-terraform+helm/runbooks/...        # tier 1 + infra/{pvc-binding-failure, postgres-secret-name-drift}
3-crossplane+helm/tasks/...   # + platform/api-deprecation, over-provisioned-workloads, security/image-vulnerability
3-crossplane+helm/runbooks/...# + platform/crossplane-claim-stuck-pending
4-hybridmulticloud/tasks/...         # + platform/weekly-incident-summary
4-hybridmulticloud/runbooks/...      # + networking/cni-networking, kargo/regional-rollout-rollback
```

## Why every tier carries its own

Each tier corresponds to a customer profile (5-engineer SMB, mid-market with first SOC 2, enterprise with platform team, multi-region fleet). Their operational pain looks completely different:

- **Tier 0** customers don't yet need a quarterly API-deprecation report. They DO need a runbook for "guestbook didn't deploy, what now?"
- **Tier 4** customers have whole teams whose job is on-call. They need region-aware runbooks for cross-region promotion failures, plus tasks that aggregate fleet-wide compliance evidence.

Putting the same playbooks in every tier would either over-engineer tier 0 or under-equip tier 4. The progressive scope is the demo.

## How registration works

```bash
export AKUITY_API_KEY_ID=...
export AKUITY_API_KEY_SECRET=...

./scripts/register-intelligence.sh                  # all tiers
./scripts/register-intelligence.sh 1-helm           # one tier
```

The script walks each tier's `tasks/MANIFEST.yaml` and `runbooks/MANIFEST.yaml`, validates them against the schemas in `.schemas/`, and upserts them via the `akuity` CLI. If your CLI version doesn't yet expose the `intelligence` subcommand, the script prints the equivalent Akuity-console action so registration can finish by hand.

## What this looks like in a customer demo

The single most powerful demo motion: "let me show you what your on-call sees when guestbook stops deploying. Here's the runbook" — open the Argo CD console, click into the failing Application, and Akuity Intelligence has *already* posted the remediation steps into the on-call Slack channel because it matched the resource state to a registered runbook.

The runbooks aren't just docs — they're the active layer. That's why this is the headline feature.
