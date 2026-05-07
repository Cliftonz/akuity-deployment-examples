# Tier 3: Crossplane + Helm

(Argo CD is implicit at every tier from 0 onward — it is what reconciles all of these manifests in the first place. The folder name only highlights what's *new* at this tier.)

The platform team publishes an XRD; app teams file claims. The wild-west Terraform from tier 2 is gone. The chart is unchanged. The story is the platform-engineering moment when "every team picks their own database story" becomes "the platform team owns the database abstraction."

## Where the abstraction lives

This tier deliberately does **not** copy XRD or Composition source. The single source of truth is `framework/`:

| Concern | Location | Notes |
|---|---|---|
| XRD source (CUE) | [`../framework/platform/xrd/database.cue`](../framework/platform/xrd/database.cue) | `XDatabase` cluster-scoped resource. Group `infra.k8`. Required fields: `name`, `engine`, `version`, `size`, `storageGB`, `tier`, `cluster`, `owner`. |
| Composition source (CUE) | [`../framework/platform/compositions/database.cue`](../framework/platform/compositions/database.cue) | Mode `Pipeline`, `function-patch-and-transform`. Composes a provider-helm `Release` of bitnami/postgresql. |
| Rendered XRD/Composition YAML | [`../platform/crossplane/{xrds,compositions}/`](../platform/crossplane/) | Output of `make export-cluster CLUSTER=demo` from repo root. Apply this to the hub cluster before applying claims. |

The CUE → YAML render is identical to what every other tier-3+ user gets; tier 3 simply ships claims that consume it.

## Why CUE, and why CUE *with Crossplane*

The XRDs and Compositions in `framework/` are written in [CUE](https://cuelang.org), not raw YAML or Helm or Jsonnet. Once you understand why CUE specifically, the rest of the framework's structure stops looking arbitrary.

### Why CUE over plain YAML

Crossplane XRDs and Compositions are **tightly coupled**. The XRD declares a schema (in the openapi spec definition that k8 uses) thus the Composition has to satisfy it. If a field name drifts in one but not the other, the Composition silently breaks at apply time. With raw YAML, keeping them aligned is a code-review job that fails the moment two PRs land in the same week.

CUE is a **constraint language, not a templating language.** It unifies types and values into one constraint system. 

 Think of it like typescript for javascript

When the XRD says `spec.engine` is required and `spec.size` must be a string, the Composition's patch references to those fields are checked at `cue vet` time (ie CI) long before any cluster sees the YAML. A typo fails CI; it cannot ship.

### Why CUE over Helm or Jsonnet for the framework

- **Helm** is templating with string substitution. It can render a manifest that's structurally invalid (typo in a field name), and you find out at apply time. For application packaging that's fine; for the platform API it's not.
- **Jsonnet** has functional composition but no native schema enforcement. You can build types on top of it, but the language wasn't designed around constraints.
- **CUE** validates and generates from the same source. The schema *is* the code. There's no second tool to keep the schema in sync with the templates.

Helm still has a place at this tier. The chart that runs the *application* is a Helm chart, and the bitnami/postgresql release the Composition deploys is also Helm. CUE is the platform-API layer; Helm is the workload layer. They don't compete.

### Why CUE specifically with Crossplane

Three things make the pairing unusually tight:

1. **One source of truth for both halves of an API.** The XRD declares the spec; the Composition implements it. With CUE, both come from one CUE file (or a shared `#XDatabase` definition referenced by both). A change to one half forces the other half to update or `cue vet` fails.

2. **Multi-Composition coordination.** Tier 4 ships three Compositions (`yugabyte-aws.cue`, `yugabyte-gcp.cue`, `yugabyte-onprem.cue`) all satisfying the same XRD. CUE constrains them to a shared interface which the patches are typed against the XRD schema, so a misnamed field in any one variant fails validation. Without CUE, that's "we wrote three Compositions, hopefully they all work."

3. **Tier policy as code.** `framework/libs/tiers/{dev,staging,production}.cue` defines per-tier defaults: dev gets 1cpu/1Gi quota and Kyverno in Audit; prod gets 4cpu/4Gi and Kyverno in Enforce. CUE's defaults + constraints make "every namespace gets the right quota for its tier unless explicitly overridden" a *type-checked* statement, not a wish.

### Render-time, not runtime

CUE runs at build time only. `make export-cluster CLUSTER=demo` runs `cue export`, produces deterministic YAML, and the cluster never sees CUE. Crossplane reconciles plain Kubernetes resources. There's no runtime CUE controller, no admission webhook chain, no chart-of-charts dependency hell. The cluster's view is "here are some XRDs and Compositions" and that's it.

This matters for compliance: the audit-log entry for "this Composition was applied" points at a YAML file in git, not at a CUE evaluation that happened in CI. Auditors get the artifact they recognize.

### When *not* to use CUE

- **You're shipping one or two Compositions.** The CUE setup cost isn't earned until you have enough XRD/Composition surface that drift between them is a real risk.

Longer rationale + the alternatives considered: [`../docs/why-crossplane-cue.md`](../docs/why-crossplane-cue.md).

## Two CD pipelines

Tier 3 introduces a structural change in the rollout shape: **two independent CD pipelines**, run by Kargo + reconciled by Argo CD.

| Pipeline | Owner | Cadence | What promotes | Argo CD generator | Kargo Project |
|---|---|---|---|---|---|
| **API pipeline** | Platform team | Slow (monthly) | XDatabase claim YAML + rendered XRD/Composition | git-files generator over `claims/*.yaml` | `kargo-claims` |
| **App pipeline** | App team | Fast (daily+) | Helm chart bytes | List generator over `dev`/`staging`/`prod` | `kargo-simple` |

The split matters because a chart-only release (which is most of them) does not need to touch claim freight, and an XRD migration does not block app deploys. The API pipeline lands first (sync-wave -2); the app pipeline lands second (sync-wave 0) and consumes the connection Secret produced by the claim.

## Layout

```
3-crossplane+helm/
├── claims/
│   ├── guestbook-dev.yaml                   # XDatabase, tier=dev
│   ├── guestbook-staging.yaml               # XDatabase, tier=staging
│   └── guestbook-prod.yaml                  # XDatabase, tier=production
├── charts/guestbook/                        # tier 1/2 chart unchanged
├── env/values-{dev,staging,prod}.yaml        # secretName per env
├── argocd/
│   ├── applicationsets/
│   │   ├── claim-sync.yaml                  # API pipeline (git-files generator)
│   │   └── business-apps.yaml               # App pipeline (list generator)
│   ├── apps/                                 # platform Applications: argocd-config, admission-policies,
│   │                                         # kube-prometheus-stack, loki, Traefik, cert-manager,
│   │                                         # kargo-pipelines
│   ├── configmaps/                          # argocd-cm (Dex/OIDC), argocd-notifications-cm
│   └── projects/{platform,business}.yaml
├── kargo/
│   ├── projects/
│   │   ├── kargo-claims.yaml + project-config-claims.yaml   # API pipeline
│   │   └── kargo-simple.yaml + project-config.yaml          # App pipeline
│   ├── warehouses/
│   │   ├── claims.yaml                      # git: claims/* + framework/platform/*
│   │   └── guestbook.yaml                   # ghcr.io/<user>/guestbook
│   ├── stages/
│   │   ├── claims-{dev,staging,prod}.yaml   # API pipeline Stages
│   │   └── {dev,staging,prod}.yaml          # App pipeline Stages
│   └── analysis-templates/
├── platform/
│   ├── admission/                           # ValidatingAdmissionPolicy + Binding (Enforce)
│   ├── kube-prometheus-stack/, loki/        # monitoring + logging
│   ├── Traefik/, cert-manager/
├── akuity/                                   # Akuity org-level: audit-log-stream.yaml
├── tasks/, runbooks/                        # Akuity Intelligence (scheduled reports + playbooks)
└── rendered/{dev,staging,prod}/             # Kargo writes hydrated YAML here per env branch
```

## Apply

Three-step bootstrap. Each step is a normal GitOps action; nothing is run from a laptop.

```bash
# 1. Render and apply the platform team's API (XRDs + Compositions).
#    This step is what tier 3 customers do once per cluster, not per app.
make export-cluster CLUSTER=demo
kubectl apply -R -f platform/crossplane/

# 2. Bootstrap Argo CD with the tier-3 manifest set.
kubectl apply -k 3-crossplane+helm/argocd/

# 3. Argo CD now reconciles claims (sync-wave -2) before the chart Apps come up.
#    The XDatabase claims hit Crossplane; Compositions provision Postgres
#    via provider-helm; a connection Secret lands in the app namespace;
#    the chart's envFrom picks it up.
```

## What this tier shows

- **One abstraction, three claims.** The platform team owns the XRD and Composition; the app team writes only the three short claims under [`claims/`](claims/). Standards (engine, version range, encryption) are enforced by the XRD schema and the Composition.
- **Reconciled, reviewed infra.** The Terraform-state ambiguity from tier 2 is gone. The claims are git-managed; Argo CD reconciles them; drift on Crossplane-composed resources triggers a re-converge.
- **Composition is the platform team's product.** Switching from bitnami/postgresql Helm to AWS RDS, GCP Cloud SQL, or on-prem operator-pg is a Composition swap — the claim does not change. (Tier 4 turns this into multi-cloud.)
- **Crossplane and Argo CD compose, not compete.** Crossplane reconciles the resources it composed; Argo CD reconciles git. Crossplane outputs land in `platform/crossplane/`, Argo CD pulls from there.

## Compliance posture

Tier 3 is **the tier where compliance becomes a platform feature, not a compliance team artifact.** The Crossplane abstraction is itself a control objective: the XRD schema enforces engine, version, size, and storage standards; the Composition enforces encryption and IAM scoping; the dual CD pipeline enforces change-review on both the API surface and the consuming app. The standards in play:

- **SOC 2 Type 2 (mature, continuous).** The audit conversation shifts from "show me your controls" to "show me one query that returns the change history of this database for the past quarter." Audit logs streaming to a SIEM, claim-history in git, and Crossplane reconciliation events together produce that query. CC7.2 (system monitoring), CC8.1 (change management), and CC6.6 (logical access provisioning) all map to artifacts the framework produces by construction.
- **ISO 27001 + ISO 27017 (cloud) + ISO 27018 (PII in cloud).** ISO 27017 specifically wants documented controls for shared-responsibility split with cloud providers — the XRD/Composition pattern is the documentation.
- **PCI-DSS Level 1 or Level 2.** Full QSA audit, segmentation requirements (cardholder data environment isolation via NetworkPolicy + AppProject scope), Requirement 10 audit trails (the audit-log fleet stream), Requirement 6.5 secure development (the admission policies in Enforce mode).
- **HIPAA with full BAA program.** Multi-tenant database isolation via the XDatabase claim's `owner` field + AppProject RBAC. Audit trail § 164.312(b) satisfied by the same audit-log stream.
- **FedRAMP Moderate.** If selling to US government. NIST 800-53 control families (AC, AU, CM, IA, SC) all map to the framework's existing controls. The admission-policies `appproject-scope` VAP is exactly the AC-3 access enforcement control auditors want to see.
- **HITRUST CSF.** Common in healthcare ecosystem; harmonizes HIPAA + ISO 27001 + NIST. The framework's CUE-validated XRDs satisfy the configuration-management control families in one shot.
- **NIST CSF / NIST 800-53.** Often a prerequisite for selling into government-adjacent or critical-infrastructure customers.
- **GDPR Article 28** (processor obligations) and **CCPA/CPRA**. The claim/Composition pattern + audit logs are the technical substrate for "show me every place this data subject's records are processed."

The structural shift at this tier: **compliance evidence is generated as a side effect of the platform working correctly**, not assembled retroactively by a compliance team. The first time the auditor asks "show me how this database was approved before it landed in prod," the answer is `git log claims/guestbook-prod.yaml`, and the conversation is over in 30 seconds instead of three weeks.

### What lands alongside Crossplane

Tier 2's compliance writeup flagged that a strict reading of SOC 2 CC6.1/6.6/6.7 and ISO 27001 A.8.20/8.21/8.24 requires a **service mesh** on top of NetworkPolicy. Tier 3 is when that lands, and **the chosen mesh is Istio**. Service mesh and Crossplane arrive together at this tier because both are "the platform team finally has authority to set standards" decisions, and both close finding-classes the tier-2 audit produced.

Why Istio specifically over Linkerd or Cilium:

- **`AuthorizationPolicy` is rich enough to express the AppProject-vs-claim boundary in policy.** Tier 3's two-pipeline split (claims at sync-wave -2, chart at sync-wave 0) wants east-west authorization policies that match on workload identity *and* the namespace's owning team. Linkerd's policy surface is narrower, Cilium's is excellent but tied to the CNI choice.
- **Multi-cluster east-west gateway is what tier 4 needs.** Istio's multi-primary topology is the cleanest path to a single mesh spanning the regional seed clusters tier 4 introduces. Building tier 3 on a mesh that doesn't have a first-class multi-cluster story means rebuilding it at tier 4.
- **Envoy access logs are the per-call audit trail the auditor wants.** Linkerd's tap is good for live debugging; Envoy's structured access logs into Loki are what survives a SOC 2 evidence pull six months later.

The framework here doesn't ship the Istio install for review portability, but the tier-3 platform-Application set is where it would land — `platform/istio-base/`, `platform/istiod/`, and `platform/istio-cni/` next to `platform/cert-manager/`. Per-namespace `PeerAuthentication: STRICT` + per-claim `AuthorizationPolicy` are injected by the Composition pipeline at claim time so the app team never writes a mesh policy by hand.

## Honest gaps in this implementation

- **Connection Secret namespace bridge.** The bitnami postgresql Helm chart creates a Secret in the `databases` namespace. The app's `envFrom` reads from the app's own namespace. In production this gap is closed by the Composition adding a Secret-mirroring step (ExternalSecrets Operator + ClusterExternalSecret, or a function step that emits a same-namespace `Secret`). The claims here document this as a known wiring step rather than implementing the full mirror.
- **Schema migrations.** The claim provisions the database; nothing here promotes a schema change with the app image. Real production setups pair the claim with a Job-based migration step in the chart, gated by a Kargo `verification` step.

Tier 4 keeps the claim API identical and adds multi-cloud Compositions behind it.

## What's missing on purpose

- Single cloud, single region. Tier 4 introduces the multi-cloud and per-region story without changing the claim shape.
- No fleet-aware ApplicationSet generators. Tier 4 swaps the list generator for a cluster generator.

Longer narrative in [`NARRATIVE.md`](NARRATIVE.md).
