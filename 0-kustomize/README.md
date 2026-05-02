# Tier 0: Kustomize + Kargo

The simplest possible GitOps shape that still has a real promotion story.

A single Helm-free guestbook app, a Kustomize base with three env overlays, two component workloads (ingress-nginx and cert-manager) installed via Argo CD, and a three-stage Kargo pipeline (dev → staging → prod) that promotes the **rendered** Kubernetes manifests across env branches via `kustomize build`.

The hydrated output lands on `env/{dev,staging,prod}` branches; Argo CD reconciles those branches; promotion PRs show literal API objects diffing.

## Layout

```
0-kustomize/
├── apps/guestbook/
│   ├── base/                       # deployment, service, namespace, networkpolicy, pdb, serviceaccount, httproute
│   └── envs/{dev,staging,prod}/    # per-env image tag + namespace + hostname patches
├── argocd/
│   ├── projects/{business,platform}.yaml
│   ├── applicationsets/business-apps.yaml
│   └── apps/{cert-manager,kargo-pipelines}.yaml
├── kargo/
│   ├── projects/{kargo-simple,project-config}.yaml
│   ├── warehouses/guestbook.yaml             # subscribes to gcr.io/google-samples/hello-app
│   ├── stages/{dev,staging,prod}.yaml        # step-based promotion (modern Kargo v1.x)
│   └── analysis-templates/guestbook-http-probe.yaml
├── platform/
│   └── cert-manager/{namespace,cluster-issuer,values}.yaml
└── rendered/{dev,staging,prod}/    # Kargo writes hydrated manifests here per env branch
```

## Ingress: Gateway API + existing Traefik Gateway

The cluster runs Traefik with Gateway API support; tier 0 attaches to the existing `traefik/traefik-gateway` via per-namespace `HTTPRoute` resources rather than installing its own ingress controller. Cross-namespace attachment (HTTPRoute in `guestbook-<env>` → Gateway in `traefik`) requires the listener's `allowedRoutes.namespaces` to permit it. The guestbook namespaces ship the label `routes-from: guestbook`; the listener uses `from: Selector` matching that label.

If the cluster's Gateway listener is more restrictive (default `from: Same`), patch it once:

```bash
kubectl patch gateway traefik-gateway -n traefik --type=merge -p '{
  "spec": {
    "listeners": [{
      "name": "web",
      "port": 8000,
      "protocol": "HTTP",
      "allowedRoutes": {
        "namespaces": {
          "from": "Selector",
          "selector": { "matchLabels": { "routes-from": "guestbook" } }
        }
      }
    }]
  }
}'
```

Verify acceptance:

```bash
kubectl get httproute -n guestbook-dev guestbook \
  -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
# Expect: True
```

## Apply

```bash
kubectl apply -k 0-kustomize/argocd/
```

This bootstraps the AppProjects, the ApplicationSet, the platform component apps, and a `kargo-pipelines` Application that pulls in everything under `kargo/`. Argo CD takes it from there.

## What this tier shows

- **GitOps without templating overhead.** Kustomize handles per-env differences with patches; no Helm to learn.
- **Rendered-manifests promotion.** Kargo's promotion steps run `kustomize-build` in CI and commit the output to `env/<stage>` branches. Argo CD applies plain YAML; PR diffs are literal Kubernetes objects, not values changes.
- **Component vs. business workload separation.** ingress-nginx and cert-manager get their own Argo CD `AppProject` and never go through Kargo. Guestbook does.

## Changes from the base Kargo Quickstart

The assignment asks for at least one beneficial deviation from the stock tutorial. Several here, each with a concrete reason:

