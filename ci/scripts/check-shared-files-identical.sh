#!/usr/bin/env bash
# Drift guard: every tier folder is intentionally self-contained, so files
# that ARE shared across tiers (AppProjects, platform component installs,
# Kargo Project bootstraps) are duplicated on purpose. This script fails
# when those duplicates drift apart so silent regressions are caught in CI.
#
# The right fix when this script fails is almost always "make all the
# copies match again" — never "centralize into framework/", which would
# break the runnable-folder-per-tier demo.
#
# Usage:
#   ./ci/scripts/check-shared-files-identical.sh
# Exits 0 on no drift, 1 with a per-file diff summary on drift.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# Files that should be identical across the listed tiers. Format:
#   "<relative-path>:<tier>,<tier>,..."
# where <relative-path> is the path WITHIN each tier folder.
SHARED=(
  "argocd/projects/platform.yaml:1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "argocd/projects/business.yaml:1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  # Tier 0 attaches HTTPRoutes to the cluster's existing Traefik Gateway and
  # ships no platform Helm install of its own; tiers 1+ install Traefik via
  # the platform AppProject and share these files byte-for-byte.
  "platform/traefik/namespace.yaml:1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "platform/traefik/values.yaml:1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "platform/cert-manager/namespace.yaml:0-kustomize,1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "platform/cert-manager/cluster-issuer.yaml:0-kustomize,1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "platform/cert-manager/values.yaml:0-kustomize,1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "kargo/projects/kargo-simple.yaml:0-kustomize,1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "kargo/projects/project-config.yaml:0-kustomize,1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "kargo/warehouses/guestbook.yaml:0-kustomize,1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "kargo/analysis-templates/guestbook-http-probe.yaml:0-kustomize,1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "argocd/configmaps/argocd-cm.yaml:1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "argocd/configmaps/argocd-notifications-cm.yaml:1-helm,2-terraform+helm,3-crossplane+helm,4-hybridmulticloud"
  "akuity/audit-log-stream.yaml:1-helm,2-terraform+helm,3-crossplane+helm"
  "akuity/README.md:1-helm,2-terraform+helm,3-crossplane+helm"
  "platform/admission/no-latest-tag.yaml:1-helm,2-terraform+helm"
  "platform/admission/security-context.yaml:1-helm,2-terraform+helm"
  "platform/admission/appproject-scope.yaml:1-helm,2-terraform+helm"
)

fail=0

for entry in "${SHARED[@]}"; do
  relpath="${entry%%:*}"
  tiers="${entry##*:}"
  IFS=',' read -r -a tier_array <<< "$tiers"

  first="${tier_array[0]}/$relpath"
  if [[ ! -f "$first" ]]; then
    echo "  SKIP: $relpath — missing in $first (declared shared)"
    continue
  fi

  for tier in "${tier_array[@]:1}"; do
    other="$tier/$relpath"
    if [[ ! -f "$other" ]]; then
      echo "  FAIL: $relpath — missing in $tier (expected identical to $first)"
      fail=1
      continue
    fi
    if ! diff -q "$first" "$other" >/dev/null 2>&1; then
      echo "  DRIFT: $relpath"
      echo "    $first"
      echo "    $other"
      diff -u "$first" "$other" | head -20 | sed 's/^/      /'
      fail=1
    fi
  done
done

if [[ $fail -eq 0 ]]; then
  echo "OK — all declared-shared files are byte-identical across tiers."
fi

exit $fail
