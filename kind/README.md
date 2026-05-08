# kind: local cluster registered with Akuity

Spins up a single-node kind cluster preloaded with Gateway API + Traefik,
ready to be registered with Akuity as a workload cluster. Once registered,
the demo Application (and tier 1 ApplicationSet, if you point it here)
deploys via the Akuity hosted Argo CD just like a real cluster.

## Prerequisites

- Docker (kind runs each node as a container)
- `kind` ≥ v0.24
- `kubectl`
- `helm` ≥ v3.13

## Bring it up

```bash
./kind/bootstrap.sh
```

That:
1. Creates kind cluster `demo` with host port 80/443 forwarded into the cluster
2. Installs Gateway API CRDs (standard channel v1.2.0)
3. Installs Traefik with `kubernetesGateway` provider, pinned to NodePort
   30080/30443 to match the cluster port mappings

Idempotent — re-run anytime.

## Register with Akuity

The agent install URL is per-cluster and only Akuity can issue it:

1. Akuity UI → **Clusters** → **Add Cluster**
2. Name it (e.g. `kind-demo` or replace your existing `demo` registration)
3. Copy the install command shown — looks like:
   ```bash
   kubectl apply -f https://<your-instance>.cd.akuity.cloud/api/agent/.../install.yaml
   ```
4. Run it against the kind cluster (already your current context after bootstrap):
   ```bash
   kubectl apply -f <agent-install-url>
   ```
5. Akuity Cluster page should flip to **Successful** within ~60s

## Point an Application at the new cluster

The demo Application currently targets `destination.name: demo`. If you
named the kind registration differently:

```yaml
# demo/argocd/apps/guestbook.yaml
destination:
  name: kind-demo        # match the name from step 2 above
  namespace: guestbook-demo
```

Push the change → Akuity syncs.

## Reach the running app

Traefik listens on `http://localhost`. The demo's HTTPRoute uses host
`guestbook-demo.local` — add a /etc/hosts entry:

```
127.0.0.1   guestbook-demo.local
```

Then:

```bash
curl http://guestbook-demo.local
# Hello, world!
# Version: 0.0.1
# Hostname: guestbook-...
```

## Tear it down

```bash
kind delete cluster --name demo
```

Removes the cluster entirely. The Akuity-side cluster registration stays
until you delete it from the UI; until then it'll show **Disconnected**.
