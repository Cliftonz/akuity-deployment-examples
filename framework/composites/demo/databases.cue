package demo

let C = cluster

// One XDatabase entry so make export-cluster CLUSTER=demo emits the
// XDatabase XRD plus all three provider Compositions (AWS, GCP, on-prem)
// under platform/crossplane/. Tier 3 and tier 4 README applies the
// rendered XRD/Composition set, then files claims from their own
// claims/ directory.
databases: [{
	name:      "guestbook-demo"
	engine:    "postgres"
	version:   "16"
	size:      "small"
	storageGB: 20
	tier:      "dev"
	cluster:   C.name
	owner:     "platform-team"
}]
