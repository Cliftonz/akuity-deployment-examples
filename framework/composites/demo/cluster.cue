package demo

import "github.com/zclifton/k8-gitops-platform/libs/tiers"

cluster: tiers.#ClusterConfig & {
	name:     "demo"
	tier:     "dev"
	provider: "eks"
	region:   "us-east-1"
}
