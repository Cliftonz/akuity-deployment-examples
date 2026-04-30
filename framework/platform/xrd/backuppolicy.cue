package xrd

// XBackupPolicy defines the CompositeResourceDefinition for backup policy requests.
#XBackupPolicy: {
	apiVersion: "apiextensions.crossplane.io/v2"
	kind:       "CompositeResourceDefinition"
	metadata: name: "xbackuppolicies.\(#ApiGroup)"
	spec: {
		group: #ApiGroup
		scope: "Cluster"
		names: {
			kind:   "XBackupPolicy"
			plural: "xbackuppolicies"
		}
		versions: [{
			name:          "v1alpha1"
			served:        true
			referenceable: true
			schema: openAPIV3Schema: {
				type: "object"
				description: "Request a backup policy for workloads or namespaces."
				properties: spec: {
					type: "object"
					description: "Backup policy settings and ownership metadata."
					properties: {
						name: {
							type:        "string"
							description: "Backup policy name to create."
							pattern:     "^[a-z][a-z0-9-]*$"
						}
						namespace: {
							type:        "string"
							description: "Target namespace for backup policy."
							pattern:     "^[a-z][a-z0-9-]*$"
						}
						schedule: {
							type:        "string"
							description: "Backup schedule in cron format."
						}
						retentionDays: {
							type:        "integer"
							description: "Number of days to retain backups."
						}
						selector: {
							type:        "object"
							description: "Label selector for workloads to include."
							additionalProperties: {type: "string"}
						}
						tier: {
							type:        "string"
							description: "Deployment tier."
							enum: ["dev", "staging", "production"]
						}
						cluster: {
							type:        "string"
							description: "Target cluster name."
						}
						owner: {
							type:        "string"
							description: "Team or service that owns this backup policy."
						}
					}
					required: ["name", "namespace", "schedule", "retentionDays", "tier", "cluster", "owner"]
				}
			}
		}]
	}
}

xBackupPolicy: #XBackupPolicy
