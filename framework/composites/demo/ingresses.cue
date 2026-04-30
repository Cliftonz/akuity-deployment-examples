package demo

let C = cluster

// Ingresses for cluster-hosted services. Each one becomes an XIngress
// claim → networking.k8s.io/v1 Ingress with the Traefik class.
ingresses: [
	{
		name:             "demo-app"
		namespace:        "demo-app"
		host:             "demo-app.demo.example.com"
		serviceName:      "demo-app"
		servicePort:      80
		ingressClassName: "traefik"
		tier:             C.tier
		cluster:          C.name
		owner:            "platform-team"
	},
]
