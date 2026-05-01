# Tier 4: Hybrid Multicloud

**Implementation:** see [`README.md`](README.md)

**Profile:** Many regions, often multiple cloud providers, sometimes including on-prem or edge. Latency, sovereignty, or regulatory boundaries force regional separation. The platform engineering team is now itself an organization, not a team, operating at fleet-of-fleets scale.

## The three-layer architecture

Tier 4 stacks three independent layers, top to bottom. Each owns a narrow concern; they hand off via Kubernetes-native APIs, not via custom integration. If you only learn one thing from this tier, learn this stack, every multi-region GitOps customer ends up with some version of it.

```mermaid
flowchart TB
    subgraph TLD["TLD control plane"]
        TLDGit[("Org git + policy repos")]
        TLDArgo["Akuity-managed Argo CD<br/>one instance, fleet-wide"]
        TLDKargo["Akuity-managed Kargo<br/>per-region gates"]
        TLDIntel["Akuity Intelligence<br/>fleet-wide Audit Logs"]
    end

    subgraph Regions["Always-connected regions"]
        direction LR
        subgraph USRegion["us-east"]
            SeedUS["Seed cluster<br/>Crossplane + Cluster API"]
            WorkerUS1["Worker<br/>guestbook-prod"]
            WorkerUS2["Worker<br/>orders-prod"]
            SeedUS -->|provisions| WorkerUS1
            SeedUS -->|provisions| WorkerUS2
        end
        subgraph EURegion["eu-west"]
            SeedEU["Seed cluster<br/>Crossplane + Cluster API"]
            WorkerEU1["Worker<br/>guestbook-prod"]
            WorkerEU2["Worker<br/>orders-prod"]
            SeedEU --> WorkerEU1
            SeedEU --> WorkerEU2
        end
        subgraph APRegion["ap-southeast"]
            SeedAP["Seed cluster<br/>Crossplane + Cluster API"]
            WorkerAP1["Worker<br/>guestbook-prod"]
            WorkerAP2["Worker<br/>orders-prod"]
            SeedAP --> WorkerAP1
            SeedAP --> WorkerAP2
        end
    end

    subgraph Edge["Intermittently-connected edge"]
        direction LR
        SeedShip["Onboard seed<br/>cruise ship / rig / remote site"]
        WorkerShip["Worker<br/>ship workloads"]
        SeedShip -->|provisions| WorkerShip
    end

    TLDGit -.->|watched by| TLDArgo
    TLDArgo -->|agent| WorkerUS1
    TLDArgo -->|agent| WorkerUS2
    TLDArgo -->|agent| WorkerEU1
    TLDArgo -->|agent| WorkerEU2
    TLDArgo -->|agent| WorkerAP1
    TLDArgo -->|agent| WorkerAP2
    TLDArgo -.->|"agent (intermittent backhaul)"| WorkerShip
    TLDKargo -. independent gate .-> USRegion
    TLDKargo -. independent gate .-> EURegion
    TLDKargo -. independent gate .-> APRegion
    TLDKargo -. independent gate .-> Edge
```

### Layer 1 — TLD control plane (top of the diagram)

The **top-level domain control plane** is the one place that has a fleet-wide view. The Akuity-managed Argo CD instance lives here; it sees every cluster in the fleet through a regional agent. The Akuity-managed Kargo instance lives here; it owns the per-region promotion gates. Akuity Intelligence and the fleet-wide Audit Log aggregator live here too — the reason to put them at the TLD instead of per-region is that incident triage at this scale needs a *fleet view*, not thirty separate Slack channels.

A useful rule of thumb: **anything that needs a global query lives at the TLD.** Anything that needs regional autonomy lives in the next layer down.

### Layer 2 — per-region seed cluster

Every region gets exactly one **seed cluster**. The seed runs Crossplane (the regional shared-services control plane) and a cluster-lifecycle layer (Cluster API or Kubermatic or Nutanix — pick one). The seed's *job* is to spin up and manage the worker clusters in its own region. When a new product team needs a workload cluster in eu-west, eu-west's seed provisions it; us-east's seed never gets involved.

