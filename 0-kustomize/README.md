# Tier 0: Kustomize + Kargo

The simplest possible GitOps shape that still has a real promotion story.

A single Helm-free guestbook app, a Kustomize base with three env overlays, two component workloads (ingress-nginx and cert-manager) installed via Argo CD, and a three-stage Kargo pipeline (dev → staging → prod) that promotes the **rendered** Kubernetes manifests across env branches via `kustomize build`.

The hydrated output lands on `env/{dev,staging,prod}` branches; Argo CD reconciles those branches; promotion PRs show literal API objects diffing.

## Layout

```
0-kustomize/
├── apps/guestbook/
│   ├── base/                       # deployment, service, namespace, networkpolicy, pdb, serviceaccount
│   └── envs/{dev,staging,prod}/    # per-env image tag + namespace patch
├── argocd/
│   ├── projects/{business,platform}.yaml
│   ├── applicationsets/business-apps.yaml
│   └── apps/{ingress-nginx,cert-manager,kargo-pipelines}.yaml
├── kargo/
│   ├── projects/{kargo-simple,project-config}.yaml
│   ├── warehouses/guestbook.yaml             # subscribes to GHCR image
│   ├── stages/{dev,staging,prod}.yaml        # step-based promotion (modern Kargo v1.x)
│   └── analysis-templates/guestbook-http-probe.yaml
├── platform/
│   ├── ingress-nginx/{namespace,values}.yaml
│   └── cert-manager/{namespace,cluster-issuer,values}.yaml
└── rendered/{dev,staging,prod}/    # Kargo writes hydrated manifests here per env branch
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
