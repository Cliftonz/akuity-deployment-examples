package demo

let C = cluster

// Per-namespace ResourceQuotas. Two patterns demonstrated:
//   - Full requests/limits + pods cap (best for namespaces hosting
//     well-defined Deployments).
//   - Pods-only cap (best for namespaces hosting chart-managed
//     DaemonSets/sidecars without per-container resource specs — a
//     strict requests.* quota would FailedCreate those pods).
resourceQuotas: [
	{
		name:      "traefik-quota"
		namespace: "traefik"
		tier:      C.tier
		cluster:   C.name
		owner:     "platform-team"
		hard: {
			"requests.cpu":    "250m"
			"requests.memory": "256Mi"
			"limits.cpu":      "1"
			"limits.memory":   "512Mi"
			pods:              "5"
		}
	},

	// MetalLB speaker DaemonSet has no per-container resources — pods-only.
	{
		name:      "metallb-quota"
		namespace: "metallb-system"
		tier:      C.tier
		cluster:   C.name
		owner:     "platform-team"
		hard: {
			pods: "10"
		}
	},

	// External Secrets webhook + cert-controller — pods-only.
	{
		name:      "external-secrets-quota"
		namespace: "external-secrets"
		tier:      C.tier
		cluster:   C.name
		owner:     "platform-team"
		hard: {
			pods: "10"
		}
	},

	{
		name:      "demo-app-quota"
		namespace: "demo-app"
		tier:      C.tier
		cluster:   C.name
		owner:     "platform-team"
		hard: {
			"requests.cpu":    "500m"
			"requests.memory": "512Mi"
			"limits.cpu":      "2"
			"limits.memory":   "2Gi"
			pods:              "10"
		}
	},
]
