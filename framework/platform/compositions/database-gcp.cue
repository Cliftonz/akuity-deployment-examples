package compositions

// DatabaseCompositionGCP maps an XDatabase claim to a GCP-hosted Postgres.
// Modeled here as a bitnami/postgresql Helm Release for review portability;
// in production this resolves to provider-gcp CloudSQLInstance + Database.
//
// Selection: this variant matches when the EnvironmentConfig on the seed
// cluster declares `provider: gcp`. See compositionSelector wiring on the
// XRD and the EnvironmentConfigs under framework/platform/environment/.
#DatabaseCompositionGCP: {
	apiVersion: "apiextensions.crossplane.io/v1"
	kind:       "Composition"
	metadata: {
		name: "database-gcp"
		labels: {
			"crossplane.io/xrd":    "xdatabases.\(#ApiGroup)"
			"infra.k8/composition": "gcp"
			"infra.k8/provider":    "gcp"
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
							annotations: "infra.k8/provider": "gcp"
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
								// GCP-flavored variant; in production this would
								// be a CloudSQLInstance forProvider with the
								// project/region pulled from EnvironmentConfig.
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

databaseCompositionGCP: #DatabaseCompositionGCP
