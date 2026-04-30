# Tier 2: Terraform + Helm (wild west)

Same guestbook from tier 1, now with a Postgres backend. The Helm chart adds an `envFrom` reading a Secret. A Terraform module under [`terraform/postgres/`](terraform/postgres/) provisions the RDS instance and creates the Secret in the app's namespace.

**The point of this tier is the bridging the infra and the app, not creating the charts.** GitOps owns the app; Terraform owns the database; nothing owns the join. That gap is the wild west, and it's where most growth-stage organizations actually live.

## Layout

```
2-terraform+helm/
├── charts/guestbook/                 # tier 1 chart + envFrom on the DB Secret
├── env/values-{dev,staging,prod}.yaml  # per-env Secret name (guestbook-postgres-<env>)
├── terraform/postgres/
│   ├── main.tf                        # aws_db_instance + kubernetes_secret
│   ├── variables.tf                   # env, namespace, secret_name, region, …
│   ├── outputs.tf                     # endpoint, secret name, secret namespace
│   └── README.md                      # apply instructions; what's wrong with this picture
├── argocd/                            # unchanged from tier 1; Argo CD never sees the DB
├── kargo/                             # unchanged from tier 1; promotes the chart only
├── platform/                          # ingress-nginx + cert-manager (unchanged)
└── rendered/{dev,staging,prod}/
```

## Apply

Two separate workflows that do not know about each other:

```bash
# 1. Provision the database. Out-of-band, per-env, manual.
cd 2-terraform+helm/terraform/postgres
terraform apply -var env=dev -var namespace=guestbook-dev -var secret_name=guestbook-postgres-dev

# 2. Bootstrap the GitOps stack. Argo CD reconciles the app; Kargo promotes
#    image tags. Neither layer knows the database exists until the deployment
#    starts and reads the Secret.
kubectl apply -k 2-terraform+helm/argocd/
```

## What this tier shows

- **The pain that motivates the tier-3 move.** The chart and the database are joined by a string (`database.secretName`). Nothing enforces that the Terraform output and the Helm value agree. A typo in either silently breaks the deployment.
- **State and ownership ambiguity.** The Terraform module has no backend declaration; whoever runs it picks one. Five teams will pick five different things, and three of them will lose state at least once.
- **No drift detection.** Console clicks on AWS or kubectl edits to the Secret are invisible to the GitOps loop.
- **No promotion of infra.** Kargo promotes the image tag from dev to staging to prod. The database schema does not move with it. There is no contract that says "the staging DB has the columns the staging app expects."

Tier 3 closes all of these gaps by handing the abstraction to the platform team as a Crossplane XRD. App teams file claims; standards are enforced; everything reconciles in git.

## Compliance posture

Tier 2 is **the tier where the auditor catches up.** SOC 2 Type 1 is in hand from tier 1; Type 2 evidence collection has been running for 6–9 months; the firm now wants to walk through how production databases get provisioned. The wild-west narrative in this tier is exactly what the auditor finds:

- **SOC 2 Type 2.** Specifically the control objectives around change management (CC8.1) and logical access (CC6.1, CC6.2). The Terraform module that has no backend, no review gate, and no drift detection lights up multiple findings. Many companies fail their first Type 2 audit on tier-2-shaped gaps and have to remediate before they can re-attest.
- **ISO 27001 surveillance audits.** A.8.32 (change management), A.8.9 (configuration management), A.5.23 (information security for use of cloud services) — the auditor asks for the Terraform state location, who has access, and who reviews changes. There isn't a clean answer.
- **HIPAA + HITECH** if applicable: §164.308(a)(1)(ii)(D) information system activity review needs audit-log evidence the wild-west doesn't produce for Terraform-side actions.
- **PCI-DSS Requirement 6.4.1** (separation of duties between dev and prod) and **10.2** (audit trail) — both fail if a developer can run `terraform apply` straight to prod.
- **Vendor management programs.** The first time a customer asks "list every subprocessor that touches our data," the team realizes the Terraform state contains references to half a dozen SaaS providers nobody filed a DPA with.

### The service-mesh finding

There's a class of finding tier-2 companies almost always hit and almost never expect: **under a strict reading of SOC 2 CC6.1, CC6.6, CC6.7 and ISO 27001 A.8.20, A.8.21, A.8.24, you need a service mesh.** NetworkPolicy alone does not satisfy the controls strictly:

- **CC6.1 / A.8.20 (network controls)** — NetworkPolicy filters by IP/namespace/pod-label, which is *network identity*. A strict auditor wants *workload identity* — every pod-to-pod call authenticated by a cryptographically verifiable identity, not by who happens to share a label.
- **CC6.6 / CC6.7 / A.8.24 (encryption in transit)** — east-west traffic between pods is plaintext by default. A strict reading of "encryption in transit for sensitive data" means mTLS on every call, not just TLS at the ingress.
- **CC7.2 / A.8.16 (system monitoring + audit logging)** — NetworkPolicy is a binary allow/deny with no per-call audit trail. The auditor wants "show me every call this service made to the database in the past hour" with caller identity, latency, and status code. That's a service-mesh observability question.

The mesh you pick depends on operational appetite that you want to deal with such as Istio (richest feature set, heaviest operationally), Linkerd (lightest, narrower feature set), or Cilium with Hubble + mTLS (eBPF-native, no sidecar). **This repo's tier 3+ pins Istio** because the AuthorizationPolicy CRD shape + multi-cluster east-west gateway are what tier 4's cross-region story needs. The mesh provides:

- mTLS between every pod via SPIFFE/SPIRE identity, scoped by Istio's `PeerAuthentication` (CC6.6, A.8.24).
- `AuthorizationPolicy` keyed off workload identity, not IP (CC6.1, A.8.20).
- Per-call audit trail via Envoy access logs + telemetry (CC7.2, A.8.16) — caller/callee identity, latency, status, surfaced in Grafana on top of Prometheus.
- Cross-namespace policy enforcement that survives the inevitable NetworkPolicy mistake.

This repo does not ship Istio at tier 2 as the wild-west narrative is the point. But **the auditor's finding "you have NetworkPolicy but no service mesh" is what tells the platform team they need both Crossplane (tier 3) and Istio**. They land at the same tier-3 transition because both are "platform team gets authority to set standards" decisions.

__Many uneducated auditors, and there are many, accept NetworkPolicy + Pod Security Admission + cert-manager-issued Ingress certs as sufficient. The strict reading is the one that bites you when you sell into financial services, healthcare, or government, where the auditor reads the controls literally.__

### The lever

Tier 2 is *also* the tier where compliance becomes the **organizational lever** that authorizes tier 3. The platform team gets headcount and authority not because someone read about Crossplane in a blog post, but because the SOC 2 Type 2 report came back with findings that won't survive next year's audit unless the control surface gets fixed — *including* the service-mesh finding above. Tier 3 is the technical answer to a multi-front compliance gap; tier 2's audit pain is what unlocks it being funded.

## What's missing on purpose

- No platform-team-owned abstraction for infra. Tier 3 introduces it.
- Still single-cloud, single-region.
- Still no claim API for app teams to consume.

Longer narrative in [`NARRATIVE.md`](NARRATIVE.md).
