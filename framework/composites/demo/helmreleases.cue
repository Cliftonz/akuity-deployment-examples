package demo

let C = cluster

// Helm-managed components. Each entry becomes an XHelmRelease claim →
// provider-helm Release. Charts are pinned to specific versions; image
// tags are pinned in `values` so a chart-only bump can never silently
// upgrade an app.
helmReleases: [
	// MetalLB — gives Services of type LoadBalancer real IPs from the
	// configured pool. speaker.frr.enabled=false: stick to the simpler
	// L2 announcer (no FRR/BGP) for the demo cluster.
	{
		name:      "metallb"
		namespace: "metallb-system"
		chart: {
			name:       "metallb"
			repository: "https://metallb.github.io/metallb"
			version:    "0.15.3"
		}
		values: {
			speaker: frr: enabled: false
		}
		tier:    C.tier
		cluster: C.name
		owner:   "platform-team"
	},

	// Traefik — ingress controller + LoadBalancer Service. The Service
	// pulls an IP from the `lan` MetalLB pool via the address-pool
	// annotation. Drop forwardedHeaders trustedIPs to TEST-NET-3 so the
	// chart picks up the demo subnet.
	{
		name:      "traefik"
		namespace: "traefik"
		chart: {
			name:       "traefik"
			repository: "https://traefik.github.io/charts"
			version:    "33.2.1"
		}
		values: {
			service: {
				type: "LoadBalancer"
				annotations: {
					"metallb.universe.tf/address-pool":    "lan"
					"metallb.universe.tf/loadBalancerIPs": "192.0.2.240"
				}
			}
			ports: {
				web: forwardedHeaders: trustedIPs: ["192.0.2.0/24"]
				websecure: forwardedHeaders: trustedIPs: ["192.0.2.0/24"]
			}
			ingressClass: isDefaultClass: true
		}
		tier:    C.tier
		cluster: C.name
		owner:   "platform-team"
	},

	// External Secrets Operator — reconciles ExternalSecret/CESS objects
	// against an external secret backend (Vault, AWS SM, GCP SM, etc.).
	{
		name:      "external-secrets"
		namespace: "external-secrets"
		chart: {
			name:       "external-secrets"
			repository: "https://charts.external-secrets.io"
			version:    "0.10.4"
		}
		values: {
			installCRDs: true
		}
		tier:    C.tier
		cluster: C.name
		owner:   "platform-team"
	},
]
