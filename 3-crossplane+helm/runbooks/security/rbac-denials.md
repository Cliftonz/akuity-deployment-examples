# RBAC access denied (audit log)

**Severity:** sev3 — usually a misconfiguration, occasionally a real breach attempt.

**Trigger:** an audit-log Event with `responseStatus.code: 403` (Forbidden), at least once.

## Symptoms

- Audit-log SIEM shows `audit.k8s.io/v1 Event` with `level: Metadata` or higher and `responseStatus.code: 403`.
- A user, ServiceAccount, or controller failed to perform an action and the API server denied it.

## Why this matters at tier 1+

Tier 1 is when SSO via Dex enters the picture and AppProject role bindings start to matter. A `Forbidden` audit-log entry is the first signal that:

1. A real user's group claim doesn't match an AppProject role they expected to have access to.
2. A controller is missing a permission a chart upgrade silently needed.
3. A genuinely unauthorized actor is probing the API.

## Diagnosis

```bash
# Pull the most recent denial events.
kubectl get --raw '/api/v1/namespaces/<ns>/events?fieldSelector=type=Warning' \
  | jq '.items[] | select(.reason == "Forbidden")'

# Cross-reference with audit-log SIEM entries — they have the user identity.
# Look for: user.username, user.groups, verb, objectRef.{resource, namespace, name}
```

## Most common causes (tier-1 frequency order)

1. **Group claim mismatch.** User logged in via Dex, GitHub group is `<your-org>:platform-engineering`, AppProject role binding expects `platform-engineering`. → fix the AppProject role's `groups:` to match the actual claim format Dex emits.
2. **Controller missing permission after chart upgrade.** A new chart version added a CRD but didn't bump the operator's ClusterRole. → cross-reference upstream chart's RBAC manifests; PR the chart with the missing rule.
3. **AppProject `clusterResourceWhitelist` doesn't include the resource kind.** Argo CD refuses to sync a kind not on the whitelist. → add to the whitelist explicitly (don't blanket with `*/*`).

## Remediation

For misconfigurations, the fix is in the chart or AppProject — apply via the normal git → Argo CD reconciliation, not direct kubectl.

For a suspected breach attempt, page security:
1. Capture the user identity, source IP, and event timestamp from the audit log.
2. Rotate the user's session in Dex (force re-login).
3. Review every audit-log event from that identity in the past 24 hours.

## What this looks like at higher tiers

Tier 3 adds Crossplane provider RBAC failures (provider-aws controller missing IAM permission) into the same channel. Tier 4 aggregates audit logs across regions so a denial in eu-west surfaces alongside us-east in the same SIEM stream.