- **Digest-pinned freight, not tags.** `kustomize-set-image` uses `imageFrom(vars.imageRepo).Digest` instead of the discovered tag. Re-tagging an already-approved digest in the registry no longer slips through; freight identity is the bytes, not the label.
- **Stage verification gate.** Each Stage runs the [`guestbook-http-probe`](kargo/analysis-templates/guestbook-http-probe.yaml) `AnalysisTemplate` after `argocd-update` reports synced. Five 2xx responses against the in-cluster Service before freight becomes eligible upstream — "Argo CD says synced" is not the same as "the app actually works." Drop-in replacement for a Prometheus query in a real environment.
- **Scoped AppProjects, not `*/*`.** [`business`](argocd/projects/business.yaml) and [`platform`](argocd/projects/platform.yaml) enumerate their `clusterResourceWhitelist` and `destinations` explicitly. A merged PR adding `apps/guestbook-evil/envs/dev/` or a sneaky `ClusterRoleBinding` has nowhere to land.
- **Auto-promote at the ProjectConfig level, not per-Stage annotations.** Kargo v1.x moved promotion policy onto [`ProjectConfig`](kargo/projects/project-config.yaml). Only `dev` is listed; staging and prod default to manual.
- **Sync window with timezone pinning.** [`platform.yaml`](argocd/projects/platform.yaml) freezes Friday 22:00 ET → Monday 10:00 ET in `America/New_York`. UTC schedules drift twice a year with DST and put the freeze in the wrong place. `manualSync: true` so on-call can break it for a real fire.
- **Gateway API attach instead of a new ingress controller.** The cluster already runs Traefik with Gateway API; tier 0 ships per-namespace `HTTPRoute` resources that attach to the existing `traefik/traefik-gateway` rather than installing ingress-nginx. One less component, one less upgrade path.
- **Client-side apply on the business ApplicationSet.** K8s 1.30+ added `.status.terminatingReplicas` to `Deployment` and Argo CD's bundled OpenAPI schema doesn't yet know that field; SSA diff blows up parsing the live resource. Comment in [`business-apps.yaml`](argocd/applicationsets/business-apps.yaml) records the why so the next person doesn't "fix" it back.
- **`prune: false` on the Kargo CR Application.** [`kargo-pipelines.yaml`](argocd/apps/kargo-pipelines.yaml) refuses to self-heal Kargo CRs. A transient render error producing empty output would otherwise prune live Stages and take freight history with them. Drift here gets a manual sync.
- **App-of-apps for the Kargo control plane.** Argo CD reconciles the entire `kargo/` directory through a single Application, so changing the promotion model is a regular GitOps PR — not `kubectl apply`.

## Assumptions

- **Cluster runs Traefik with Gateway API enabled** and exposes a `traefik/traefik-gateway` Gateway. If yours doesn't, swap the [`HTTPRoute`](apps/guestbook/base/httproute.yaml) for an `Ingress` and add an ingress controller to the platform AppProject.
- **Argo CD and Kargo run in Akuity** (managed control plane). The cluster has the Akuity Agent installed and an outbound tunnel back. The bootstrap `kubectl apply -k argocd/` lands the AppProjects, ApplicationSet, and platform Apps; Akuity-hosted Argo CD takes it from there.
- **Single workload cluster.** ApplicationSet uses a list generator over envs, not a cluster generator. The multi-cluster fan-out lives in tier 4.
- **`env/<stage>` branches are created by Kargo on first promotion.** The `git-clone` step uses `create: true`, so the branches don't need to pre-exist. The `rendered/{dev,staging,prod}/` directories on `main` are placeholders; the real hydrated YAML lives on the env branches after the first promote.
- **Public demo image (`gcr.io/google-samples/hello-app`).** No registry credentials are wired. Tags `1.0` and `2.0` exist; `semverConstraint: ">=1.0.0"` keeps any future mutable tags (`latest`, `canary`) out of the discovery set.
- **Founders are the only operators.** No SSO, no audit logs, no per-AppProject role bindings — those are tier 1 once a real auditor appears. See [`NARRATIVE.md`](NARRATIVE.md) for the trigger that moves this tier forward.

## Compliance posture

A tier-0 company is mostly **pre-compliance**. They're small enough that no auditor is asking yet, and the technical controls a SOC 2 firm would expect (SSO with role bindings, audit-log SIEM, change-review evidence) aren't in place — see "What's missing on purpose." The compliance work that *does* show up at this stage:

- **Vendor security questionnaires.** A first enterprise prospect sends a 200-row spreadsheet asking about backup, encryption, access control, incident response. The CTO answers it themselves over a weekend.
- **Privacy basics.** A privacy policy on the marketing site. A DPA template if any EU customers ask. CCPA disclosure if any California ones do.
- **Pre-SOC 2 prep.** Sometimes the company starts collecting screenshots and policies 12 months before the first SOC 2 Type 1 — the tier-1 trigger.
- **Sector exceptions.** If the company is in healthcare, HIPAA shows up on day one (BAA with the cloud provider, encryption-at-rest); if processing card data directly, PCI-DSS does (most use Stripe and skip).

Tier 0 is not the tier where compliance fails — it's the tier where the *absence* of compliance machinery is appropriate. Adding SOC-2-grade controls at five engineers is overhead without a corresponding ask, and burns the runway for shipping.

## What's missing on purpose

- No Helm. Tier 1 introduces it.
- No external infra (databases, etc.). Tier 2 introduces it.
- No Crossplane abstractions. Tier 3 introduces it.
- No multi-cloud or per-region routing. Tier 4 introduces it.

Longer narrative in [`NARRATIVE.md`](NARRATIVE.md).
