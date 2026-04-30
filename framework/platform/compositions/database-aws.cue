package compositions

// DatabaseCompositionAWS maps an XDatabase claim to an AWS-hosted Postgres.
// Modeled here as a bitnami/postgresql Helm Release for review portability;
// in production this resolves to provider-aws RDSInstance + DBSubnetGroup.
//
// Selection: this variant matches when the EnvironmentConfig on the seed
// cluster declares `provider: aws`. See compositionSelector wiring on the
// XRD and the EnvironmentConfigs under framework/platform/environment/.
#DatabaseCompositionAWS: {
	apiVersion: "apiextensions.crossplane.io/v1"
	kind:       "Composition"
	metadata: {
		name: "database-aws"
		labels: {
			"crossplane.io/xrd":    "xdatabases.\(#ApiGroup)"
			"infra.k8/composition": "aws"
			"infra.k8/provider":    "aws"
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

databaseCompositionAWS: #DatabaseCompositionAWS
