package compositions

// YugabyteCompositionGCP — same XDatabase XRD, GCP regional sub-deployment.
// Joins the same global xCluster universe as the AWS and on-prem variants.
// Selection: provider=gcp + engine=yugabytedb.
#YugabyteCompositionGCP: {
	apiVersion: "apiextensions.crossplane.io/v1"
	kind:       "Composition"
	metadata: {
		name: "yugabyte-gcp"
		labels: {
			"crossplane.io/xrd":    "xdatabases.\(#ApiGroup)"
			"infra.k8/composition": "yugabyte-gcp"
			"infra.k8/provider":    "gcp"
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
								"infra.k8/provider": "gcp"
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
								values: {
									isMultiAz: true
									AZ:        "europe-west1-b"
									masterAddresses: "yb-master-svc.databases.svc.cluster.local:7100"
								}
							}
						}
					}
					patches: [
						{type: "FromCompositeFieldPath", fromFieldPath: "spec.name", toFieldPath: "metadata.name"},
						{type: "FromCompositeFieldPath", fromFieldPath: "spec.version", toFieldPath: "spec.forProvider.values.image.tag"},
						{type: "FromCompositeFieldPath", fromFieldPath: "spec.size", toFieldPath: "spec.forProvider.values.resource.master.requests.memory"},
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

yugabyteCompositionGCP: #YugabyteCompositionGCP
