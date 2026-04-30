package policy

import "github.com/zclifton/k8-gitops-platform/libs/tiers"

// NetworkPolicyByTier maps tier defaults for use in policy templates.
#NetworkPolicyByTier: {
	dev:        tiers.dev.networkPolicy
	staging:    tiers.staging.networkPolicy
	production: tiers.production.networkPolicy
}
