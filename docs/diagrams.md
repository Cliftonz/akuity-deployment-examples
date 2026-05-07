# Diagrams

All architecture and buying-conversation diagrams across the five tiers, in one place. Each is duplicated in its tier's `NARRATIVE.md`; this page is a single-pane view for reviewers who want the visual sweep without reading the prose.

---

## Tier 0 — Kustomize + Kargo

### Architecture

```mermaid
flowchart LR
    Dev[Engineer] -->|git push| Repo[(Config repo<br/>Kustomize bases + overlays)]

    subgraph Akuity["Akuity Platform; fully managed"]
        direction TB
        ArgoCD[Argo CD]
        Kargo[Kargo<br/>dev → staging → prod]
        Kargo -->|hydrates rendered YAML to env branch| Repo
    end

    Repo -.->|watch env branch| ArgoCD

    subgraph Cluster["Workload Cluster"]
        Agent[Akuity Agent]
        DevNS[guestbook-dev]
        StgNS[guestbook-staging]
        ProdNS[guestbook-prod]
    end

    ArgoCD <-.->|secure tunnel| Agent
    Agent --> DevNS
    Agent --> StgNS
    Agent --> ProdNS
```

### Buying conversation

```mermaid
flowchart LR
    subgraph Today["The 5–20 engineer reality today"]
        CTO["CTO is also<br/>the SRE"]
        Script["bash deploy script<br/>on its 3rd rewrite"]
        Page["3am page;<br/>nobody on-call"]
    end

    subgraph Akuity["What Akuity gives you"]
        SaaS["Argo CD + Kargo<br/>fully managed"]
        Tunnel["Outbound agent;<br/>no inbound surface<br/>to harden"]
        Cheap["Starter tier covers<br/>1 cluster, 1 team"]
    end

    Today ==>|"replace"| Akuity

    Akuity --> W1["Hours to first deploy<br/>(weeks rolling your own)"]
    Akuity --> W2["No GitOps control plane<br/>to upgrade or page on"]
    Akuity --> W3["Promotion story your<br/>auditor won't laugh<br/>at next year"]

    style Today fill:#fff3e0
    style Akuity fill:#e8f5e9
```

---

## Tier 1 — Helm + Kargo

### Architecture

```mermaid
flowchart TB
    IdP[Corporate IdP<br/>Okta / Entra / Google] -.->|OIDC| Dex

    subgraph Repos["Portfolio repo layout"]
        AppRepos[(per-app config repos<br/>Helm chart + values)]
        PlatRepo[(platform repo<br/>component workloads)]
        Rendered[(rendered manifests<br/>env branches)]
    end

    AppRepos -->|CI Helm render| Rendered

    subgraph Akuity["Akuity Platform; fully managed"]
        Dex
        ArgoCD[Argo CD]
        Kargo[Kargo<br/>dev → staging → prod]
        Audit[Audit Logs]
        Intel[Akuity Intelligence]
    end

    Dex --> ArgoCD
    Dex --> Kargo
    Audit -->|export| SIEM[SIEM<br/>SOC 2 evidence]

    Rendered -.->|watch| ArgoCD
    PlatRepo -.->|watch| ArgoCD
    Kargo -->|commit promotion| Rendered

    ArgoCD --> DevC[Dev cluster]
    ArgoCD --> StgC[Staging cluster]
    ArgoCD --> PrdC[Prod cluster]
```

### Buying conversation

```mermaid
flowchart LR
    subgraph Pain["Tier 1 reality"]
        SOC["SOC 2 Type 1<br/>kickoff this quarter"]
        Plat["2–4 person<br/>platform team"]
        Self["Self-hosted Argo CD<br/>upgraded on weekends"]
        Triage["Sync breaks;<br/>20-tab debug session"]
    end

    subgraph Akuity["Akuity tier-1 wins"]
        SSO["Dex + Okta/Entra/Google<br/>wired in an hour"]
        AuditExp["Audit Logs<br/>streamed to your SIEM"]
        Intel["Akuity Intelligence;<br/>broken-sync triage<br/>in minutes"]
        Upgrades["Argo CD upgrades;<br/>Akuity's problem"]
    end

    Pain ==> Akuity

    Akuity --> Out1["SOC 2 evidence<br/>collected automatically"]
    Akuity --> Out2["Platform team back<br/>to building abstractions,<br/>not operating Argo CD"]
    Akuity --> Out3["Time-to-resolution<br/>on incidents drops<br/>by an order of magnitude"]

    style Pain fill:#fff3e0
    style Akuity fill:#e8f5e9
```

---

## Tier 2 — Terraform + Helm (Wild West)

### Architecture

