# 006 — Connection Secret namespace bridge for XDatabase claims

## Status

Accepted; partial implementation deferred.

## Context

Tier 3+ uses Crossplane to compose an `XDatabase` claim into a managed database. The current Composition (`framework/platform/compositions/database-aws.cue` and the gcp/onprem variants) creates a provider-helm `Release` of bitnami/postgresql in the `databases` namespace. Bitnami's chart in turn creates a Kubernetes Secret of the form `<release>-postgresql` carrying the database credentials.

The consuming guestbook chart at `<tier>/charts/guestbook/templates/deployment.yaml` reads its DB credentials via:

```yaml
envFrom:
  - secretRef:
      name: {{ .Values.database.secretName }}
```

`envFrom` only resolves Secrets in the **same namespace** as the Pod. The Composition produces the Secret in `databases`; the Pod runs in `guestbook-<env>`. There is no working path between them today.

The tier 3 README acknowledges this explicitly as a known gap. This ADR records the decision about how it will be closed.

## Decision

The Composition is responsible for **mirroring** the connection Secret from the `databases` namespace into the consuming app's namespace via External Secrets Operator (`ExternalSecret` or `ClusterExternalSecret`). The mirror is part of the Composition pipeline, not a hand-applied YAML.

Concretely:

1. Each XDatabase Composition pipeline gains an additional patch-and-transform step that emits a `ClusterExternalSecret` resource. The `ClusterExternalSecret` watches a label selector matching the consuming chart's namespace (e.g. `kubernetes.io/metadata.name: guestbook-<env>`) and projects the bitnami-created Secret into that namespace as `guestbook-postgres-<env>`.
2. ESO is installed on every cluster that will run an XDatabase claim — already the case at tier 3+ since `platform/external-secrets/install.yaml` is wired by every tier's `argocd/apps/` directory. (TODO: confirm and add an `argocd/apps/external-secrets.yaml` Application if missing.)
3. The naming convention `guestbook-postgres-<env>` is enforced by the Composition's patch — the same patch that propagates `spec.name` into `metadata.name`. The chart's `values-<env>.yaml` therefore declares `database.secretName: guestbook-postgres-<env>` and the two never drift.

Alternatives considered:

- **Cross-namespace `secretRef`.** Not supported by Kubernetes; rejected.
- **Bind the Pod's ServiceAccount to a `Role` in the `databases` namespace.** Works for Pods that fetch the Secret programmatically (via the API), but `envFrom` does not work that way. Rejected.
- **Move the bitnami release into the app's namespace.** Conflates platform-team-owned resources with app-team-owned resources; tier-3+ explicitly separates the two. Rejected.

## Consequences

- The connection Secret bridge is part of the Crossplane Composition source of truth (CUE in `framework/platform/compositions/`). Customers who copy the framework get the bridge for free.
- ESO is now a hard dependency at tier 3+. Tier 2 customers do not run ESO (the wild-west TF module writes the Secret directly into the app namespace). Tier 3 onboarding requires ESO install as a prerequisite.
- The ESO `ClusterExternalSecret` is a cluster-scoped resource. AppProject `clusterResourceWhitelist` at tier 3+ must include it; verify after wiring.

## Implementation status

Not yet wired. The current Compositions still create the bitnami release without the secret-mirror step. Tier 3 README documents this as a known gap. The fix is to add the patch-and-transform step in CUE; rendered Composition YAML then naturally carries the ESO resource.

Expected effort: one CUE file change in `framework/platform/compositions/database-{aws,gcp,onprem}.cue` (add a `clusterExternalSecret` resource alongside the existing `release` resource), plus a verification pass that the rendered output applies cleanly against an ESO-installed cluster.

## References

- `3-crossplane+helm/README.md` "Honest gaps in this implementation"
- ESO `ClusterExternalSecret` API: <https://external-secrets.io/latest/api/clusterexternalsecret/>
- Bitnami postgresql chart secret naming: `<release>.fullname-postgresql`
