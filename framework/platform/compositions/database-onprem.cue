package compositions

// DatabaseCompositionOnPrem maps an XDatabase claim to an on-prem / edge
// Postgres deployment via the bitnami/postgresql Helm chart on the local
// cluster. No cloud provider involvement.
//
// Selection: this variant matches when the EnvironmentConfig on the seed
// cluster declares `provider: onprem`. See compositionSelector wiring on
// the XRD and the EnvironmentConfigs under framework/platform/environment/.
#DatabaseCompositionOnPrem: {
	apiVersion: "apiextensions.crossplane.io/v1"
	kind:       "Composition"
	metadata: {
		name: "database-onprem"
		labels: {
			"crossplane.io/xrd":    "xdatabases.\(#ApiGroup)"
			"infra.k8/composition": "onprem"
			"infra.k8/provider":    "onprem"
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
							annotations: "infra.k8/provider": "onprem"
						}
						spec: {
							providerConfigRef: {
								name: "in-cluster"
							}
							rollbackLimit: 3
							forProvider: {
								chart: {
									name:       "postgresql"
									repository: "https://charts.bitnami.com/bitnami"
									version:    "16.4.0"
								}
								namespace: "databases"
								// On-prem variant: the chart runs in-cluster
								// against local persistent storage. No cloud
								// CRDs touched.
								values: {}
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
							toFieldPath:   "spec.forProvider.values.primary.resources.requests.memory"
						},
						{
							type: "CombineFromComposite"
							combine: {
								variables: [{fromFieldPath: "spec.storageGB"}]
								strategy: "string"
								string: {fmt: "%dGi"}
							}
							toFieldPath: "spec.forProvider.values.primary.persistence.size"
						},
					]
				}]
			}
		}]
	}
}

databaseCompositionOnPrem: #DatabaseCompositionOnPrem
