# Pod stuck in ImagePullBackOff

**Severity:** sev2.

**Trigger:** a Pod has been in `ImagePullBackOff` for 120+ seconds.

## Symptoms

- `kubectl get pods` shows status `ImagePullBackOff` or `ErrImagePull`.
- New replicas of a Deployment fail to come up after a Kargo promotion.

## Diagnosis

```bash
kubectl -n <ns> describe pod <pod> | tail -30
# Look at the Events block — the actual pull error is at the bottom.
```

Common error patterns and their causes:

| Error excerpt | Cause |
|---|---|
| `manifest unknown` | The image tag/digest does not exist in the registry. Kargo wrote something the registry rejects. |
| `unauthorized` | The Pod's pull secret is missing, expired, or wrong. |
| `connection refused` / `i/o timeout` | NetworkPolicy egress blocking the registry, or DNS broken. |
| `denied: requested access to the resource is denied` | The pull secret authenticates but the credentials don't have read on this repo. |

## Remediation

**Tag/digest mismatch.** Check the Kargo Stage's `argocd-update` step ran cleanly:
```bash
kubectl -n kargo-simple get stage <stage> -o jsonpath='{.status.lastPromotion}'
```
If a digest was promoted that doesn't exist, revert the env-branch commit (same procedure as `app-sync-failure.md`).

**Auth.** Recreate the pull secret in the namespace:
```bash
kubectl -n <ns> create secret docker-registry ghcr \
  --docker-server=ghcr.io \
  --docker-username=<user> \
  --docker-password=<token> \
  --dry-run=client -o yaml | kubectl apply -f -

# Add to the ServiceAccount if not already.
kubectl -n <ns> patch sa default -p '{"imagePullSecrets":[{"name":"ghcr"}]}'
```

**Network/DNS.** Check egress policy:
```bash
kubectl -n <ns> get networkpolicy
# Confirm a policy permits egress to TCP/443 against the registry CIDR (or
# at least to kube-system DNS).
```

## Verification

```bash
kubectl -n <ns> get pods -w
# Pod transitions through Pending → ContainerCreating → Running.
```

## What this looks like at higher tiers

Tier 3 adds an admission policy (`no-latest-tag.yaml`) that prevents `latest` tags from ever being applied; tier 4 adds region-specific image mirroring (ECR per region) so eu-west doesn't time out pulling from a us-east-only registry.
