# Over-provisioned workloads (CPU/memory)

**Audience:** Platform team + finance.

**What it produces:** A weekly report ranking workloads by gap between `requests` and actual sustained usage. Lists the top 20 highest-cost over-provisioned Deployments / StatefulSets across the cluster.

## Why this matters at tier 3

Tier-3 customers have hundreds to thousands of workloads, mostly self-served by app teams who copy-paste resource requests from a sibling chart. The cumulative over-provision wastes 20–60% of cluster spend in real production fleets.

This task surfaces it without being scary — it's a Slack post, not a bill. The platform team uses it to start tuning conversations with team leads, who usually agree to drop requests once they see their app uses 8% of what it asks for.

## Sections

1. **Top 20 by absolute waste.** Workload, current `requests`, P95 actual usage over 7 days, gap (cores × $/core × 730 hours).
2. **Top 5 most-over-provisioned (by ratio).** Workloads using <10% of their requests. These are the easiest wins.
3. **Trend.** 4-week rolling average of total cluster waste. Going up = new charts shipping with sloppy defaults.

## Data sources

- Prometheus (deployed at tier 1 as kube-prometheus-stack): `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`
- Kubernetes API: `Deployment.spec.template.spec.containers[*].resources.requests`
- Cluster cost rate (configured in the Akuity Intelligence task settings): $0.04/core-hour by default

## Sample output

```
Akuity over-provisioned workloads — 2026-04-29

💸 Top 5 by waste (weekly):
  1. analytics/etl-runner          requests 8 cores → P95 0.6  → $235/wk
  2. payments/legacy-bridge        requests 4 cores → P95 0.3  → $109/wk
  3. guestbook-prod/guestbook      requests 2 cores → P95 0.1  → $55/wk
  4. orders-prod/orders            requests 4 cores → P95 0.4  → $105/wk
  5. ingest-prod/kafka-consumer    requests 6 cores → P95 1.2  → $140/wk

📉 4-week trend: $720/wk → $844/wk (+17%)
```

## What this looks like at higher tiers

Tier 4 extends with per-region cost attribution and reserved-capacity awareness — over-provision in a region with reserved capacity is "free", over-provision in a burst region is real spend.
