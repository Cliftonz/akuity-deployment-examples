# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Validation Commands

```bash
make validate                          # cue vet from framework/ — validate all CUE schemas
make export                            # render all clusters → apps/<cluster>/ + platform/crossplane/
make export-cluster CLUSTER=demo       # render YAML for a single cluster into apps/demo/
make apply CLUSTER=demo                # render + kubectl apply -R against current context
make diff                              # dry-run export and diff against existing apps/ + platform/crossplane/
make check-shared                      # drift guard for byte-identical files across tier folders
make clean                             # clear CUE caches (framework/cue.mod/pkg/, framework/cue.mod/usr/)
```

`make export` / `make apply` ships XRDs + Compositions (to `platform/crossplane/`) + claim CRs (to `apps/<cluster>/`) — target cluster needs Crossplane.

## Cluster Bootstrap

A fresh cluster needs Crossplane + provider-helm + provider-kubernetes
before it can apply rendered manifests. The included installer is
idempotent:

```bash
infrastructure/crossplane/install.sh      # install UXP + providers + functions
make export-cluster CLUSTER=demo          # render YAML for the demo cluster
make apply CLUSTER=demo                   # apply XRDs first, then everything else
```

CUE version is pinned to **v0.15.4** in `framework/cue.mod/module.cue`. Module path: `github.com/zclifton/k8-gitops-platform@v0`.

## Architecture

**Hub-and-spoke Crossplane model** with CUE-based validation and OCI artifact promotion.

- **Hub cluster** runs Crossplane (XRDs, Compositions, Providers) and provisions spoke clusters
- **Spoke clusters** (dev, staging, prod) consume pre-rendered manifests via Harness GitOps / ArgoCD
- **CUE** validates contracts and generates deterministic YAML at build time — no runtime CUE
- **Promotion flow**: Author claims → CI validates (`cue vet`) → CI renders (`cue export`) → commit rendered output to env branch → GitOps syncs to spoke

See `docs/architecture.md` for full design.

## Repository Layout

| Directory | Purpose |
| --- | --- |
| `framework/` | All CUE source. `cue vet` and `cue export` run from here. |
| `framework/platform/xrd/` | Crossplane XRDs (namespace, rbac, resourcequota, networkpolicy) — platform API schemas |
| `framework/platform/compositions/` | Crossplane Compositions mapping XRD claims → Kubernetes Objects |
| `framework/platform/policy/` | Tier-based policy constraints (quota limits, network policy defaults, Kyverno) |
| `framework/libs/tiers/` | Tier definitions (dev/staging/production) implementing `#TierConfig` contract |
| `framework/libs/k8s/` | Shared Kubernetes type schemas (metadata, namespace, rbac, resourcequota, networkpolicy) |
| `framework/composites/{cluster}/` | Per-cluster desired state as composite inputs (CUE) |
| `framework/export/` | CI entry point — `export/all.cue` aggregates all claims and renders manifests |
| `framework/functions/` | Crossplane composition functions |
| `apps/<cluster>/` | **Render output.** Per-cluster claim YAML grouped by kind. |
| `platform/crossplane/{xrds,compositions}/` | **Render output.** Cluster-shared XRDs + Compositions. |
| `platform/{external-secrets,kubescape,kyverno,headlamp}/` | Component workload installs (hand-authored, not rendered). |
| `0-kustomize/` | Tier-0 maturity demo: Kustomize + Kargo + Argo CD (guestbook). Self-contained. |
| `1-helm/` | Tier-1: Helm chart of the same scenario; Kargo `helm-template` + `helm-update-image`. |
| `2-terraform+helm/` | Tier-2: tier-1 chart + a deliberately-rough Terraform module that demonstrates wild-west infra provisioning. |
| `3-crossplane+helm/` | Tier-3: app team files `XDatabase` claims; the platform team owns the abstraction in `framework/`. |
| `4-hybridmulticloud/` | Tier-4: same claim API, multiple cloud Compositions, EnvironmentConfig-driven routing, regional Kargo gates. |
| `infrastructure/` | Version-pinned install manifests (Crossplane, ESO, Provider Helm, Provider Kubernetes) for hub bootstrap |
| `<tier>/NARRATIVE.md` (one per tier folder) | Customer-maturity tier narrative; each pairs with the matching `<N>-<name>/` folder. |
| `ci/scripts/` | Render + drift-guard scripts (see `ci/scripts/README.md`) |

## CUE Conventions

- All `cue` commands run from `framework/` (where `cue.mod/` lives).
- **Module-scoped imports only**: `"github.com/zclifton/k8-gitops-platform/libs/tiers"`, never file-relative
- **Single-module, multi-package** layout — each directory is a CUE package
- All XRDs use group `infra.k8`, version `v1alpha1`
- All resource names must match `^[a-z][a-z0-9-]*$`
- Tier values: `"dev"`, `"staging"`, `"production"`
- Provider values: `"rancher"`, `"eks"`, `"gke"`, `"aks"`
- Standard labels (`app.kubernetes.io/managed-by: k8-gitops-platform`, tier, cluster, owner) are enforced on all resources via `framework/libs/k8s/metadata.cue`

## Cluster-tier system (framework/)

> Note: this is the *cluster* tier system inside `framework/` (dev / staging / production). Not to be confused with the *maturity* tiers `0-kustomize/` … `4-hybridmulticloud/` at the repo root, which describe customer profiles.

Each cluster tier (`framework/libs/tiers/{tier}.cue`) implements `#TierConfig` with:

- **Resource quotas** — dev: 1cpu/1Gi req, 2cpu/2Gi limit; staging: 2/2Gi, 4/4Gi; prod: 4/4Gi, 8/8Gi
- **Kyverno mode** — dev: `Audit`; staging/prod: `Enforce`
- **Network policy** — all tiers deny ingress/egress by default, allow DNS; staging/prod also allow monitoring

## Adding a New Cluster (framework-internal)

1. Create `framework/composites/{cluster-name}/` with `cluster.cue` plus per-resource files (`namespaces.cue`, `rbac.cue`, `resourcequotas.cue`, `networkpolicies.cue`, `databases.cue`, etc.)
2. Update `framework/export/all.cue` to import and aggregate the new cluster
3. Validate: `make validate && make export-cluster CLUSTER={cluster-name}`

## Key Rules

- **Never hand-edit `apps/` or `platform/crossplane/`** — both are CI-generated rendered YAML.
- `platform/{external-secrets,kubescape,kyverno,headlamp}/` and the empty plan dirs (`charts/`, `env/`, `kargo/`) ARE hand-authored — leave the rendered output paths alone.
- All CUE imports use the full module path
- Claims reference cluster metadata via `let C = cluster` pattern
- Infrastructure components (Kyverno, ESO) are installed via Crossplane Provider Helm; only Crossplane itself is installed directly
