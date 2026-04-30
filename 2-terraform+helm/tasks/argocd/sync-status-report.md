# Weekly Argo CD sync-status report

**Audience:** Founders (CTO/SRE).

**What it produces:** A Monday-morning Slack digest of the past week's Argo CD activity on the single tier-0 cluster. Surfaces failures the founders missed in the noise.

## Sections

1. **Apps currently OutOfSync or Degraded.** Application name, last-sync time, last-sync status. If empty, the report says "all green."
2. **Sync failures in the past 7 days.** Application name, error excerpt, count.
3. **Promotions completed.** Kargo Stages that moved freight: dev → staging, staging → prod. Count plus the image tag/digest promoted.

## Data sources

- Argo CD API: `applications.argoproj.io` resources on the cluster
- Kargo API: `freight.kargo.akuity.io`, `stages.kargo.akuity.io`

## Why this matters at tier 0

Tier-0 customers don't yet have monitoring dashboards. Akuity Intelligence runs this on their behalf so they don't need to remember to check the Argo CD UI. If something has been silently broken for three days, the Monday-morning digest catches it.

## Sample output

```
Akuity weekly status — 2026-04-29

✅ All 3 Applications synced & healthy
🚀 2 promotions completed: guestbook v0.0.7 → dev → staging → prod

Quiet week. 0 sync failures. 0 health regressions.
```
