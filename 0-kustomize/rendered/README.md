# `rendered/`

This is where Kargo writes the output of each promotion. The shape on disk is `rendered/<env>/manifests.yaml`, but the actual files only ever live on the per-env branches (`env/dev`, `env/staging`, `env/prod`). On `main` you'll only see the `.gitkeep` placeholders that keep the directory visible.

That's deliberate. Argo CD reads the env branch and applies plain YAML without re-rendering — the bytes that ran in dev are the same bytes that run in prod. Each env branch's `git log` is also the literal deploy history for that environment, which makes rollback (`git revert` on the branch) clean.

For the full pattern walkthrough: [`docs/rendered-manifests-pattern.md`](../docs/rendered-manifests-pattern.md).
