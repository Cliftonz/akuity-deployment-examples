# demo: minimal Helm + Argo CD

Smallest end-to-end shape in this repo. One chart, one Application, one
namespace. No Kargo. No progressive delivery. No platform components.

## Layout

```
demo/
├── argocd/
│   ├── kustomization.yaml      # bootstrap entrypoint
│   ├── projects/demo.yaml      # AppProject scoped to guestbook-demo ns
│   └── apps/guestbook.yaml     # Application that renders the chart
└── charts/guestbook/
    ├── Chart.yaml
    ├── values.yaml             # single values file — no per-env overlays
    └── templates/              # ns + sa + deploy + svc + httproute + pdb + netpol
```

## What gets deployed

`helm template demo/charts/guestbook` produces:

| Kind | Name | Notes |
| --- | --- | --- |
| Namespace | `guestbook-demo` | Pod Security Admission `restricted`, `routes-from: business` label |
| ServiceAccount | `guestbook` | `automountServiceAccountToken: false` |
| Deployment | `guestbook` | 1 replica, hello-app:0.0.1, hardened securityContext |
| Service | `guestbook` | ClusterIP :80 → :3000 |
| HTTPRoute | `guestbook` | Gateway API attach to `traefik/traefik-gateway` |
| PodDisruptionBudget | `guestbook` | minAvailable: 1 |
| 3× NetworkPolicy | `guestbook-*` | default-deny + allow-ingress-from-traefik + allow-egress-DNS |

## Deploy

```bash
# Bootstrap once into your Argo CD instance:
kubectl apply -k demo/argocd/

# Argo CD picks up the Application and renders the chart on every sync.
# Push a values change → Argo CD detects → Sync → cluster updated.
```

## Cluster prerequisites

- Argo CD installed (or an Akuity instance) with a cluster registered as `demo`
- Traefik installed with `traefik-gateway` Gateway in the `traefik` namespace,
  with a listener that accepts routes from namespaces labelled `routes-from: business`
- (Optional) ingress-only mode: set `httpRoute.enabled: false` in
  `charts/guestbook/values.yaml` to skip the Gateway API attach

## What this is for

A starter scaffold. Anyone landing on this repo who wants to see "Helm
chart deployed via Argo CD" without the Kargo / canary / multi-env
machinery starts here. Progresses naturally to tier 1 (`1-helm/`) once
the team needs more than one environment.
