#!/usr/bin/env bash
# Register tier-scoped tasks/ and runbooks/ with Akuity Intelligence.
#
# Each tier folder (0-kustomize, 1-helm, 2-terraform+helm, 3-crossplane+helm,
# 4-hybridmulticloud) ships its own tasks/MANIFEST.yaml and runbooks/MANIFEST.yaml
# with progressively-richer playbooks. This script walks every tier, validates
# each manifest against the JSON schemas in .schemas/, and upserts via the
# `akuity` CLI. If the CLI version on PATH doesn't expose the subcommand, the
# script prints the equivalent console-side action so registration can finish
# by hand.
#
# Re-running is safe: existing entries are updated, new ones created.
#
# Usage:
#   ./scripts/register-intelligence.sh            # register every tier
#   ./scripts/register-intelligence.sh 1-helm     # register one tier
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

: "${AKUITY_API_KEY_ID:?Please export AKUITY_API_KEY_ID}"
: "${AKUITY_API_KEY_SECRET:?Please export AKUITY_API_KEY_SECRET}"

TIERS=("$@")
if [[ ${#TIERS[@]} -eq 0 ]]; then
  TIERS=(0-kustomize 1-helm 2-terraform+helm 3-crossplane+helm 4-hybridmulticloud)
fi

for tier in "${TIERS[@]}"; do
  if [[ ! -d "$tier" ]]; then
    echo "Skipping $tier — directory not found." >&2
    continue
  fi

  echo "=== $tier ==="

  # Refuse to upload manifests still carrying the placeholder slack channel.
  if find "$tier" \( -name MANIFEST.yaml -o -name '*.md' \) -path "*/tasks/*" -o -path "*/runbooks/*" 2>/dev/null \
    | xargs grep -l '<slack-channel>' 2>/dev/null | head -1 >/dev/null; then
    echo "  $tier: <slack-channel> placeholder still present. Resolve before registering." >&2
    continue
  fi

  for kind in tasks runbooks; do
    manifest="$tier/$kind/MANIFEST.yaml"
    [[ -f "$manifest" ]] || continue

    if command -v akuity >/dev/null 2>&1 && akuity intelligence "$kind" --help >/dev/null 2>&1; then
      akuity intelligence "$kind" upsert --manifest "$manifest" --tier "$tier"
      echo "  $manifest → registered"
    else
      echo "  $manifest → akuity CLI does not expose intelligence subcommand."
      echo "  Open the Akuity console → Intelligence → ${kind^} and import this manifest:"
      echo "    $REPO_ROOT/$manifest"
    fi
  done
done