```mermaid
flowchart TB
    subgraph Teams["Product teams"]
        SqA[Team A<br/>has its own TF state]
        SqB[Team B<br/>different TF state]
        SqC[Team C<br/>uses console clicks]
    end

    SqA -->|terraform apply<br/>from a laptop| AWSA[AWS account 1]
    SqB -->|terraform apply<br/>from a CI runner| AWSB[AWS account 2]
    SqC -->|console| AWSC[AWS account 3]

    subgraph Akuity["Akuity Platform"]
        ArgoCD[Argo CD]
        Kargo[Kargo]
    end

    Repo[(Per-app config repos<br/>Helm chart)] -.->|watch| ArgoCD
    Kargo --> Repo

    ArgoCD --> Cluster[Workload cluster]

    Cluster -. consumes Secret created out-of-band .-> AWSA
    Cluster -. consumes Secret created out-of-band .-> AWSB
    Cluster -. consumes Secret created out-of-band .-> AWSC

    style Akuity fill:#e8f5e9
    style Teams fill:#fff3e0
```

### Buying conversation

```mermaid
flowchart TB
    subgraph Today["Tier 2 today"]
        Apps["Apps in GitOps<br/>(this part works)"]
        Wild["Terraform: 5 teams,<br/>5 state files,<br/>3 console-clickers"]
        Mesh["No service mesh;<br/>SOC 2 CC6.6 finding"]
        Gap["Seam between<br/>app and infra<br/>is nobody's"]
    end

    Apps --> AkuityNow["Akuity<br/>already reconciling git"]
    Wild -.->|"audit finding"| CISO["CISO conversation"]

    AkuityNow ==>|"same control plane,<br/>no migration"| Tier3["Tier 3 path:<br/>XRD claims behind<br/>Crossplane OR<br/>Terraform-operator"]

    Tier3 --> Out1["Every database<br/>review-gated in git"]
    Tier3 --> Out2["State location<br/>declared, not folkloric"]
    Tier3 --> Out3["Drift detection free;<br/>auditor question answered"]

    style AkuityNow fill:#e8f5e9
    style Today fill:#fff3e0
    style Tier3 fill:#e3f2fd
```

---

## Tier 3 — Crossplane + Helm

### Architecture

```mermaid
flowchart TB
    subgraph AppTeams["Application teams"]
        Claim[Claims<br/>XPostgresDatabase<br/>XKafkaTopic<br/>XS3Bucket]
        AppCode[App config]
    end

    subgraph PlatformTeam["Platform engineering team"]
        XRD[XRDs + Compositions<br/>tier policy in CUE]
    end

    Claim -->|consumed by| XRD

    subgraph Crossplane["Crossplane; programmability on the way in"]
        Composer[Composition engine]
    end

    XRD --> Composer
    Composer -->|provisions| CloudInfra[(Cloud provider<br/>RDS / MSK / IAM)]
    Composer -->|commits manifests| EnvRepo[(env repo<br/>rendered manifests)]

    AppCode --> EnvRepo

    subgraph Akuity["Akuity; pull-based safety on the way down"]
        ArgoCD[Argo CD]
        Kargo[Kargo]
        Audit[Audit Logs]
        Intel[Akuity Intelligence]
    end

    EnvRepo -.->|watch| ArgoCD
    Kargo -->|promotes| EnvRepo

    ArgoCD --> ClusterA[Cluster A]
    ArgoCD --> ClusterB[Cluster B]
    ArgoCD --> ClusterC[Cluster C]

    CloudInfra -.->|consumed by workloads| ClusterA
    CloudInfra -.->|consumed by workloads| ClusterB
    CloudInfra -.->|consumed by workloads| ClusterC
```

### Buying conversation

```mermaid
flowchart LR
    subgraph IDP["Your internal developer platform"]
        Portal["Backstage / Port<br/>developer portal"]
        XRDs["Crossplane XRDs<br/>(platform team owns)"]
        CICD["Build / test pipelines"]
        IstioMesh["Istio service mesh"]
        Obs["Observability stack"]
    end

    Portal --> XRDs
    XRDs --> Compose["Compositions →<br/>cloud / on-prem"]

    subgraph Akuity["Akuity = managed GitOps half of the IDP"]
        ArgoFleet["Argo CD;<br/>50+ clusters,<br/>one control plane"]
        KargoFleet["Kargo;<br/>per-stage gates,<br/>fleet-wide"]
        RBAC["AppProject RBAC<br/>matches platform/app<br/>boundary"]
        AuditEnt["Audit Logs;<br/>every deploy,<br/>every cluster"]
    end

    XRDs -.->|"rendered manifests"| ArgoFleet
    KargoFleet --> ArgoFleet
    ArgoFleet --> Fleet[("50+ clusters<br/>multi-cloud")]

    IDP ==> Akuity

    Akuity --> Out1["Platform team owns<br/>abstractions, not<br/>Argo CD operations"]
    Akuity --> Out2["Onboard a new team<br/>= one AppProject,<br/>not a Helm chart"]
    Akuity --> Out3["Compliance evidence<br/>covers every cluster<br/>without bolted-on tools"]

    style IDP fill:#e3f2fd
    style Akuity fill:#e8f5e9
```

