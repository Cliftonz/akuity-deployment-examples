# Infrastructure

Day-zero substrate. Everything in this directory installs **before** the Crossplane control plane comes up — these are the pieces a fresh cluster needs in place so Crossplane (and everything downstream of it) has somewhere to land.

GitOps cannot bootstrap GitOps. The hub cluster's control plane has to exist before Argo CD can reconcile anything against it; the storage layer has to exist before Crossplane's package manager can write its cache; the database operator has to exist before the first XRD-driven Postgres claim can land. These installers are the imperative seam at the edge of the declarative system.

## What lives here

| Component | Why it's pre-Crossplane |
| --- | --- |
| [`talos/`](talos/) | Cluster-OS configuration patches (apiserver tuning, etcd tuning, kubelet cert rotation, Longhorn user-volume mode). Applied at machine-config time before any workload runs. |
| [`storageclass/`](storageclass/) | Default `StorageClass` (NFS in this repo). Crossplane's package manager and any operator with a PVC need a default class to bind to. |
| [`longhorn/`](longhorn/) | Block-storage provider. Stateful workloads (CloudNative-PG, Loki, Thanos receive) need ReadWriteOnce volumes; Longhorn is the cluster-local answer when there is no cloud CSI. |
| [`metrics-server/`](metrics-server/) | `kubectl top`, HPA, VPA all read from `metrics.k8s.io`. Without it, autoscaling silently fails closed. |
| [`cloudnative-pg/`](cloudnative-pg/) | Postgres operator. Tier-3 `XPostgresDatabase` claims compose into CloudNative-PG `Cluster` CRs; the operator has to be running before any Composition references those CRDs. |
| [`crossplane/`](crossplane/) | Crossplane UXP itself, plus Provider Helm, Provider Kubernetes, and the composition functions. Once this lands, everything else is GitOps-managed via XRDs and Compositions from `framework/`. |

## Order of operations

1. **Talos machine config** — apply the patches in `talos/` at cluster install or via `talosctl patch`. This is the only thing that has to happen before Kubernetes is reachable.
2. **Storage layer** — `storageclass/` and `longhorn/install.sh`. Anything that runs a PVC depends on this being ready.
3. **Metrics + DB operators** — `metrics-server/install.sh`, `cloudnative-pg/install.sh`. These are operators that Crossplane's Compositions later consume; they don't *require* Crossplane, so they install first.
4. **Crossplane** — `crossplane/install.sh`. UXP + Provider Helm + Provider Kubernetes + functions, all version-pinned.

After step 4, `make export-cluster CLUSTER=demo && make apply CLUSTER=demo` from the repo root takes over. From that point, every subsequent change goes through the framework / GitOps path, not through these scripts.

## Why scripts and not GitOps

The chicken-and-egg problem: the components in this directory are what GitOps reconciles *onto*. Argo CD cannot reconcile its own dependencies; Crossplane cannot reconcile the storage layer it stores its package cache on. The pragmatic answer is a small, version-pinned, idempotent imperative seam — these install scripts — kept deliberately tiny so the surface area outside GitOps stays small.

The components themselves are not unmanaged after install. Once Crossplane is up, their Helm releases are reconciled by Provider Helm (see `framework/composites/<cluster>/helmreleases.cue`); the install scripts are bootstrap-only and shouldn't be re-run after the cluster is healthy.

## Re-running

Each `install.sh` is idempotent — re-running it on a healthy cluster is a no-op. Treat them as bootstrap, not as the day-two operations interface. For day-two changes (version bumps, value changes), edit the `values.yaml` next to the script and let the Crossplane Helm release reconcile, **not** by re-running the script.
