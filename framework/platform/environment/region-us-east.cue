package environment

// EnvironmentConfig installed on the us-east regional seed cluster.
// Crossplane reads this to drive Composition selection — claims landing
// here resolve to the AWS variant via compositionSelector matchLabels.
#RegionUSEast: {
	apiVersion: "apiextensions.crossplane.io/v1beta1"
	kind:       "EnvironmentConfig"
	metadata: {
		name: "region-us-east"
		labels: {
			"infra.k8/region":   "us-east"
			"infra.k8/provider": "aws"
		}
	}
	data: {
		region:   "us-east-1"
		provider: "aws"
		// Cloud-specific defaults consumed by the AWS Composition pipeline
		// when it matures past the bitnami stand-in (subnet group, KMS key,
		// IAM role, etc.).
		dbSubnetGroup: "data-private"
	}
}

regionUSEast: #RegionUSEast
