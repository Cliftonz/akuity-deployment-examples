# Architecture

## Overview

This repository defines a Crossplane-centric platform that renders Kubernetes
manifests at build time using CUE. Rendered outputs are promoted as immutable
OCI artifacts and deployed through GitOps.

## Control Plane vs Workload Clusters

- The hub (management) cluster runs Crossplane, XRDs, Compositions, and providers.
- Spoke clusters run workloads only and apply pre-rendered manifests.

## Build and Promotion Flow

1. CUE validates claims against platform schemas.
2. `cue export` renders YAML to a deterministic output.
3. Rendered manifests are packaged as an OCI artifact.
4. Environment repositories reference the artifact digest.
5. GitOps sync applies the promoted artifact to the target cluster.

## Repository Contracts

- `framework/platform/` defines platform APIs (XRDs) and implementations (Compositions). Multi-cloud database variants live here.
- `framework/platform/environment/` declares `EnvironmentConfig` resources per regional seed cluster (used by Crossplane to select the right Composition for an `XDatabase` claim at apply time).
- `framework/libs/` defines shared schemas and tier defaults.
- `framework/composites/<cluster>/` defines per-cluster desired state inputs. The `demo` cluster is the framework's own reference cluster — it exercises every XRD the framework publishes, so `make export-cluster CLUSTER=demo` produces a complete `platform/crossplane/{xrds,compositions}/` tree that tier-3 and tier-4 customer demos consume. **It is not itself a tier in the maturity ladder.**
- `framework/export/` is the single render entry point.