This is the single most important architectural insight at tier 4: **regional seeds keep regions independent.** A blast-radius event in eu-west (a misconfigured Crossplane Composition, a Cluster API controller bug, a regional cloud outage) does not propagate to us-east because us-east's seed reconciles from its own state. The TLD control plane keeps a copy of the desired state, but the *runtime* responsibility for keeping the region healthy belongs to the regional seed.

The seed's responsibilities, in order of importance:
1. **Worker-cluster lifecycle.** Provision new workers, upgrade them, retire them. Cluster API or equivalent.
2. **Regional shared services.** Crossplane Compositions for the database, queue, cache, observability backend in this region. The XDatabase claim's regional sub-deployment lives here.
3. **Regional GitOps reconciliation.** Argo CD's regional agent runs here; the agent pulls from the TLD control plane and applies to the workers.

### Layer 3 — worker clusters

Worker clusters run nothing but the application workloads. **Spokes are kept dumb on purpose** — the platform team's disaster-recovery story for a worker is "delete it and let the seed reconstruct it." If you find yourself needing to back up a worker's state, the architecture has a leak. Anything stateful at the worker level is a sign that something belongs on the seed instead.

Per-region promotion gates work because the worker clusters are uniform within a region: when Kargo promotes guestbook to `prod-eu-west`, every eu-west worker that's part of `prod-eu-west` gets the new manifests. A green us-east promotion does not unblock eu-west because the gates are independent — different regulatory windows, different rollout-risk profiles, a bug that fires only on European data residency settings shouldn't ride into APAC because us-east was healthy.

## Online vs. offline — the cruise-ship pattern

The diagram so far assumes every region has a stable backhaul to the TLD control plane. That's true for cloud regions. It is **not true** for a real chunk of tier-4 customers — cruise ships, oil rigs, mining sites, military forward operating bases, ships at sea, remote research stations, anything with a satellite uplink that goes dark when weather rolls in or the ship sails between coverage zones.

These customers want the same platform contract — file an XDatabase claim, deploy a chart via Kargo, hit Akuity Audit Logs for evidence — but they need it to **degrade gracefully** when the backhaul is unreliable. The architectural shifts at this tier:

### What "the spoke is dumb" stops being true for

Tier 4's default disaster-recovery story for a worker is "delete it and let the seed reconstruct it." That assumes you can reach the seed. On a ship at sea you can't, sometimes for days. The disconnected spoke needs to be self-sufficient between reconnects:

- **Argo CD agent caches the last desired state.** When the TLD control plane is unreachable, the agent keeps reconciling against what it last pulled. New deployments don't land, but existing workloads stay healthy and self-heal against pod-level failures.
- **The onboard seed cluster is not optional.** Cloud regions can in principle skip the regional seed and let the TLD push directly to workers; intermittent-edge deployments cannot. Each ship / rig / site runs its own seed cluster with Crossplane locally so claim reconciliation continues without backhaul.
- **YugabyteDB's local nodes keep accepting writes.** xCluster replication catches up when the link comes back. The application sees a working database the whole time; the eventual consistency story is the price.
- **Audit logs store-and-forward.** The agent buffers audit events locally (bounded by disk) and replays them to the TLD aggregator when the link is back. Compliance evidence is never lost; it is sometimes delayed.

### What can't happen during a disconnect

- **Promotions don't reach the disconnected fleet.** Kargo's per-region gate model handles this naturally — a `prod-fleet-at-sea` Stage simply doesn't progress until the ship reconnects. Other regions promote independently.
- **Akuity Intelligence runbooks fire on stale data.** The fleet-wide weekly incident summary will undercount disconnected-fleet incidents until those audit events catch up. The task itself flags "X regions reporting stale" so the on-call manager knows.
- **Cross-region YugabyteDB reads degrade to local.** The disconnected node serves local data only. Writes that need cross-region consistency (rare in this profile — most ship workloads are read-mostly or local-write) are surfaced as conflict on reconnect, resolved per the YB conflict policy the platform team picks.

