# Akuity Sales Engineer take-home — GitOps maturity in five steps

This is my submission for the Akuity Sales Engineer take-home. The assignment asks for the Kargo Quickstart end-to-end on the Akuity platform plus at least one beneficial change from the base tutorial. Rather than ship a single change, I built the quickstart out into a **five-tier maturity ladder** that walks the same workload (a guestbook app, three environments, a Postgres backend) through five levels of platform-engineering maturity. Each tier corresponds to a different kind of customer profile, so the bonus considerations from the prompt can each show up at the tier where they earn their complexity rather than getting piled into one folder.

The hardest part of platform work isn't picking the tools, it's picking the right tools for the company you're actually at, not the one you wish you were at. Most of us have been on both sides of that mistake. We've over-engineered a five-person startup, or we've shipped a tier-1 pattern at a tier-4 fleet and watched it fall over. The maturity-ladder framing is what lets a single repo carry this conversation.

Three things I'd flag before you dive in:

1. **The new tool at each tier earned its complexity at that tier.** Not before, not after. If you find yourself disagreeing with where a tool shows up, that's the conversation worth having in our review.
2. **The omissions at each tier are deliberate.** The startup without SSO isn't a bug. The wild-west tier 2 isn't an oversight.
3. **Org structure drives the architecture, not the other way around.** Every tier transition in this repo follows from a headcount or authority change, not a tooling choice.

---

## How this maps to the take-home prompt

The base assignment + every item on the bonus list, with where each lives:

