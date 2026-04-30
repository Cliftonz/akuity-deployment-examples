# Tier 1: Helm + Kargo

Same scenario as tier 0 the guestbook app, three environments, Kargo promotion across rendered branches is rewritten as a Helm chart.

The reason to move from Kustomize to Helm at this tier is templating leverage, not feature richness. Kustomize patches scale fine for small overlays; once a chart starts carrying real configuration (resource sizes that vary, optional sidecars, conditional NetworkPolicies, computed image refs), Helm's templating + values composition wins. The promotion model does not change though as Kargo still hydrates the env branch with rendered Kubernetes YAML, and Argo CD still applies plain manifests.

## Layout

```
1-helm/
├── charts/guestbook/
│   ├── Chart.yaml
│   ├── values.yaml                 # defaults
│   └── templates/
│       ├── _helpers.tpl            # image ref helper, common labels
│       ├── namespace.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── serviceaccount.yaml
│       ├── networkpolicy.yaml
│       └── pdb.yaml
├── env/
│   ├── values-dev.yaml             # 1 replica, namespace=guestbook-dev
│   ├── values-staging.yaml         # 2 replicas, namespace=guestbook-staging
│   └── values-prod.yaml            # 3 replicas, namespace=guestbook-prod
├── argocd/
│   ├── projects/{business,platform}.yaml
│   ├── applicationsets/business-apps.yaml   # list generator (one element per env)
│   └── apps/{ingress-nginx,cert-manager,kargo-pipelines}.yaml
├── kargo/
│   ├── projects/{kargo-simple,project-config}.yaml
│   ├── warehouses/guestbook.yaml
│   ├── stages/{dev,staging,prod}.yaml        # helm-update-image + helm-template
│   └── analysis-templates/guestbook-http-probe.yaml
├── platform/                                  # ingress-nginx + cert-manager (unchanged from tier 0)
└── rendered/{dev,staging,prod}/.gitkeep
```

## Apply

```bash
kubectl apply -k 1-helm/argocd/
```

## What changed from tier 0

| Concern | Tier 0 | Tier 1 |
|---|---|---|
| Per-env config | Kustomize patch in `apps/guestbook/envs/<env>/kustomization.yaml` | `env/values-<env>.yaml` |
| Image pinning | `kustomize-set-image` | `helm-update-image` (writes to `image.digest`) |
| Render step in Kargo | `kustomize-build` | `helm-template` |
| ApplicationSet generator | List | List (unchanged) |
| Promotion currency | Rendered YAML on env branch | Rendered YAML on env branch (unchanged) |

The Argo CD Applications, the Kargo Project / Warehouse / AnalysisTemplate, and the platform component workloads are byte-identical between tiers. Only the chart, the values overlays, and the two render-related Kargo steps differ.

## Apply

Same as tier 0:

```bash
kubectl apply -k 1-helm/argocd/
```

## Compliance posture

Tier 1 is **the first real audit tier**. The trigger to move from tier 0 to tier 1 is almost always either the third product team or the first compliance review, whichever comes first. The standards in play:

- **SOC 2 Type 1 → Type 2.**   Type 1 ("controls are designed correctly") in months 0–6, then a 6–12 month observation window, then Type 2 ("controls operated effectively"). SSO via Dex, audit logs flowing to a SIEM, AppProject role bindings against IdP groups, admission policies in Audit mode; every tier-1 addition over tier 0 directly maps to a SOC 2 control objective.
- **ISO 27001.** Common at this tier for companies selling into EU and US. The Statement of Applicability gets long; many of the same controls overlap with SOC 2.
- **HIPAA.** If the company is healthcare-adjacent: BAA with cloud provider, encryption-at-rest + in-transit (cert-manager handles the latter), audit logs preserved long enough to meet the §164.312 retention requirement.
- **PCI-DSS Level 4** for low-volume card processors; most tier-1 companies offload this to Stripe and skip the technical control surface.
- **GDPR / CCPA.** Privacy policy + DPA + DSR (data subject request) processes start needing actual technical implementation, not just legal templates. Audit logs become the substrate for "show me everywhere this user's data was accessed."

Tier 1's `argocd-cm.yaml` Dex block, `argocd-notifications-cm.yaml` SIEM webhook, audit-log-stream stub, and admission-policies (Audit mode) exist specifically to give the SOC 2 auditor things to look at when they ask "how do you control who deploys to production?" The honest gap: at tier 1 the controls are *designed*, not yet *battle-tested*. Tier 1 → tier 2 → tier 3 is the journey from "designed" to "operating effectively over a 12-month window."

## What's missing on purpose

- Still no external infra (databases, queues) because it done by click-ops at this tier. Tier 2 introduces it as Terraform and the wild-west pain that motivates tier 3. 
- Still no Crossplane abstractions or claim-based provisioning.
- Still single-cluster, single-region.

Longer narrative in [`NARRATIVE.md`](NARRATIVE.md).
