# The rendered-manifests pattern

The single most important pattern in this repo. Every tier uses it. Each tier README mentions it; this page is the canonical explanation that those READMEs link to.

## The claim

**The bytes that ran in dev are the bytes that run in prod.** No re-rendering between environments. The PR diff on a promotion is the literal set of Kubernetes API objects changing — not a values change, not a chart upgrade, not a kustomize patch.

## How it works

```
                Author's commit (chart, kustomize base, or claim)
                                   │
                                   ▼
                          ┌────────────────┐
                          │  Kargo Stage   │
                          │  (CI render)   │
                          └────────┬───────┘
                                   │
                  helm template / kustomize build / cue export
                                   │
                                   ▼
                       env/<stage> branch (rendered YAML)
                                   │
                                   ▼
                          Argo CD Application
                          (path: rendered/<stage>)
                                   │
                                   ▼
                          kubectl apply (plain YAML)
```

Every promotion runs the renderer in CI, commits the output to an env-specific git branch, and Argo CD applies it without re-rendering. The git ref is the freight identity.

## Why it wins

- **Reviewable promotions.** Reviewers see actual API objects in the PR — not "image tag bumped from x to y", but every NetworkPolicy, every label, every resource limit that's about to change.
- **No template drift between environments.** A chart upgrade lands in dev's render only; staging's bytes don't move until Kargo promotes them.
- **Compliance evidence is in git.** Every change to production is a commit on an env branch. SOC 2 evidence is `git log env/prod`.
- **Argo CD never runs the renderer.** No Helm template hooks, no kustomize plugins on the cluster, no CMP plugin to operate. Argo CD just applies YAML.

## What it costs

- **One more CI step.** Every promotion runs `helm template` (or `kustomize build`, or `cue export`) and pushes a commit. Adds ~10–60 seconds per promotion depending on chart size.
- **Bigger git repo.** Each env branch carries a complete rendered YAML tree. Manageable for tens of apps; needs sharding past low hundreds.
- **Two-source-of-truth surface.** Authors edit `main`; rendered output lands on env branches. Tooling needs to point reviewers at the right branch when they ask "what's in prod right now."

## When NOT to use it

- **Image-tag-only promotions on a single chart.** If the only thing that ever changes is the image tag on one Deployment, hydrating the full chart on every promotion is overkill. A values-only promotion is fine.
- **Charts smaller than a single page of YAML.** The reviewer benefit doesn't compound until there's enough rendered YAML to actually obscure the change.
- **Two environments only, on the same cluster.** Drift surface is small; the operational cost of an env branch per stage isn't repaid.

## How each tier uses it

| Tier | Renderer | Hydrated branch path |
|---|---|---|
| 0 | `kustomize build` | `env/{dev,staging,prod}` → `rendered/<env>/manifests.yaml` |
| 1 | `helm template` + values overlay | same |
| 2 | `helm template` (Terraform is out-of-band) | same |
| 3 | `helm template` + claim sync (claims via separate AppSet) | same |
| 4 | `helm template` per region | `env/{dev,staging,prod-us-east,prod-eu-west,prod-ap-southeast}` |

## References

- Akuity blog: https://akuity.io/blog/the-rendered-manifests-pattern
- Reference impl: https://github.com/akuity/kargo-rendered-branches
