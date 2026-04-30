# Akuity-managed control-plane resources (tier 4)

Tier 4 expands the Akuity org-level configuration to fan across three regions.

| File | Purpose |
|---|---|
| `audit-log-fleet-export.yaml` | Per-region audit-log streams + a fleet-wide aggregator. The aggregator is what the weekly-incident-summary task queries. |

The single most powerful tier-4 demo motion: open the Akuity console, point at the aggregator destination, and show the SE prospect a single audit query that returns events from every region in the past week. Tier 1's single SIEM destination cannot do this.

## How these get applied

Same as tier 1's `akuity/`: via the Akuity console / API, NOT via Argo CD.

```bash
akuity org streaming-destination apply -f audit-log-fleet-export.yaml
```

The four destinations get created in the Akuity org. Each regional Akuity Cluster registration carries the `region: <name>` label, which Akuity adds to every event before forwarding through the streaming destinations.

## Per-region tokens

Each regional destination has its own SIEM token (eu-west's SIEM is in-region for data-residency reasons). Provision via ESO from the corporate secret store, one ExternalSecret per token.
