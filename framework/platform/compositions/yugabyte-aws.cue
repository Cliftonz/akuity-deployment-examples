package compositions

// YugabyteCompositionAWS maps an XDatabase claim with `engine: yugabytedb`
// to an AWS-hosted YugabyteDB regional sub-deployment. Modeled here as a
// yugabytedb Helm Release for review portability; in production this
// resolves to a Yugabyte Managed instance or a self-operated cluster on EKS.
//
// Why YugabyteDB at tier 4 (not tier 3): YugabyteDB is multi-region native.
// One logical database spans every region; each regional Composition
// deploys local nodes that join the same global universe via xCluster
// replication. The app team writes one claim and gets a database that
// follows their users no matter which region they're in. Tier 3's
// per-cloud Postgres pattern can't do that — each tier-3 region has its
// own isolated Postgres.
//
// Selection: this variant matches when the EnvironmentConfig declares
// `provider: aws` AND the claim's spec.engine is `yugabytedb`.
#YugabyteCompositionAWS: {
	apiVersion: "apiextensions.crossplane.io/v1"
	kind:       "Composition"
	metadata: {
		name: "yugabyte-aws"
		labels: {
			"crossplane.io/xrd":    "xdatabases.\(#ApiGroup)"
			"infra.k8/composition": "yugabyte-aws"
			"infra.k8/provider":    "aws"
			"infra.k8/engine":      "yugabytedb"
		}
	}
	spec: {
		compositeTypeRef: {
			apiVersion: "\(#ApiGroup)/v1alpha1"
			kind:       "XDatabase"
		}
		mode: "Pipeline"
		pipeline: [{
			step: "patch-and-transform"
			functionRef: {
				name: "crossplane-contrib-function-patch-and-transform"
			}
			input: {
				apiVersion: "pt.fn.crossplane.io/v1beta1"
				kind:       "Resources"
				resources: [{
					name: "release"
					base: {
						apiVersion: "helm.crossplane.io/v1beta1"
						kind:       "Release"
						metadata: {
							name: "database"
							annotations: {
								"infra.k8/provider": "aws"
								"infra.k8/engine":   "yugabytedb"
							}
						}
						spec: {
							providerConfigRef: {
								name: "in-cluster"
							}
							rollbackLimit: 3
							forProvider: {
								chart: {
									name:       "yugabyte"
									repository: "https://charts.yugabyte.com"
									version:    "2.21.0"
								}
								namespace: "databases"
								// Regional deployment that joins the global
								// xCluster universe. The xClusterMaster value
								// points at the same primary across regions
								// so all three Compositions form one DB.
								values: {
									isMultiAz: true
									AZ:        "us-east-1a"
									masterAddresses: "yb-master-svc.databases.svc.cluster.local:7100"
								}
							}
						}
					}
					patches: [
						{
							type:          "FromCompositeFieldPath"
							fromFieldPath: "spec.name"
							toFieldPath:   "metadata.name"
						},
						{
							type:          "FromCompositeFieldPath"
							fromFieldPath: "spec.version"
							toFieldPath:   "spec.forProvider.values.image.tag"
						},
						{
							type:          "FromCompositeFieldPath"
							fromFieldPath: "spec.size"
							toFieldPath:   "spec.forProvider.values.resource.master.requests.memory"
						},
						{
							type: "CombineFromComposite"
							combine: {
								variables: [{fromFieldPath: "spec.storageGB"}]
								strategy: "string"
								string: {fmt: "%dGi"}
							}
							toFieldPath: "spec.forProvider.values.storage.master.size"
						},
					]
				}]
			}
		}]
	}
}

yugabyteCompositionAWS: #YugabyteCompositionAWS
