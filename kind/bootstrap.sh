#!/usr/bin/env bash
# Bootstrap a local kind cluster with the prerequisites the demo / tier 1
# charts need: Gateway API CRDs + Traefik. Idempotent — safe to re-run.
#
# After this completes:
#   - `kubectl --context kind-demo get nodes` works
#   - http://localhost reaches Traefik (404 until an HTTPRoute attaches)
#   - The cluster is ready to be registered with Akuity via the agent
#     install command from the Akuity UI ("Add Cluster")
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing dependency: $1" >&2
    exit 1
  }
}

require kind
require kubectl
require helm

# 1. Cluster ----------------------------------------------------------
if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' already exists, skipping create"
else
  echo "creating kind cluster '${CLUSTER_NAME}'"
  kind create cluster --config "${SCRIPT_DIR}/cluster.yaml"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

# 2. Gateway API CRDs -------------------------------------------------
# Standard channel includes HTTPRoute, Gateway, GatewayClass, ReferenceGrant.
# Install before Traefik so the kubernetesGateway provider can register.
echo "installing Gateway API CRDs (standard channel v1.2.0)"
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# 3. Traefik ----------------------------------------------------------
echo "installing Traefik"
helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update traefik >/dev/null

kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --version 32.1.1 \
  --values "${SCRIPT_DIR}/traefik-values.yaml" \
  --wait

# 4. Summary ----------------------------------------------------------
cat <<EOF

cluster ready.

next steps:
  1. register this cluster with Akuity:
       Akuity UI → Clusters → Add Cluster → name it (e.g. 'kind-demo')
       copy the agent install command and run it:
         kubectl apply -f <agent-install-url>

  2. update the demo Application to target the new cluster name:
       demo/argocd/apps/guestbook.yaml → spec.destination.name: <name>
     (or keep 'demo' if you registered it under that name)

  3. push to git, Akuity syncs, the demo lands at:
       http://guestbook-demo.local
       (add to /etc/hosts: 127.0.0.1 guestbook-demo.local)
EOF