| Prompt item | Where it lives |
|---|---|
| Kargo Quickstart end-to-end (base requirement) | Implemented as **tier 0** — the simplest pared-down version, modernized to Kargo v1.x step-based promotions |
| ≥1 beneficial change from the base tutorial | The whole maturity-ladder framing is the change. Per-tier specifics in each tier's `README.md` |
| Additional applications, clusters, or namespaces | `orders` second app at tiers 3+ for AppProject RBAC; tier 4 fans across three regional seed clusters |
| Monorepo vs portfolio deployment | Canonical writeup at [`docs/monorepo-vs-portfolio.md`](docs/monorepo-vs-portfolio.md) |
| ApplicationSet use cases | List generator at tiers 0/1, **git-files** generator for claim sync at tier 3, **cluster** generator for prod fan-out at tier 4 |
| SSO configuration (Dex w/ VCS as OIDC) | `argocd/configmaps/argocd-cm.yaml` at tiers 1+ — connector blocks for GitHub-as-OIDC, Okta, Entra, Google Workspace. Designed-not-wired (placeholder OAuth credentials) |
| Rendered manifest pattern in Kargo | Used at every tier; canonical writeup at [`docs/rendered-manifests-pattern.md`](docs/rendered-manifests-pattern.md) |
| Component vs business workload split | Separate `platform` and `business` AppProjects at every tier; component workloads (ingress-nginx, cert-manager, monitoring, admission policies) sit in their own project with their own RBAC and sync windows |
| Argo/Kargo definitions for common addons | cert-manager at every tier; ingress-nginx from tier 1+ (tier 0 attaches to the cluster's existing Traefik Gateway via HTTPRoute — one less component to operate); kube-prometheus-stack from tier 1+; Loki from tier 2+; Thanos at tier 4 |
| Akuity Intelligence | `tasks/` and `runbooks/` directories in every tier folder with progressively richer scope; canonical writeup at [`docs/tasks-and-runbooks.md`](docs/tasks-and-runbooks.md) |
| Audit Logs | `akuity/audit-log-stream.yaml` at tier 1+ (single SIEM destination); `akuity/audit-log-fleet-export.yaml` at tier 4 (per-region streams + fleet aggregator) |

Tier 0 is the closest match to "the quickstart with one beneficial change." Everything from tier 1 onward is the bonus surface, scoped progressively so the omissions stay coherent.

---

## The five tiers, at a glance

| Tier | Where you'd see this | Stack | What the GitOps layer is doing | What pushes them to the next tier |
|---|---|---|---|---|
| **[0: Kustomize + Kargo](#tier-0-kustomize--kargo)** ([folder](0-kustomize/)) | 3–20 engineers, one cluster, no platform team | Kustomize, Kargo, Argo CD | "Give us GitOps without making us run Argo CD ourselves" | someone forks the repo because Kustomize patches stop composing well |
| **[1: Helm + Kargo](#tier-1-helm--kargo)** ([folder](1-helm/)) | 20–100 engineers, 2–3 clusters, small platform team forming, first SOC 2 on the calendar | Helm, Kargo, Argo CD, SSO via Dex, audit logs, monitoring, admission policies (Audit) | Compliance-grade GitOps as a service | First team provisioning Postgres in Terraform from a laptop |
| **[2: Terraform + Helm (wild west)](#tier-2-terraform--helm-wild-west)** ([folder](2-terraform+helm/)) | Same headcount a year later, multiple teams each picking their own infra story | Terraform (per team, per state) + Helm + Kargo + Argo CD + Loki/datadog/newrelic | Someone will start acting as a platform team trying to fix the mess | Auditor asks "who approved this database before it landed in prod?" |
| **[3: Crossplane + Helm](#tier-3-crossplane--helm)** ([folder](3-crossplane+helm/)) | 500–several thousand engineers, real platform engineering team, infra-as-product | Crossplane (XRDs + Compositions) + dual CD pipeline + Helm + Kargo + Argo CD + admission policies (Enforce) | The GitOps half of an internal developer platform | Regional sovereignty, latency, or regulatory pressure forcing fleet-of-fleets thinking |
| **[4: Hybrid Multicloud](#tier-4-hybrid-multicloud)** ([folder](4-hybridmulticloud/)) | Multi-region, multi-cloud, sometimes on-prem or edge | Same Crossplane abstraction (engine swaps to YugabyteDB for multi-region native writes), per-region seeds, ApplicationSet cluster generators, per-region Kargo gates, Thanos | One managed GitOps control plane across a fleet too big for one team | (none — this is where it ends) |

Every tier folder is self-contained. `kubectl apply -k <tier>/argocd/` against a fresh cluster stands the whole tier up. The longer-form customer narrative for each tier lives at [`<tier>/NARRATIVE.md`](.) (one in each tier folder) — those are the *why this kind of company exists* essays. The per-tier `README.md` files are the *how the bits fit together* essays.

---

## Tier-by-tier

### Tier 0: Kustomize + Kargo

The base of the take-home assignment. The Kargo Quickstart, paired down. Five engineers, one cluster, the CTO is also the SRE. They pay Akuity to run Argo CD and Kargo so they don't have to operate either.

The promotion model is the rendered-manifests pattern: Kargo runs `kustomize build` in CI, commits to `env/<stage>`, Argo CD applies plain YAML. The PR diff on a promotion is the literal set of API objects changing. That pattern scales all the way up to tier 4 unchanged. This is part of why I picked it for tier 0 even though Kustomize-the-templating-tool gets replaced at tier 1. The promotion *shape* outlives the templating choice.

What's deliberately not here: SSO, audit-log streaming, admission policies, monitoring stack, AppProject role bindings. Shipping any of that at five engineers is overhead without a corresponding pain and usually would leverage a saas to do it too like newrelic, datadog, or grafana. Each piece reappears at the tier where its absence becomes the trigger.

Implementation in [`0-kustomize/`](0-kustomize/). Long-form in [`0-kustomize/NARRATIVE.md`](0-kustomize/NARRATIVE.md).

### Tier 1: Helm + Kargo

The growth-stage company. Around 50 engineers, two or three clusters split by env, a platform team/SRE of one to two usually including the CTO. SOC 2 is generally on the calendar.

Two things change. Helm replaces Kustomize because the chart's per-env config has graduated past what patches express well due to different resource sizes, optional sidecars, conditional NetworkPolicies. The promotion model itself doesn't change; Kargo still hydrates rendered YAML, Argo CD still applies plain manifests. The substantive change is org-shaped: SSO via Dex, audit logs flowing into a SIEM, portfolio-style repos (one per business app, one platform repo for shared component workloads), admission policies in Audit mode.

The Audit-mode-first detail is worth flagging though at this stage. Rules that block on day one make devs lose trust in the platform and the team responsible. Setting the system to audit first, lets you find the violations against real workloads before you flip to Enforce. By tier 3 the policies are battle-tested; that's where Enforce becomes the right default.

Implementation in [`1-helm/`](1-helm/). Long-form in [`1-helm/NARRATIVE.md`](1-helm/NARRATIVE.md).

### Tier 2: Terraform + Helm (wild west)

This repo is the picture **most growth-stage companies actually live in** and it's the one tutorials skip.

The app needs Postgres. Team A writes a Terraform module and applies it from a laptop. Team B copy-pastes it. Team C uses the AWS console because they're in a hurry. State lives in five different places. The chart's `envFrom` reads a Secret created out-of-band by `terraform apply`, and nothing enforces that the Secret name in the Terraform output matches the chart's `database.secretName` value. I shipped a `postgres-secret-watcher` Application that goes intentionally OutOfSync after `terraform apply` mutates the Secret data.

The point: **GitOps tools reconcile git, and the wild west is not in git.** Akuity doesn't fix this tier. What Akuity does is *be the substrate* for the fix so when the platform team gets the headcount and authority to author abstractions, the Crossplane claims they create get reconciled by the same Argo CD instance, the same Kargo, the same audit pipeline. The tier-3 transition is organizational, not technical.

Implementation in [`2-terraform+helm/`](2-terraform+helm/). Long-form in [`2-terraform+helm/NARRATIVE.md`](2-terraform+helm/NARRATIVE.md).

### Tier 3: Crossplane + Helm

The platform team becomes a product team. They publish an `XDatabase` XRD; app teams file three-line claims in their helm chart and the Composition expands each claim into managed infra plus a connection Secret in the consuming chart's namespace. **Two reconciliation loops, owning different halves.** Crossplane reconciles resources it composed; Argo CD reconciles git. They compose; they don't compete and that's the conversation customers running both will want to have, especially the ones who walked in expecting these tools to fight.

The structural change at tier 3 worth understanding: **two CD pipelines.** The API pipeline (Kargo Project `kargo-claims`) promotes claim YAML and rendered XRD/Composition output, slow cadence, platform team. The App pipeline (Kargo Project `kargo-simple`) promotes the chart bytes, fast cadence, app team. Sequenced via sync waves: API at -2, App at 0. The chart doesn't deploy until the claim is Ready (a `db-claim-ready` AnalysisTemplate verifies it).

I split the pipelines because chart-only releases shouldn't touch claim freight, and XRD migrations shouldn't block app deploys. Different change-management problems, different risk profiles, different owners. Combine them and you get the worst of both situations as app teams waiting on platform-team review of every chart bump, platform teams scrambling to coordinate XRD changes around app releases.

XRDs and Compositions live under [`framework/`](framework/) as CUE source, rendering to [`platform/crossplane/`](platform/crossplane/) via `make export-cluster CLUSTER=demo`. Tier folders 3 and 4 ship only the **claims**. The platform team owns the abstraction in *one* place; tiers 3 and 4 reference it.

Implementation in [`3-crossplane+helm/`](3-crossplane+helm/). Long-form in [`3-crossplane+helm/NARRATIVE.md`](3-crossplane+helm/NARRATIVE.md).

### Tier 4: Hybrid Multicloud

**The shape is identical to the tier-3 claim** — only the `engine:` value swaps from `postgres` to `yugabytedb` (Open `4-hybridmulticloud/claims/guestbook-prod.yaml`to see the change). XRD identical, chart identical, claim fields identical, app team writes nothing structurally new. That's the design.

The engine swap matters: YugabyteDB is multi-region native in a way Postgres isn't. Tier 3's per-region isolated Postgres pattern can't span regions natively; YugabyteDB can. One logical database, regional sub-deployments that join one global xCluster universe, latency and sovereignty handled by the database itself.

What else changed lives below the abstraction. The platform team added three new Compositions (`yugabyte-aws.cue`, `yugabyte-gcp.cue`, `yugabyte-onprem.cue`) alongside the existing tier-3 Postgres family — all six satisfy the same XRD. Each regional seed cluster carries an `EnvironmentConfig` declaring its `provider`. Crossplane reads it at composition time, matches `compositionSelector` against `provider:` + `engine:`, and routes the same claim to the right Composition. The app team never knows which cloud answered.

The other tier-4 idea: **per-region promotion gates.** Three Stages, `prod-us-east`, `prod-eu-west`, and `prod-ap-southeast` which areeach independent. Green us-east does not unblock eu-west. Different regulatory windows, different rollout-risk profiles, a bug that fires only on European data residency settings shouldn't ride into APAC because us-east was healthy. All three Stages reference one parameterized `regional-promote` PromotionTask, so each Stage is ~30 lines instead of ~120. That's PromotionTask earning its complexity at the tier where it pays for itself.

Architecturally, tier 4 stacks three layers: a **TLD control plane** (the Akuity-managed Argo CD + Kargo + Audit Logs + Intelligence — fleet-wide view), **per-region seed clusters** (Crossplane + Cluster API — each seed spins up and manages the worker clusters in its own region), and **worker clusters** (kept dumb on purpose — the disaster-recovery story is "delete the worker, let the seed reconstruct it"). Long-form architecture in [`4-hybridmulticloud/NARRATIVE.md`](4-hybridmulticloud/NARRATIVE.md).

Akuity at this tier is one of four or five carefully chosen layers. Cluster lifecycle is Cluster API or Kubermatic. Infra abstraction is Crossplane. Database multi-region replication is YugabyteDB. Akuity owns GitOps reconciliation and cross-region orchestration, and **nothing else**. That's healthy positioning, not a retreat — the value compounds rather than stretching thin.

Implementation in [`4-hybridmulticloud/`](4-hybridmulticloud/). Long-form in [`4-hybridmulticloud/NARRATIVE.md`](4-hybridmulticloud/NARRATIVE.md).

---

## Assumptions I made

A few things were unstated in the prompt that I had to pick a direction on:

- **The "beneficial change" can be the whole framing, not a single feature.** I read this as "at least one" as a floor, not a ceiling. The maturity ladder is one big change that makes every smaller change make sense.
- **Designed-not-wired is acceptable for things that need real customer creds.** Dex + GitHub OIDC, the SIEM webhook, and the per-region GitHub Apps would all take ~30 minutes each to wire to live providers; none of that wiring earns review credit, and committing real OAuth client IDs to a public repo is a non-starter. Where I had to make a decision in the code, I marked the file explicitly with a "designed, not wired" note.
- **Public repo means placeholders, not credentials.** Every credential-shaped string in the repo is a `<placeholder>`. The `sed` block at the bottom of this file is the customer-onboarding step to making any one of these examples live.
- **The Akuity-managed Argo CD instance is what I'm using to test all of this.** My trial-account Akuity Argo CD instance is the deployment target — I did not stand up self-hosted Argo CD anywhere in the demo. The agent connection model is what tier 0 is selling, and verifying the manifests in this repo against an actual Akuity-managed instance is the cleanest way to demonstrate the lift it removes. Self-hosting becomes viable in raw cost terms at tier 3, but rarely in opportunity-cost terms.
- **One workload, five platforms.** I held the guestbook constant across tiers so the diff between tiers is *only* the platform. The cost is that tier 4 isn't showing off a more interesting app except for a database change to support multi-region natively.
- **`framework/` is shared across tiers 3 and 4.** Tier folders 0–2 are fully self-contained. Tier 3 and 4 reference one canonical `framework/` for XRDs/Compositions because the whole point of tier 3 is that the abstraction has *one* source and duplicating it per tier would defeat the narrative.

---

## What this repo is not

- **Not a turnkey product.** Each tier is a runnable demonstration, not a packaged distribution. Real customers make decisions this repo doesn't make for them — IdP, cloud provider, observability stack, cluster lifecycle layer.
- **Not a one-size-fits-all answer.** The whole point of laying out five tiers is that the *right* answer changes with the company. Tier-3 abstractions on a tier-1 company is over-engineering. Tier-1 patterns on a tier-4 fleet is malpractice.
- **Not showing Crossplane as a Competitor to Akuity.** Crossplane and ArgoCD reconcile different things in a k8 cluster because resources Crossplane composes are infrastructure in nature not application based. When customers walk in expecting these tools to compete, we show them how they layer.

---

## Notes for the technical review

The prompt mentioned the discussion will cover: walkthrough, key design choices, experience using the platform, what surprised me, what felt complex or frustrating, and favorite feature / perceived customer value. Pre-staged thoughts:

**Walkthrough plan.** I'd start at tier 0 (the literal quickstart deliverable), then jump straight to tier 3 because that's where the architectural conversation gets interesting — dual CD pipeline, the Crossplane / Argo CD composition, `framework/` as the shared abstraction source. Tier 4 is the natural close: same claim, three clouds.

**Key design choices.** Top three: (1) the maturity-ladder framing as the "beneficial change," because it lets every bonus consideration land where it earns its keep; (2) the dual CD pipeline split at tier 3 between API (claims) and App (chart), each with its own Kargo Project and ApplicationSet; (3) the parameterized `regional-promote` PromotionTask at tier 4 that collapses 120-line regional Stages to 30 lines.

**Experience using the platform.** The agent + Akuity-managed Argo CD onboarding flow is the lightest-weight Argo CD I've ever stood up. Coming from self-hosted, the upgrade-and-operate burden disappearing is the real product, even more than the UI. The Kargo v1.x step-based promotion model felt clean once I unlearned the deprecated `promotionMechanisms` shape.

**What surprised me.** The `tasks/` and `runbooks/` integration with Akuity Intelligence is the most under-marketed feature I encountered. Every other GitOps platform competes on "we render manifests prettier"; this one ships the operational substrate the on-call team actually uses. That's the slide that should lead in any enterprise pitch.

**What felt complex.** The Composition + EnvironmentConfig + `compositionSelector` wiring at tier 4 has a lot of moving parts, and the documentation for `function-environment-configs` is sparse. I noted this honestly in the tier-4 README and the wiring is intentionally understated. Real production deployments need a Composition pipeline step the demo doesn't fully implement.

**Favorite feature / perceived value.** Akuity Audit Logs as the SOC 2 evidence pipeline. Most customers don't yet realize they're going to need this until the auditor asks; by then they're rebuilding the export plumbing themselves. Having it as a managed feature with a single `OrganizationStreamingDestination` resource turns a quarter-long compliance project into a single-PR change.

Open questions I'd love to discuss:
- The connection-Secret namespace bridge at tier 3+; what's the cleanest pattern in production deployments you've seen?
- Per-region Kargo gating at tier 4; how often do real customers actually use independent gates vs. effectively-coupled ones in practice?
- Tasks and runbooks tier-progression; is this how Akuity Intelligence is positioned in the field, or am I reading too much into it?

---

## How to run any of it

Per-tier setup instructions live in each tier folder's `README.md`. Build/render commands for `framework/` (the tier-3+ substrate) live in [`CLAUDE.md`](CLAUDE.md). The CI drift guard runs as `make check-shared`.

### Placeholders to replace before applying

A few manifests carry placeholder strings to customize per company:

| Placeholder | Where | What to replace |
|---|---|---|
| `<repo>` | every `argocd/projects/*.yaml` `sourceRepos`, every Application `repoURL`, every Kargo Stage `gitRepo` | the company's git repo URL |
| `<user>` | `kargo/warehouses/guestbook.yaml`, every Stage `imageRepo` | the company's GHCR namespace |
| `<slack-channel>` | every Argo CD Notifications subscription annotation | the company's incident Slack channel |
| `<your-domain>`, `<your-org>` | `argocd/configmaps/argocd-cm.yaml` Dex connectors | the company's domain + GitHub org |
| `<github-oauth-app-client-id>`, etc. | `argocd-cm.yaml` Dex connectors | OAuth credentials provisioned for the Akuity Argo CD instance |

One-shot `sed` to handle all of them at clone time:

```bash
sed -i '' \
  -e 's|<repo>|github.com/<your-org>/<your-repo>|g' \
  -e 's|<user>|<your-org>|g' \
  -e 's|<slack-channel>|#deploys|g' \
  -e 's|<your-domain>|<your-org>.com|g' \
  $(find . -type f -name '*.yaml' -not -path './apps/*' -not -path './platform/crossplane/*')
```

Tier 0 needs the fewest substitutions; tier 4 needs the most (per-region SIEM endpoints, per-region GitHub Apps).

---

The takeaway, if I had to compress all of it: **DevOps maturity is not the same as DevOps quality.** A great tier-0 company can be a worse hire than a struggling tier-3 one. What matters is whether the platform fits the company, and whether the company is honest about the tier it's actually at. Most of them aren't. That's where the SE work is.
