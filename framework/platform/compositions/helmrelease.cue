package compositions

// HelmReleaseComposition maps an XHelmRelease claim to a Helm provider Release.
#HelmReleaseComposition: {
	apiVersion: "apiextensions.crossplane.io/v1"
	kind:       "Composition"
	metadata: {
		name: "helmrelease-standard"
		labels: {
			"crossplane.io/xrd":   "xhelmreleases.\(#ApiGroup)"
			"infra.k8/composition": "standard"
		}
	}
	spec: {
		compositeTypeRef: {
				apiVersion: "\(#ApiGroup)/v1alpha1"
			kind:       "XHelmRelease"
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
							name: "helm-release"
						}
						spec: {
							providerConfigRef: {
								name: "in-cluster"
							}
							rollbackLimit: 3
							forProvider: {
								chart: {
									name: ""
									repository: ""
									version: ""
								}
								namespace: ""
								values: {}
							}
						}
					}
					patches: [
						{
							type: "FromCompositeFieldPath"
							fromFieldPath: "spec.name"
							toFieldPath:   "metadata.name"
						},
						{
							type: "FromCompositeFieldPath"
							fromFieldPath: "spec.namespace"
							toFieldPath:   "spec.forProvider.namespace"
						},
						{
							type: "FromCompositeFieldPath"
							fromFieldPath: "spec.chart.name"
							toFieldPath:   "spec.forProvider.chart.name"
						},
						{
							type: "FromCompositeFieldPath"
							fromFieldPath: "spec.chart.repository"
							toFieldPath:   "spec.forProvider.chart.repository"
						},
						{
							type: "FromCompositeFieldPath"
							fromFieldPath: "spec.chart.version"
							toFieldPath:   "spec.forProvider.chart.version"
						},
						{
							type: "FromCompositeFieldPath"
							fromFieldPath: "spec.values"
							toFieldPath:   "spec.forProvider.values"
						},
					]
				}]
		}
	}]
	}
}

helmReleaseComposition: #HelmReleaseComposition
