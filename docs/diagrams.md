# Diagrams

All architecture and buying-conversation diagrams across the five tiers, in one place. Each is duplicated in its tier's `NARRATIVE.md`; this page is a single-pane view for reviewers who want the visual sweep without reading the prose.

---

## Tier 0 — Kustomize + Kargo

### Architecture

```mermaid
flowchart LR
    Dev[Engineer] -->|git push| Repo[(Config repo Kustomize bases + overlays)]

    subgraph Akuity["Akuity Platform; fully managed"]
        direction TB
        ArgoCD[Argo CD]
        Kargo[Kargo dev → staging → prod]
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
        CTO["CTO is also the SRE"]
        Script["bash deploy script on its 3rd rewrite"]
        Page["3am page; nobody on-call"]
    end

    subgraph Akuity["What Akuity gives you"]
        SaaS["Argo CD + Kargo fully managed"]
        Tunnel["Outbound agent; no inbound surface to harden"]
        Cheap["Starter tier covers 1 cluster, 1 team"]
    end

    Today ==>|"replace"| Akuity

    Akuity --> W1["Hours to first deploy (weeks rolling your own)"]
    Akuity --> W2["No GitOps control plane to upgrade or page on"]
    Akuity --> W3["Promotion story your auditor won't laugh at next year"]

    style Today fill:#fff3e0
    style Akuity fill:#e8f5e9
```

---

## Tier 1 — Helm + Kargo

### Architecture

```mermaid
flowchart TB
    IdP[Corporate IdP Okta / Entra / Google] -.->|OIDC| Dex

    subgraph Repos["Portfolio repo layout"]
        AppRepos[(per-app config repos Helm chart + values)]
        PlatRepo[(platform repo component workloads)]
        Rendered[(rendered manifests env branches)]
    end

    AppRepos -->|CI Helm render| Rendered

    subgraph Akuity["Akuity Platform; fully managed"]
        Dex
        ArgoCD[Argo CD]
        Kargo[Kargo dev → staging → prod]
        Audit[Audit Logs]
        Intel[Akuity Intelligence]
    end

    Dex --> ArgoCD
    Dex --> Kargo
    Audit -->|export| SIEM[SIEM SOC 2 evidence]

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
        SOC["SOC 2 Type 1 kickoff this quarter"]
        Plat["2–4 person platform team"]
        Self["Self-hosted Argo CD upgraded on weekends"]
        Triage["Sync breaks; 20-tab debug session"]
    end

    subgraph Akuity["Akuity tier-1 wins"]
        SSO["Dex + Okta/Entra/Google wired in an hour"]
        AuditExp["Audit Logs streamed to your SIEM"]
        Intel["Akuity Intelligence; broken-sync triage in minutes"]
        Upgrades["Argo CD upgrades; Akuity's problem"]
    end

    Pain ==> Akuity

    Akuity --> Out1["SOC 2 evidence collected automatically"]
    Akuity --> Out2["Platform team back to building abstractions, not operating Argo CD"]
    Akuity --> Out3["Time-to-resolution on incidents drops by an order of magnitude"]

    style Pain fill:#fff3e0
    style Akuity fill:#e8f5e9
```

---

## Tier 2 — Terraform + Helm (Wild West)

### Architecture

