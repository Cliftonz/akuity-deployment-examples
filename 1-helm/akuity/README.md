# Akuity-managed control-plane resources

Tier 1 introduces the first artifacts that live at the **Akuity organization level**, not on any one workload cluster. These are managed via the Akuity console / API, not via `kubectl`.

| File | Purpose |
|---|---|
| `audit-log-stream.yaml` | Configures Akuity Audit Log → SIEM webhook. SOC 2 evidence pipeline. |

## How these get applied

Two paths:

1. **Console.** Open the Akuity console → Organization → Streaming Destinations → Import → paste this YAML.
2. **CLI.** `akuity org streaming-destination apply -f audit-log-stream.yaml`.

Argo CD does NOT reconcile these — they're not Kubernetes resources. The repo holds them as the source of truth for what the org *should* be configured to do, and the Akuity console is where the configuration runs.

## Sample SIEM destination secret

The webhook needs a token. Create it via ESO from the corporate secret store:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: audit-log-siem-token
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: corporate-secrets
  target:
    name: audit-log-siem-token
  data:
    - secretKey: token
      remoteRef:
        key: akuity/audit-log/siem-webhook-token
```

## Tier escalation

- **Tier 1** (this file): one stream, one SIEM destination.
- **Tier 4**: per-region streams plus a fleet-wide aggregation destination (see `4-hybridmulticloud/akuity/audit-log-fleet-export.yaml`).
