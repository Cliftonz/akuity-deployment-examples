# Fleet-wide weekly incident summary

**Audience:** Platform team management + executive leadership.

**What it produces:** A Monday-morning aggregate of every incident across every regional cluster in the past week. Surfaces region-specific patterns the per-cluster reports miss.

## Why this matters at tier 4

Tier-4 customers run a fleet of fleets. Each region has its own dashboards, its own on-call, its own incident channel. The weekly fleet view is the *only* place anyone gets a cross-region picture.

Common patterns this report surfaces:
- One region consistently has more sev1s than the others → cluster-lifecycle quality issue or regional-provider quality issue.
- A specific Tuesday has spikes across all regions → upstream change (Akuity Intelligence, Argo CD upstream, cloud provider event).
- Promotion-failure rate by region → one region's environment is more brittle than the others.

## Sections

1. **Incident counts.** Per region, by severity. Plus week-over-week delta.
2. **Top 5 incidents by total time-to-resolve.** Across all regions.
3. **Region health score.** Synthetic 0–100 score combining incident count, MTTR, and Akuity Intelligence's confidence in claim health.
4. **Newly-introduced runbooks.** Runbooks added in the past 7 days — useful for the on-call team to read before they're paged on a new incident class.
5. **Pages that bypassed runbooks.** Incidents that were paged but didn't match any registered runbook trigger. These are gaps.

## Data sources

- Akuity Audit Logs (fleet-wide stream from tier 4's `audit-log-fleet-export.yaml`).
- Akuity Intelligence incident records.
- Per-cluster Prometheus → Thanos federation (deployed at tier 4 as `platform/thanos/`).

## Sample output

```
Akuity weekly fleet incident summary — 2026-04-29

📊 Incidents by region (last 7d):
  us-east:        sev1: 0  sev2: 3  sev3: 11   (last week: 0/2/9)
  eu-west:        sev1: 1  sev2: 5  sev3: 14   (last week: 0/4/12)
  ap-southeast:   sev1: 0  sev2: 1  sev3: 4    (last week: 0/0/3)

🔥 Top 5 by time-to-resolve:
  1. eu-west / payments-prod / claim-stuck    →  4h 12m
  2. eu-west / orders-prod / app-degraded     →  2h 47m
  3. us-east / guestbook-prod / sync-failure  →  1h 31m
  4. eu-west / orders-prod / pvc-binding      →  1h 18m
  5. ap-southeast / guestbook-prod / app-deg  →     58m

🆕 Runbooks added this week: 2
  - runbooks/networking/cni-networking.md (us-east, 1 page handled)
  - runbooks/kargo/regional-rollout-rollback.md (eu-west, 1 page handled)

❓ Unmatched pages (gap analysis): 3
  - eu-west: cert-manager rate-limit failure (no runbook)
  - ap-southeast: provider-helm controller OOM (no runbook)
  - us-east: Kargo Warehouse webhook timeout (no runbook)
```

## What's distinctive about this task

Tier 1's weekly report is "things looked OK this week." Tier 4's is "**which region is the weakest link, and why?**" The question completely changes — and Akuity Intelligence is the only product positioned to answer it because it sees every region's audit stream.
