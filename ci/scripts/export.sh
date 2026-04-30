#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "${script_dir}/../.." && pwd)"
framework_dir="${root_dir}/framework"

cluster=""
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      echo "Usage: $0 [--cluster NAME] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# Render output lives at the repo root: apps/<cluster>/ for per-cluster
# claims and platform/crossplane/ for shared XRDs+Compositions. For dry-run
# drift checks we render into a tempdir and diff.
apps_out="${root_dir}/apps"
platform_out="${root_dir}/platform/crossplane"
cleanup_dir=""

if [[ "${dry_run}" == "true" ]]; then
  cleanup_dir="$(mktemp -d)"
  apps_out="${cleanup_dir}/apps"
  platform_out="${cleanup_dir}/platform/crossplane"
  mkdir -p "${apps_out}" "${platform_out}"
fi

cd "${framework_dir}"

if [[ -n "${cluster}" ]]; then
  cue export ./export/ -t cluster="${cluster}" -o "${cleanup_dir:-${root_dir}/.cue-render}/${cluster}.yaml"
else
  cue export ./export/ -o "${cleanup_dir:-${root_dir}/.cue-render}/all.yaml"
fi

if [[ "${dry_run}" == "true" ]]; then
  if [[ -d "${root_dir}/apps" || -d "${root_dir}/platform/crossplane" ]]; then
    diff -ru "${root_dir}/apps" "${apps_out}" || true
    diff -ru "${root_dir}/platform/crossplane" "${platform_out}" || true
  else
    echo "apps/ and platform/crossplane/ do not exist; generated output is in ${cleanup_dir}" >&2
  fi
  rm -rf "${cleanup_dir}"
fi
