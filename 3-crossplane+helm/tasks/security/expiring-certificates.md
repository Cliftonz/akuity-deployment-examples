# Certificates expiring in 30 days

**Audience:** Platform team + security team.

**What it produces:** A weekly Slack post listing every cert-manager `Certificate` resource on the cluster whose `notAfter` is less than 30 days away. Cuts the "we forgot to renew" incident class.

## Why this matters at tier 1

Tier 1 is the first compliance-relevant tier — SOC 2 audits ask "show me your certificate renewal process." A weekly automated report is the answer; the alternative is the renewal process being a TODO in someone's notes that nobody remembers until the cert expires at 03:00 UTC on a Sunday.

Tier 0 didn't need this — at five engineers, the founders use Let's Encrypt with auto-renewal and trust cert-manager to do its job. By tier 1 the team is bigger than the trust boundary.

## Sections in the report

1. **Critical (< 7 days).** Cert name, namespace, issuer, days-to-expiry. Pages security in addition to the channel post.
2. **Warning (< 30 days).** Same shape, no page.
3. **Issuer health.** Each `ClusterIssuer` and `Issuer` resource's `Ready` status. A failed issuer surfaces here even if no certs are expiring yet.

## Data sources

- cert-manager.io `Certificate` resources: `kubectl get cert -A -o jsonpath='{...}'`
- cert-manager.io `ClusterIssuer` and `Issuer` resources

## Sample output

```
Akuity weekly cert report — 2026-04-29

🚨 Critical (< 7 days):
  - argocd/argocd-tls (Let's Encrypt-prod) → 4 days

⚠️  Warning (< 30 days):
  - guestbook-prod/guestbook-tls (Let's Encrypt-prod) → 18 days

✅ Issuers:
  - letsencrypt-prod: Ready
  - letsencrypt-staging: Ready
```