---

## Tier 4 — Hybrid Multicloud

### Architecture (TLD → seed → worker, plus edge)

```mermaid
flowchart TB
    subgraph TLD["TLD control plane"]
        TLDGit[("Org git + policy repos")]
        TLDArgo["Akuity-managed Argo CD<br/>one instance, fleet-wide"]
        TLDKargo["Akuity-managed Kargo<br/>per-region gates"]
        TLDIntel["Akuity Intelligence<br/>fleet-wide Audit Logs"]
    end

    subgraph Regions["Always-connected regions"]
        direction LR
        subgraph USRegion["us-east"]
            SeedUS["Seed cluster<br/>Crossplane + Cluster API"]
            WorkerUS1["Worker<br/>guestbook-prod"]
            WorkerUS2["Worker<br/>orders-prod"]
            SeedUS -->|provisions| WorkerUS1
            SeedUS -->|provisions| WorkerUS2
        end
        subgraph EURegion["eu-west"]
            SeedEU["Seed cluster<br/>Crossplane + Cluster API"]
            WorkerEU1["Worker<br/>guestbook-prod"]
            WorkerEU2["Worker<br/>orders-prod"]
            SeedEU --> WorkerEU1
            SeedEU --> WorkerEU2
        end
        subgraph APRegion["ap-southeast"]
            SeedAP["Seed cluster<br/>Crossplane + Cluster API"]
            WorkerAP1["Worker<br/>guestbook-prod"]
            WorkerAP2["Worker<br/>orders-prod"]
            SeedAP --> WorkerAP1
            SeedAP --> WorkerAP2
        end
    end

    subgraph Edge["Intermittently-connected edge"]
        direction LR
        SeedShip["Onboard seed<br/>cruise ship / rig / remote site"]
        WorkerShip["Worker<br/>ship workloads"]
        SeedShip -->|provisions| WorkerShip
    end

    TLDGit -.->|watched by| TLDArgo
    TLDArgo -->|agent| WorkerUS1
    TLDArgo -->|agent| WorkerUS2
    TLDArgo -->|agent| WorkerEU1
    TLDArgo -->|agent| WorkerEU2
    TLDArgo -->|agent| WorkerAP1
    TLDArgo -->|agent| WorkerAP2
    TLDArgo -.->|"agent (intermittent backhaul)"| WorkerShip
    TLDKargo -. independent gate .-> USRegion
    TLDKargo -. independent gate .-> EURegion
    TLDKargo -. independent gate .-> APRegion
    TLDKargo -. independent gate .-> Edge
```

### Buying conversation

```mermaid
flowchart TB
    subgraph TLDBuy["Akuity TLD control plane (one)"]
        ArgoT["Argo CD;<br/>fleet-wide single pane"]
        KargoT["Kargo;<br/>per-region gates"]
        AuditT["Audit Logs<br/>aggregated fleet-wide"]
        IntelT["Akuity Intelligence;<br/>fleet incident triage"]
    end

    subgraph US["us-east"]
        SeedUS["Seed + workers"]
    end
    subgraph EU["eu-west"]
        SeedEU["Seed + workers"]
    end
    subgraph AP["ap-southeast"]
        SeedAP["Seed + workers"]
    end
    subgraph Sea["fleet-at-sea"]
        SeedSea["Seed + workers<br/>(intermittent backhaul)"]
    end

    TLDBuy -->|agent| US
    TLDBuy -->|agent| EU
    TLDBuy -->|agent| AP
    TLDBuy -.->|"agent (store-and-forward)"| Sea

    KargoT -. independent .-> US
    KargoT -. independent .-> EU
    KargoT -. independent .-> AP
    KargoT -. independent .-> Sea

    TLDBuy --> Win1["One Argo CD,<br/>30+ clusters,<br/>multi-cloud + on-prem"]
    TLDBuy --> Win2["EU outage doesn't<br/>block APAC promotion"]
    TLDBuy --> Win3["Audit evidence survives<br/>partial outage and<br/>satellite-link gaps"]

    style TLDBuy fill:#e8f5e9
    style Sea fill:#fff3e0
```
