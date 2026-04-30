package environment

// EnvironmentConfig installed on the eu-west regional seed cluster.
// Drives Composition selection toward the GCP variant.
#RegionEUWest: {
	apiVersion: "apiextensions.crossplane.io/v1beta1"
	kind:       "EnvironmentConfig"
	metadata: {
		name: "region-eu-west"
		labels: {
			"infra.k8/region":   "eu-west"
			"infra.k8/provider": "gcp"
		}
	}
	data: {
		region:   "europe-west1"
		provider: "gcp"
		project:  "platform-eu-west"
	}
}

regionEUWest: #RegionEUWest
