# `ci/scripts/`

Shell scripts called by the Makefile. Trimmed down to what the take-home walkthrough actually uses; the framework-legacy scripts (raw-fallback render mode, golden-file regressions, OCI publish, Kyverno chainsaw tests, kind e2e, CRD-to-CUE generators, infra-manifest freshness checks, XRD doc generator) were removed.

| Script | What it does | Triggered by |
|---|---|---|
| `check-shared-files-identical.sh` | Drift guard. Diffs files declared identical across tier folders, fails CI on divergence. The maintenance discipline that makes self-contained tier folders viable. | `make check-shared` |
| `split-manifests.sh` | YAML-stream → per-resource files split, used by every `make export*` target. | Every render path |
| `export.sh` | Wraps `cue export` with a `--dry-run` mode for the drift-check target. | `make diff` |

## What an SE reviewing this take-home would run

```bash
make validate                       # cue vet ./... from framework/
make export-cluster CLUSTER=demo    # render the framework's XRDs/Compositions
make check-shared                   # drift guard across tier folders
```

Everything tier-specific (`kubectl apply -k <tier>/argocd/`, `helm template <chart>`, `terraform apply` at tier 2) lives in the per-tier `README.md` files and does not require these scripts.

# `scripts/` (repo root)

Single script:

- **`scripts/register-intelligence.sh`** — walks each tier's `tasks/MANIFEST.yaml` and `runbooks/MANIFEST.yaml`, validates them against `.schemas/`, and upserts them via the `akuity` CLI. Central to the Akuity Intelligence demo motion. Not Makefile-wired because it requires Akuity API credentials in env vars and is intended to be run manually or by CI with secrets.
