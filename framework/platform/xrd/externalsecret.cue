package xrd

// XExternalSecret defines the CompositeResourceDefinition for external secret requests.
#XExternalSecret: {
	apiVersion: "apiextensions.crossplane.io/v2"
	kind:       "CompositeResourceDefinition"
	metadata: name: "xexternalsecrets.\(#ApiGroup)"
	spec: {
		group: #ApiGroup
		scope: "Cluster"
		names: {
			kind:   "XExternalSecret"
			plural: "xexternalsecrets"
		}
		versions: [{
			name:          "v1alpha1"
			served:        true
			referenceable: true
			schema: openAPIV3Schema: {
				type: "object"
				description: "Request a secret synced from an external secret store."
				properties: spec: {
					type: "object"
					description: "External secret settings and ownership metadata."
					properties: {
						name: {
							type:        "string"
							description: "Kubernetes Secret name to create."
							pattern:     "^[a-z][a-z0-9-]*$"
						}
						namespace: {
							type:        "string"
							description: "Namespace where the Secret will be created."
							pattern:     "^[a-z][a-z0-9-]*$"
						}
						secretStoreRef: {
							type:        "string"
							description: "Name of the secret store to read from."
						}
						data: {
							type:        "array"
							description: "Mappings from remote keys to local secret keys, matching ESO's ExternalSecret.spec.data shape."
							items: {
								type: "object"
								properties: {
									secretKey: {
										type:        "string"
										description: "Key name in the resulting Kubernetes Secret."
									}
									remoteRef: {
										type:        "object"
										description: "Reference to the remote secret in the backing store."
										properties: {
											key: {
												type:        "string"
												description: "Remote secret key or path (e.g., preview/github-pat)."
											}
											property: {
												type:        "string"
												description: "Optional property of the remote secret to extract."
											}
										}
										required: ["key"]
									}
								}
								required: ["secretKey", "remoteRef"]
							}
						}
						refreshInterval: {
							type:        "string"
							description: "Refresh interval for syncing secrets (e.g., 1h, 5m)."
						}
						template: {
							type:        "object"
							description: "Optional ESO target.template — used for inline secret data templating, type override, or annotation/label injection on the resulting Kubernetes Secret."
							"x-kubernetes-preserve-unknown-fields": true
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
							description: "Team or service that owns this secret."
						}
					}
					required: ["name", "namespace", "secretStoreRef", "data", "tier", "cluster", "owner"]
				}
			}
		}]
	}
}

xExternalSecret: #XExternalSecret
