package demo

let C = cluster

// Demonstrates the XNetworkPolicy claim — pass through any
// networking.k8s.io/v1 NetworkPolicy spec; the claim provides metadata
// labelling + tier/owner enforcement at composition time.
networkPolicies: [
	// Traefik egress: DNS to any namespace + HTTP/HTTPS/kube-api outbound.
	// No ingress restriction — Service is LoadBalancer; MetalLB delivers
	// traffic direct to pods.
	{
		name:      "traefik-egress"
		namespace: "traefik"
		tier:      C.tier
		cluster:   C.name
		owner:     "platform-team"
		policy: {
			podSelector: {}
			policyTypes: ["Egress"]
			egress: [
				{
					to: [{namespaceSelector: {}}]
					ports: [
						{port: 53, protocol: "UDP"},
						{port: 53, protocol: "TCP"},
					]
				},
				{
					to: [{ipBlock: cidr: "0.0.0.0/0"}]
					ports: [
						{port: 80, protocol: "TCP"},
						{port: 443, protocol: "TCP"},
						{port: 6443, protocol: "TCP"},
					]
				},
			]
		}
	},

	// demo-app: deny-all baseline + allow ingress from Traefik.
	{
		name:      "demo-app-from-traefik"
		namespace: "demo-app"
		tier:      C.tier
		cluster:   C.name
		owner:     "platform-team"
		policy: {
			podSelector: {}
			policyTypes: ["Ingress", "Egress"]
			ingress: [
				{
					from: [{
						namespaceSelector: matchLabels: "kubernetes.io/metadata.name": "traefik"
					}]
				},
			]
			egress: [
				{
					to: [{namespaceSelector: {}}]
					ports: [
						{port: 53, protocol: "UDP"},
						{port: 53, protocol: "TCP"},
					]
				},
				{
					to: [{ipBlock: cidr: "0.0.0.0/0"}]
					ports: [{port: 443, protocol: "TCP"}]
				},
			]
		}
	},
]
