# demo: Helm + Kargo + Argo CD, three environments

Self-contained tier. One chart, three env overlays, Kargo for promotion,
Argo CD for sync. Uses the **rendered-manifests pattern** — Kargo runs
`helm template` per env and commits the output to `env/<env>` branches;
Argo CD only ever applies plain Kubernetes YAML.

## Layout

```
demo/
├── argocd/
│   ├── kustomization.yaml          # bootstrap entrypoint
│   ├── projects/demo.yaml          # AppProject scoped to demo namespaces
│   ├── apps/kargo-pipelines.yaml   # Argo CD app reconciling demo/kargo/
│   └── applicationsets/guestbook.yaml  # generates one App per env
├── charts/guestbook/               # the chart (single chart, multi-env values)
├── env/                            # per-env values overlays
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   └── values-prod.yaml
├── kargo/                          # Kargo control plane CRs
│   ├── projects/
│   ├── warehouses/guestbook.yaml
│   ├── analysis-templates/
│   ├── stages/{dev,staging,prod}.yaml
│   └── kustomization.yaml
└── rendered/                       # Kargo writes here on env branches
    ├── dev/
    ├── staging/
    └── prod/
```

## Promotion flow

```
new image hits gcr.io/google-samples/hello-app
        │
        ▼
Warehouse discovers freight
        │
        ▼  (autoPromotion)
Stage: dev
  ├─ helm-update-image  (writes digest to env/values-dev.yaml)
  ├─ helm-template      (renders chart)
  ├─ git-commit + push  (rendered/dev/manifests.yaml on env/dev branch)
  ├─ argocd-update      (waits for guestbook-demo-dev App Healthy)
  └─ verification       (http-probe against the dev Service)
        │
        ▼  (manual click)
Stage: staging        ← same steps, env=staging
        │
        ▼  (manual click)
Stage: prod           ← same steps, env=prod
```

## Bring it up

### 1. Argo CD side

```bash
kubectl apply -k demo/argocd/
```

Lands the AppProject + ApplicationSet (3 child Apps) + the
`kargo-pipelines-demo` App that reconciles the Kargo CRs. Apps will
sit `OutOfSync` until Kargo runs at least one promotion (the env
branches don't have rendered manifests yet).

### 2. Kargo side

Either let `kargo-pipelines-demo` reconcile from git (option above), or
paste the Kargo CRs directly into the Akuity Kargo UI:

```bash
kubectl apply -k demo/kargo/
```

### 3. First promotion

```bash
# Trigger via Akuity Kargo UI:
#   Project: kargo-demo → Warehouse: guestbook → "Refresh"
# discovers freight, dev auto-promotes, staging/prod await human click.
```

After dev runs, `env/dev` branch will have `demo/rendered/dev/manifests.yaml`
and the `guestbook-demo-dev` Argo CD App will sync.

## Cluster prerequisites

- Argo CD (or an Akuity instance) with a workload cluster registered as `demo`
- Kargo controller running (Akuity ships it; for self-hosted, install separately)
- Traefik with `traefik-gateway` in the `traefik` namespace, accepting routes
  from namespaces labelled `routes-from: business`

## What this shows

The same shape as tier 1, minus platform overhead (no kube-prometheus-stack,
no Argo Rollouts, no canary, no cert-manager). Smallest viable footprint
for the rendered-manifests promotion pattern with three real environments.
