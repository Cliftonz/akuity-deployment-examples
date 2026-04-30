package environment

// EnvironmentConfig installed on the ap-southeast regional seed cluster.
// Drives Composition selection toward the on-prem variant — this region
// runs the Postgres workload on local hardware behind a private link
// rather than against a hyperscaler-managed service.
#RegionAPSoutheast: {
	apiVersion: "apiextensions.crossplane.io/v1beta1"
	kind:       "EnvironmentConfig"
	metadata: {
		name: "region-ap-southeast"
		labels: {
			"infra.k8/region":   "ap-southeast"
			"infra.k8/provider": "onprem"
		}
	}
	data: {
		region:   "ap-southeast-1"
		provider: "onprem"
		// Bare-metal storage class on the seed cluster.
		storageClass: "rook-ceph-block"
	}
}

regionAPSoutheast: #RegionAPSoutheast
