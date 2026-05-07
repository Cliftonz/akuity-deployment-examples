# demo: minimal Helm + Argo CD

Smallest end-to-end shape in this repo. One chart, one Application, one
namespace. No Kargo, no canary, no platform components.

## Layout

```
demo/
├── argocd/
│   ├── kustomization.yaml      # bootstrap entrypoint
│   ├── projects/demo.yaml      # AppProject scoped to guestbook-demo
│   └── apps/guestbook.yaml     # Application that renders the chart
└── charts/guestbook/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/              # ns + deploy + svc + httproute
```

## Deploy

```bash
kubectl apply -k demo/argocd/
```

Argo CD picks up the Application and renders the chart on every sync.

## Cluster prerequisites

- Argo CD (or an Akuity instance) with the workload cluster registered as `demo`
- Traefik with `traefik-gateway` in the `traefik` namespace, accepting routes
  from namespaces labelled `routes-from: business`
- Set `httpRoute.enabled: false` in `charts/guestbook/values.yaml` if the
  cluster has no Gateway API
