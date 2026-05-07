# Tier 4: Hybrid Multicloud

Same XRD. Same claim shape. Same chart. The app team writes nothing new.

What changes lives below the abstraction:

- **Engine swaps Postgres → YugabyteDB** because YugabyteDB is multi-region native. Tier 3's per-region isolated Postgres pattern can't span regions natively; YugabyteDB can. One logical database, regional sub-deployments that join one global xCluster universe.
- The platform team adds three new Compositions (`yugabyte-aws.cue`, `yugabyte-gcp.cue`, `yugabyte-onprem.cue`) — all three satisfy the same `XDatabase` XRD; selection happens via `compositionSelector` matching `provider:` (from the regional seed's `EnvironmentConfig`) AND `engine: yugabytedb` (from the claim).
- The app's prod rollout switches from a list generator to a **cluster generator** ApplicationSet, fanning the prod manifests across regional seeds. Kargo gets per-region prod Stages, each promoting independently.
- Three layers stack: TLD control plane (Akuity) → per-region seed clusters (Crossplane + Cluster API) → worker clusters. Long-form architecture in [`NARRATIVE.md`](NARRATIVE.md).

The buying conversation: "we already have the abstraction; now we need it to span clouds without app teams caring."

## What was added vs. tier 3

| Layer | Tier 3 | Tier 4 |
|---|---|---|
| XRD | `framework/platform/xrd/database.cue` | unchanged |
| Database engine | Postgres (per-region isolated) | **YugabyteDB** (multi-region native, one universe via xCluster) |
| Composition | `database-{aws,gcp,onprem}.cue` (Postgres family) | + `yugabyte-{aws,gcp,onprem}.cue` (YugabyteDB family — three new variants, same XRD) |
| Routing | n/a | `framework/platform/environment/region-{us-east,eu-west,ap-southeast}.cue` declares `provider` per regional seed; XRD's `compositionSelector` matches `provider` + `engine` |
| Claim shape | `XDatabase` with `engine: postgres` | `XDatabase` with `engine: yugabytedb` |
| Argo CD claim sync | `claim-sync.yaml` git-files generator (single cluster) | `claim-sync-nonprod.yaml` (git-files, dev+staging) + `claim-sync-prod.yaml` (cluster generator across regional seeds) |
| Argo CD app sync | `business-apps.yaml` list generator | List for dev/staging + `regional-rollout-prod.yaml` cluster generator for prod |
| Kargo claim Stages | 3 (dev, staging, prod) | 5 (dev, staging, prod-us-east, prod-eu-west, prod-ap-southeast) |
| Kargo app Stages | 3 (dev, staging, prod) | 5 (same) — prod Stages reference a single parameterized PromotionTask (`regional-promote`); each Stage is ~30 lines instead of ~120 |
| Promotion ordering | API → App via sync waves | Same, fanned independently per region |

## Layout

```
4-hybridmulticloud/
├── claims/
│   ├── guestbook-{dev,staging,prod}.yaml      # XDatabase, engine: yugabytedb
│   ├── orders-{dev,staging,prod}.yaml         # second business app, same engine
├── charts/guestbook/                          # YSQL port 5433 instead of 5432
├── env/
│   ├── values-{dev,staging}.yaml
│   ├── values-prod-us-east.yaml               # per-region prod overlays
│   ├── values-prod-eu-west.yaml
│   └── values-prod-ap-southeast.yaml
├── argocd/
│   ├── applicationsets/
│   │   ├── claim-sync-nonprod.yaml            # API pipeline (dev/staging) — git-files
│   │   ├── claim-sync-prod.yaml               # API pipeline (prod) — cluster generator
│   │   ├── business-apps.yaml                 # App pipeline (dev/staging) — list
│   │   └── regional-rollout-prod.yaml         # App pipeline (prod) — cluster generator
│   ├── apps/                                   # platform Applications
│   ├── configmaps/                            # argocd-cm (Dex), argocd-notifications-cm
│   └── projects/{platform,business}.yaml
├── kargo/
│   ├── projects/{kargo-claims,kargo-simple}.yaml + project-configs
│   ├── warehouses/{claims,guestbook}.yaml
│   ├── stages/                                 # 10 total (5 claims, 5 app)
│   ├── promotion-tasks/regional-promote.yaml   # parameterized prod PromotionTask
│   └── analysis-templates/                     # guestbook-http-probe, error-rate-prometheus, db-claim-ready, regional-latency
├── platform/
│   ├── admission/                              # VAPs (Enforce mode)
│   ├── kube-prometheus-stack/, loki/, thanos/  # fleet observability
│   ├── Traefik/, cert-manager/
├── akuity/
│   ├── audit-log-fleet-export.yaml             # per-region streams + fleet aggregator
│   └── README.md
├── tasks/, runbooks/                          # Akuity Intelligence, region-aware
└── rendered/{dev,staging,prod-us-east,prod-eu-west,prod-ap-southeast}/.gitkeep
```

## Where the under-the-hood unification lives

| Concern | Location |
|---|---|
| XRD (provider- and engine-agnostic) | [`../framework/platform/xrd/database.cue`](../framework/platform/xrd/database.cue) |
| Postgres family (tier-3 default; available at tier 4 too if needed) | `database-{aws,gcp,onprem}.cue` |
| YugabyteDB family (tier-4 default) | `yugabyte-{aws,gcp,onprem}.cue` |
| EnvironmentConfigs (regional) | [`../framework/platform/environment/region-*.cue`](../framework/platform/environment/) |

Crossplane reads the seed cluster's `EnvironmentConfig` at composition time. The XRD's `compositionSelector` matches `provider: <value>` AND `engine: <value>`, and the right Composition runs. The claim never names a cloud; the Composition's regional sub-deployment joins the global YugabyteDB universe.

## Apply

```bash
# 1. Render the multi-cloud abstraction.
make export-cluster CLUSTER=demo

# 2. Apply XRDs + Compositions to every regional seed.
kubectl --context=seed-us-east       apply -R -f platform/crossplane/
kubectl --context=seed-eu-west       apply -R -f platform/crossplane/
kubectl --context=seed-ap-southeast  apply -R -f platform/crossplane/

# 3. Apply the EnvironmentConfig that matches each seed's provider.
kubectl --context=seed-us-east       apply -f platform/crossplane/environment/region-us-east.yaml
kubectl --context=seed-eu-west       apply -f platform/crossplane/environment/region-eu-west.yaml
kubectl --context=seed-ap-southeast  apply -f platform/crossplane/environment/region-ap-southeast.yaml

# 4. Bootstrap the tier-4 Argo CD layer. Cluster registrations must already
#    carry labels env=prod, app=guestbook, region=<region>, role=seed for
#    the cluster generators to fan out correctly.
kubectl apply -k 4-hybridmulticloud/argocd/
```

## What this tier shows

- **The contract did not change.** Tier 3 → tier 4 is invisible to app teams in claim shape. The engine value swaps from `postgres` to `yugabytedb` but the field that holds it doesn't.
- **The database itself is now multi-region native.** YugabyteDB regional sub-deployments form one global universe. App teams in eu-west hit local writes; sovereignty + latency requirements satisfy themselves.
- **Composition is a portfolio.** Adding a fourth provider (Azure, Oracle, hyperconverged) is one more Composition file plus an EnvironmentConfig label. The XRD does not move.
- **Per-region promotion gates are independent.** Promoting `prod-us-east` does not unblock `prod-eu-west`.
- **Akuity narrows and deepens.** Akuity owns the cross-region GitOps reconciliation and orchestration surface. Cluster lifecycle (Cluster API / Kubermatic / Nutanix) and Crossplane (the regional shared-services API) sit underneath.

## Compliance posture

Tier 4 inherits everything from tier 3 and adds **data sovereignty + regional regulation** as first-class concerns. This is the tier where the YugabyteDB swap and the per-region Kargo gates stop being architectural preferences and start being **legal requirements**.

Inherited from tier 3 (still in scope, now operating at fleet scale):

- SOC 2 Type 2, ISO 27001 + 27017 + 27018, PCI-DSS Level 1, HIPAA, FedRAMP Moderate, HITRUST CSF, NIST 800-53 / NIST CSF, GDPR Article 28, CCPA/CPRA. Audit-log evidence is now a fleet-wide query (`akuity/audit-log-fleet-export.yaml` is what makes this tractable).

New at tier 4:

- **Data sovereignty / residency.** GDPR's restriction on EU data leaving the EU is the canonical example, but the same shape repeats globally: **PIPL** (China), **LGPD** (Brazil), **POPIA** (South Africa), **DPDP Act** (India), **Australian Privacy Principles**, **PIPEDA** (Canada). The YugabyteDB swap matters here because the database itself enforces residency: an eu-west user's writes land in eu-west's YB nodes and never cross the Atlantic. Tier 3's per-region isolated Postgres would force the app team to handle residency in code; tier 4 makes it a database property.
- **Schrems II / cross-border transfer.** SCCs (Standard Contractual Clauses), Transfer Impact Assessments, and the Article 46 supplementary measures conversation. Per-region audit-log destinations (`audit-log-fleet-export.yaml` ships separate streams for us-east, eu-west, ap-southeast) is the technical answer to "EU audit data must be processed in the EU."
- **Sovereign-cloud certifications.** **FedRAMP High** (US gov, regulated workloads), **IRAP PROTECTED** (Australia gov), **C5** (Germany), **SecNumCloud** (France), **HDS** (France healthcare), **K-ISMS** (South Korea), **MTCS** (Singapore). Each one demands cloud-region isolation that the per-region seed pattern provides; the regional Composition variants (AWS / GCP / on-prem) let you mix sovereign clouds with hyperscalers per region.
- **Sector-specific multi-region.** **PSD2 + SCA** (EU payments), **MAS TRM** (Singapore monetary authority), **NIS2** (EU critical infrastructure), **DORA** (EU financial services digital operational resilience). DORA in particular requires demonstrable regional failover testing — per-region Kargo gates + the `regional-rollout-rollback.md` runbook are the substrate.
- **Regional incident response.** Akuity Intelligence's fleet-wide weekly incident summary (`tasks/platform/weekly-incident-summary.md`) is what makes "demonstrate to the regulator that your eu-west region's incident MTTR meets the SLA they require" answerable in one query instead of one ticket per cluster.

The structural insight worth flagging: **at tier 3 compliance is a control-objective conversation; at tier 4 it's a regional-architecture conversation.** Different regulators care about different regions in different ways, and the platform either supports per-region differentiation natively or it doesn't. The framework's three-Composition / per-region-EnvironmentConfig / per-region-Kargo-gate pattern is what makes that differentiation expressible without rebuilding the platform per regulator.

### Istio multi-cluster mesh (cross-region east-west)

Tier 3 introduced Istio as the answer to the strict-reading service-mesh finding from tier 2. **Tier 4 extends Istio to a multi-primary multi-cluster topology** which builds one logical mesh spanning every regional seed and worker cluster. The mesh becomes the cross-region trust fabric for both YugabyteDB's xCluster traffic and the cross-region service calls the apps make.

The pieces tier 4 adds on top of tier 3's Istio install:

- **`istiod` per region** in multi-primary mode, sharing root CA. Each region's control plane is independent; a regional outage doesn't take the mesh down elsewhere.
- **East-west gateway** per region (`istio-eastwestgateway`) — the only path mesh-internal traffic crosses regions through. Mutual TLS terminates on identity, not IP.
- **`ServiceEntry` + `WorkloadEntry`** for the YugabyteDB master endpoints across regions, so xCluster replication traffic inherits the mesh's mTLS automatically.
- **Per-region `AuthorizationPolicy`** keyed off `request.auth.principal` — sovereignty rules become "EU workloads can only call services whose identity claims EU residency." The policy enforces what the audit log proves.

The compliance payoff: cross-region traffic that lands in EU stays in EU because the mesh's `AuthorizationPolicy` denies cross-region calls that would violate residency. SCCs become the answer for the data plane Akuity manages; the mesh's policy is the answer for everything else.

## Honest gaps

- **EnvironmentConfig + compositionSelector wiring is real but understated.** The CUE captures `provider:` and `engine:` labels; turning that into a working `compositionSelector` on the XRD requires a function-environment-configs pipeline step the demo Compositions don't yet declare. Production deployments add it; the demo focuses on the directional story.
- **YugabyteDB Helm-chart stand-in.** All three YugabyteDB Compositions wrap the same `yugabytedb` Helm chart for review portability; the AWS variant in production would point at provider-aws compute primitives plus YugabyteDB Anywhere or Yugabyte Managed; the GCP variant likewise. The CUE files note this.
- **Cluster registration labels are assumed.** Tier 4 cluster generators depend on `env=prod`, `app=guestbook`, `region=<region>`, `role=seed` being set when each cluster is connected to Akuity. These come from the Akuity `Cluster` decorators.

Longer narrative in [`NARRATIVE.md`](NARRATIVE.md).