```mermaid
flowchart TB
    subgraph Teams["Product teams"]
        SqA[Team A has its own TF state]
        SqB[Team B different TF state]
        SqC[Team C uses console clicks]
    end

    SqA -->|terraform apply from a laptop| AWSA[AWS account 1]
    SqB -->|terraform apply from a CI runner| AWSB[AWS account 2]
    SqC -->|console| AWSC[AWS account 3]

    subgraph Akuity["Akuity Platform"]
        ArgoCD[Argo CD]
        Kargo[Kargo]
    end

    Repo[(Per-app config repos Helm chart)] -.->|watch| ArgoCD
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
        Apps["Apps in GitOps (this part works)"]
        Wild["Terraform: 5 teams, 5 state files, 3 console-clickers"]
        Mesh["No service mesh; SOC 2 CC6.6 finding"]
        Gap["Seam between app and infra is nobody's"]
    end

    Apps --> AkuityNow["Akuity already reconciling git"]
    Wild -.->|"audit finding"| CISO["CISO conversation"]

    AkuityNow ==>|"same control plane, no migration"| Tier3["Tier 3 path: XRD claims behind Crossplane OR Terraform-operator"]

    Tier3 --> Out1["Every database review-gated in git"]
    Tier3 --> Out2["State location declared, not folkloric"]
    Tier3 --> Out3["Drift detection free; auditor question answered"]

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
        Claim[Claims XPostgresDatabase XKafkaTopic XS3Bucket]
        AppCode[App config]
    end

    subgraph PlatformTeam["Platform engineering team"]
        XRD[XRDs + Compositions tier policy in CUE]
    end

    Claim -->|consumed by| XRD

    subgraph Crossplane["Crossplane; programmability on the way in"]
        Composer[Composition engine]
    end

    XRD --> Composer
    Composer -->|provisions| CloudInfra[(Cloud provider RDS / MSK / IAM)]
    Composer -->|commits manifests| EnvRepo[(env repo rendered manifests)]

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
        Portal["Backstage / Port developer portal"]
        XRDs["Crossplane XRDs (platform team owns)"]
        CICD["Build / test pipelines"]
        IstioMesh["Istio service mesh"]
        Obs["Observability stack"]
    end

    Portal --> XRDs
    XRDs --> Compose["Compositions → cloud / on-prem"]

    subgraph Akuity["Akuity = managed GitOps half of the IDP"]
        ArgoFleet["Argo CD; 50+ clusters, one control plane"]
        KargoFleet["Kargo; per-stage gates, fleet-wide"]
        RBAC["AppProject RBAC matches platform/app boundary"]
        AuditEnt["Audit Logs; every deploy, every cluster"]
    end

    XRDs -.->|"rendered manifests"| ArgoFleet
    KargoFleet --> ArgoFleet
    ArgoFleet --> Fleet[("50+ clusters multi-cloud")]

    IDP ==> Akuity

    Akuity --> Out1["Platform team owns abstractions, not Argo CD operations"]
    Akuity --> Out2["Onboard a new team = one AppProject, not a Helm chart"]
    Akuity --> Out3["Compliance evidence covers every cluster without bolted-on tools"]

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
        TLDArgo["Akuity-managed Argo CD one instance, fleet-wide"]
        TLDKargo["Akuity-managed Kargo per-region gates"]
        TLDIntel["Akuity Intelligence fleet-wide Audit Logs"]
    end

    subgraph Regions["Always-connected regions"]
        direction LR
        subgraph USRegion["us-east"]
            SeedUS["Seed cluster Crossplane + Cluster API"]
            WorkerUS1["Worker guestbook-prod"]
            WorkerUS2["Worker orders-prod"]
            SeedUS -->|provisions| WorkerUS1
            SeedUS -->|provisions| WorkerUS2
        end
        subgraph EURegion["eu-west"]
            SeedEU["Seed cluster Crossplane + Cluster API"]
            WorkerEU1["Worker guestbook-prod"]
            WorkerEU2["Worker orders-prod"]
            SeedEU --> WorkerEU1
            SeedEU --> WorkerEU2
        end
        subgraph APRegion["ap-southeast"]
            SeedAP["Seed cluster Crossplane + Cluster API"]
            WorkerAP1["Worker guestbook-prod"]
            WorkerAP2["Worker orders-prod"]
            SeedAP --> WorkerAP1
            SeedAP --> WorkerAP2
        end
    end

    subgraph Edge["Intermittently-connected edge"]
        direction LR
        SeedShip["Onboard seed cruise ship / rig / remote site"]
        WorkerShip["Worker ship workloads"]
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
        ArgoT["Argo CD; fleet-wide single pane"]
        KargoT["Kargo; per-region gates"]
        AuditT["Audit Logs aggregated fleet-wide"]
        IntelT["Akuity Intelligence; fleet incident triage"]
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
        SeedSea["Seed + workers (intermittent backhaul)"]
    end

    TLDBuy -->|agent| US
    TLDBuy -->|agent| EU
    TLDBuy -->|agent| AP
    TLDBuy -.->|"agent (store-and-forward)"| Sea

    KargoT -. independent .-> US
    KargoT -. independent .-> EU
    KargoT -. independent .-> AP
    KargoT -. independent .-> Sea

    TLDBuy --> Win1["One Argo CD, 30+ clusters, multi-cloud + on-prem"]
    TLDBuy --> Win2["EU outage doesn't block APAC promotion"]
    TLDBuy --> Win3["Audit evidence survives partial outage and satellite-link gaps"]

    style TLDBuy fill:#e8f5e9
    style Sea fill:#fff3e0
```