### What the framework gives you for free

This isn't a tier-4-only conversation — the same primitives let you handle planned maintenance windows, regional cloud outages, and partial-availability degraded states. The fact that the platform has a **per-region Kargo gate**, a **regional seed cluster doing the local Crossplane reconciliation**, and a **store-and-forward audit pipeline** means the disconnected-edge case is just an extreme of patterns the platform already supports.

The buying conversation: most tier-4 customers don't have ships at sea, but most of them have at least one region where the network is "less reliable than the others" — a partner-managed datacenter, a regulated environment behind extra firewalls, a region with smaller cloud presence and worse peering. The cruise-ship architecture is the answer for the worst case, and the same answer covers the merely-flaky case for free.

## Why YugabyteDB at this tier

Tier 3 used Postgres. Why does tier 4 swap to YugabyteDB? Because YugabyteDB is **multi-region native** in a way that Postgres is not.

The tier 3 setup gives every region its own isolated Postgres. That's correct at tier 3 — most companies running tier 3 have a single primary region for state, with read replicas and async backups for DR. Tier 4 customers usually can't get away with that. They need a database that handles multi-region writes natively because:

- **Latency demands.** A user in Frankfurt should hit a database write path that doesn't cross the Atlantic.
- **Sovereignty rules.** EU customer data must stay in the EU, even if the same logical database is also serving APAC.
- **Failover semantics.** When one region degrades, the other regions' writes have to keep working without manual promotion.

YugabyteDB handles these natively via xCluster replication: each region runs its own YB nodes, all of them part of one logical universe. The tier-4 Compositions (`yugabyte-aws.cue`, `yugabyte-gcp.cue`, `yugabyte-onprem.cue`) deploy the local nodes; YugabyteDB's clustering protocol stitches them together into one global database. The app team's claim never says "yugabytedb spanning these regions" — it just says `engine: yugabytedb`, and the platform's regional Compositions handle the rest.

The honest tradeoff: YugabyteDB is operationally heavier than managed Postgres. You're trading "cheap regional Postgres × 3" for "one expensive multi-region YugabyteDB universe." That's only worth it when the latency or sovereignty requirements actually matter — which is most of the time at tier 4 and almost none of the time at tier 3.

This is also why the swap happens at tier 4 specifically. Tier 3 customers running multi-region Postgres-with-failover would have the wrong default. Tier 4 customers running per-region isolated databases would be working around a database limitation that doesn't need to exist.

## What this tier reveals about Akuity's positioning

As the customer matures, Akuity's role narrows and deepens. Tier 1 Akuity does almost everything GitOps-shaped. Tier 4 Akuity is one of four or five carefully chosen layers, owning exactly the GitOps reconciliation and orchestration surface, no more and no less. Cluster lifecycle is owned by Cluster API or Kubermatic. Infra composition is owned by Crossplane on the regional seeds. Database multi-region replication is owned by YugabyteDB. Akuity owns the cross-region GitOps reconciliation surface.

That's a healthy product positioning. The same name appears at every tier and the value compounds rather than stretching thin.

## Tradeoffs and what's missing

This is the most expensive tier to operate and the most expensive to mis-architect. Honest failure modes:

- **The regional seed is the regional blast radius.** Each seed needs HA or a fast rebuild path; one bad Composition push can take a region's worker provisioning offline.
- **Network reach from the seed to every worker apiserver creates VPN/tunnel sprawl.** This is a real cost that grows linearly with worker count.
- **Per-region Kargo gating only works if the promotion model itself is region-aware.** Teams that built their pipeline assuming single-region promotion need to rework it before they can get value out of independent gates.
- **YugabyteDB operational complexity.** Multi-region replication is excellent when it works and a hard debugging surface when it doesn't. Have a YB-experienced operator on staff before you commit.

None of these are Akuity-specific. They're the conversations that turn a tier-4 customer from a logo into a production reference.
