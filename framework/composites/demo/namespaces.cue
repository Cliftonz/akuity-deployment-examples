package demo

let C = cluster

// Demo cluster namespaces. Each namespace becomes an XNamespace claim →
// Crossplane Composition → core/v1 Namespace + per-tier baseline labels.
namespaces: [
	{
		name:    "traefik"
		tier:    C.tier
		cluster: C.name
		owner:   "platform-team"
	},
	{
		name:    "metallb-system"
		tier:    C.tier
		cluster: C.name
		owner:   "platform-team"
		// MetalLB speaker uses hostNetwork + NET_RAW, both forbidden under
		// the baseline Pod Security Standard. Opt this namespace into
		// `privileged` so the speaker DaemonSet can schedule.
		labels: {
			"pod-security.kubernetes.io/enforce": "privileged"
			"pod-security.kubernetes.io/audit":   "privileged"
			"pod-security.kubernetes.io/warn":    "privileged"
		}
	},
	{
		name:    "external-secrets"
		tier:    C.tier
		cluster: C.name
		owner:   "platform-team"
	},
	{
		name:    "demo-app"
		tier:    C.tier
		cluster: C.name
		owner:   "platform-team"
	},
]
