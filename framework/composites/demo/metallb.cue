package demo

let C = cluster

// MetalLB pools. `autoAssign: false` forces Services to opt in via the
// `metallb.universe.tf/address-pool` annotation — prevents an unrelated
// Service from grabbing an IP and breaking DNS. Address range uses
// RFC 5737 TEST-NET-1 (192.0.2.0/24) to make it obvious this is a demo.
metallbPools: [
	{
		name:       "lan"
		namespace:  "metallb-system"
		addresses:  ["192.0.2.240-192.0.2.250"]
		autoAssign: false
		tier:       C.tier
		cluster:    C.name
		owner:      "platform-team"
	},
]
