package export

import (
	"list"

	"github.com/zclifton/k8-gitops-platform/libs/constants"
	demo "github.com/zclifton/k8-gitops-platform/composites/demo:demo"
	platformCompositions "github.com/zclifton/k8-gitops-platform/platform/compositions:compositions"
	xrd "github.com/zclifton/k8-gitops-platform/platform/xrd:xrd"
)

// Tag for single-cluster export: cue export ./export/ -t cluster=demo
_cluster: *"" | string @tag(cluster)

// Tag to include/exclude platform resources (XRDs + Compositions).
// Use -t platform=false to render only composite resources.
_platform: *"true" | string @tag(platform)
_includePlatform: _platform == "true"

// Tag to include/exclude shared composite resources. Reserved for a
// future composites/shared package.
_shared: *"true" | string @tag(shared)
_includeShared: _shared == "true"

_apiVersion: "\(constants.ApiGroup)/v1alpha1"
_platformXRDs: [...] | *[]
_platformComps: [...] | *[]
if _includePlatform {
	if _cluster != "" {
		// Per-cluster: only XRDs/Compositions whose composite list is
		// populated on this cluster.
		_platformXRDs:  _platformXRDsPerCluster[_cluster]
		_platformComps: _platformCompsPerCluster[_cluster]
	}
	if _cluster == "" {
		// Multi-cluster export: union of every cluster's used XRDs.
		_platformXRDs:  _unionXRDs
		_platformComps: _unionComps
	}
}

// _xrdMap is the single source of truth that ties a composite list field
// (e.g. `helmReleases`) to its XRD definition and matching Composition(s).
// Most entries have a single Composition; multi-cloud entries (databases)
// list one Composition per provider. All Compositions for an entry satisfy
// the same XRD; Crossplane picks among them via compositionSelector and
// EnvironmentConfig at claim time.
_xrdMap: {
	namespaces: {definition:             xrd.xNamespace,             compositions: [platformCompositions.namespaceComposition]}
	roleBindings: {definition:           xrd.xRoleBinding,           compositions: [platformCompositions.roleBindingComposition]}
	resourceQuotas: {definition:         xrd.xResourceQuota,         compositions: [platformCompositions.resourceQuotaComposition]}
	networkPolicies: {definition:        xrd.xNetworkPolicy,         compositions: [platformCompositions.networkPolicyComposition]}
	helmReleases: {definition:           xrd.xHelmRelease,           compositions: [platformCompositions.helmReleaseComposition]}
	storageClasses: {definition:         xrd.xStorageClass,          compositions: [platformCompositions.storageClassComposition]}
	nodeTaints: {definition:             xrd.xNodeTaint,             compositions: [platformCompositions.nodeTaintComposition]}
	kyvernoPolicies: {definition:        xrd.xKyvernoPolicy,         compositions: [platformCompositions.kyvernoPolicyComposition]}
	argoEventBuses: {definition:         xrd.xArgoEventBus,          compositions: [platformCompositions.argoEventBusComposition]}
	argoEventSources: {definition:       xrd.xArgoEventSource,       compositions: [platformCompositions.argoEventSourceComposition]}
	argoSensors: {definition:            xrd.xArgoSensor,            compositions: [platformCompositions.argoSensorComposition]}
	argoAppProjects: {definition:        xrd.xArgoAppProject,        compositions: [platformCompositions.argoAppProjectComposition]}
	argoApplicationSets: {definition:    xrd.xArgoApplicationSet,    compositions: [platformCompositions.argoApplicationSetComposition]}
	certificates: {definition:           xrd.xCertificate,           compositions: [platformCompositions.certificateComposition]}
	clusterExternalSecrets: {definition: xrd.xClusterExternalSecret, compositions: [platformCompositions.clusterExternalSecretComposition]}
	cronJobs: {definition:               xrd.xCronJob,               compositions: [platformCompositions.cronJobComposition]}
	clusterRoles: {definition:           xrd.xClusterRole,           compositions: [platformCompositions.clusterRoleComposition]}
	clusterRoleBindings: {definition:    xrd.xClusterRoleBinding,    compositions: [platformCompositions.clusterRoleBindingComposition]}
	externalSecrets: {definition:        xrd.xExternalSecret,        compositions: [platformCompositions.externalSecretComposition]}
	clusterSecretStores: {definition:    xrd.xClusterSecretStore,    compositions: [platformCompositions.clusterSecretStoreComposition]}
	jobs: {definition:                   xrd.xJob,                   compositions: [platformCompositions.jobComposition]}
	serviceAccounts: {definition:        xrd.xServiceAccount,        compositions: [platformCompositions.serviceAccountComposition]}
	objectPatches: {definition:          xrd.xObjectPatch,           compositions: [platformCompositions.objectPatchComposition]}
	ingresses: {definition:              xrd.xIngress,               compositions: [platformCompositions.ingressComposition]}
	metallbPools: {definition:           xrd.xMetalLBPool,           compositions: [platformCompositions.metallbPoolComposition]}
	externalBackends: {definition:       xrd.xExternalBackend,       compositions: [platformCompositions.externalBackendComposition]}
	serversTransports: {definition:      xrd.xServersTransport,      compositions: [platformCompositions.serversTransportComposition]}
	exposedServices: {definition:        xrd.xExposedService,        compositions: [platformCompositions.exposedServiceComposition]}
	databases: {definition:              xrd.xDatabase,              compositions: [
		// Postgres family — tier 3 default. Each region runs an isolated
		// managed Postgres; no cross-region replication.
		platformCompositions.databaseCompositionAWS,
		platformCompositions.databaseCompositionGCP,
		platformCompositions.databaseCompositionOnPrem,
		// YugabyteDB family — tier 4 default. Each region's Composition
		// deploys local YB nodes that join one global xCluster universe;
		// the database itself spans regions natively.
		platformCompositions.yugabyteCompositionAWS,
		platformCompositions.yugabyteCompositionGCP,
		platformCompositions.yugabyteCompositionOnPrem,
	]}
}

// _clusterUsedFields[clusterName] is the list of composite field names
// where that cluster has at least one entry in the rendered output.
_clusterUsedFields: {
	for _name, _c in _allClusters {
		(_name): [for k, _ in _xrdMap if len(_c[k]) > 0 {k}]
	}
}

// Per-cluster XRD + Composition lists, derived from usage.
_platformXRDsPerCluster: {
	for _name, _fields in _clusterUsedFields {
		(_name): [for f in _fields {_xrdMap[f].definition}]
	}
}
_platformCompsPerCluster: {
	for _name, _fields in _clusterUsedFields {
		(_name): list.FlattenN([for f in _fields {_xrdMap[f].compositions}], 1)
	}
}

// Union across all clusters — used when no cluster tag is set.
_anyClusterUsesField: {
	for k, _ in _xrdMap {
		(k): list.Sum([for _name, _c in _allClusters {len(_c[k])}]) > 0
	}
}
_unionXRDs: [for k, used in _anyClusterUsesField if used {_xrdMap[k].definition}]
_unionComps: list.FlattenN([for k, used in _anyClusterUsesField if used {_xrdMap[k].compositions}], 1)

// Default empty lists for optional composite resource types.
_compositeDefaults: {
	namespaces:             *[] | [...]
	roleBindings:           *[] | [...]
	resourceQuotas:         *[] | [...]
	networkPolicies:        *[] | [...]
	helmReleases:           *[] | [...]
	storageClasses:         *[] | [...]
	nodeTaints:             *[] | [...]
	kyvernoPolicies:        *[] | [...]
	argoEventBuses:         *[] | [...]
	argoEventSources:       *[] | [...]
	argoSensors:            *[] | [...]
	argoAppProjects:        *[] | [...]
	argoApplicationSets:    *[] | [...]
	certificates:           *[] | [...]
	clusterExternalSecrets: *[] | [...]
	cronJobs:               *[] | [...]
	clusterRoles:           *[] | [...]
	clusterRoleBindings:    *[] | [...]
	externalSecrets:        *[] | [...]
	clusterSecretStores:    *[] | [...]
	jobs:                   *[] | [...]
	serviceAccounts:        *[] | [...]
	objectPatches:          *[] | [...]
	ingresses:              *[] | [...]
	metallbPools:           *[] | [...]
	externalBackends:       *[] | [...]
	serversTransports:      *[] | [...]
	exposedServices:        *[] | [...]
	databases:              *[] | [...]
	...
}
_demo: _compositeDefaults & demo

_allClusters: {
	"demo": {
		metadata: demo.cluster
		namespaces: [for ns in _demo.namespaces {
			apiVersion: _apiVersion
			kind:       "XNamespace"
			metadata: name: ns.name
			spec: {
				name:    ns.name
				tier:    ns.tier
				cluster: ns.cluster
				owner:   ns.owner
				if ns.labels != _|_ {
					labels: ns.labels
				}
			}
		}]
		roleBindings: [for rb in _demo.roleBindings {
			apiVersion: _apiVersion
			kind:       "XRoleBinding"
			metadata: name: rb.name
			spec: {
				name:      rb.name
				namespace: rb.namespace
				tier:      rb.tier
				cluster:   rb.cluster
				owner:     rb.owner
				roleRef:   rb.roleRef
				subjects:  rb.subjects
			}
		}]
		resourceQuotas: [for rq in _demo.resourceQuotas {
			apiVersion: _apiVersion
			kind:       "XResourceQuota"
			metadata: name: rq.name
			spec: {
				name:      rq.name
				namespace: rq.namespace
				tier:      rq.tier
				cluster:   rq.cluster
				owner:     rq.owner
				hard:      rq.hard
			}
		}]
		networkPolicies: [for np in _demo.networkPolicies {
			apiVersion: _apiVersion
			kind:       "XNetworkPolicy"
			metadata: name: np.name
			spec: {
				name:      np.name
				namespace: np.namespace
				tier:      np.tier
				cluster:   np.cluster
				owner:     np.owner
				policy:    np.policy
			}
		}]
		helmReleases: [for hr in _demo.helmReleases {
			apiVersion: _apiVersion
			kind:       "XHelmRelease"
			metadata: name: hr.name
			spec: {
				name:      hr.name
				namespace: hr.namespace
				chart:     hr.chart
				values:    hr.values
				tier:      hr.tier
				cluster:   hr.cluster
				owner:     hr.owner
			}
		}]
		storageClasses: [for sc in _demo.storageClasses {
			apiVersion: _apiVersion
			kind:       "XStorageClass"
			metadata: name: sc.name
			spec: {
				name:                 sc.name
				provisioner:          sc.provisioner
				reclaimPolicy:        sc.reclaimPolicy
				allowVolumeExpansion: sc.allowVolumeExpansion
				volumeBindingMode:    sc.volumeBindingMode
				parameters:           sc.parameters
				tier:                 sc.tier
				cluster:              sc.cluster
				owner:                sc.owner
			}
		}]
		nodeTaints: [for nt in _demo.nodeTaints {
			apiVersion: _apiVersion
			kind:       "XNodeTaint"
			metadata: name: nt.name
			spec: {
				name:     nt.name
				cluster:  nt.cluster
				owner:    nt.owner
				nodeName: nt.nodeName
				taints:   nt.taints
			}
		}]
		kyvernoPolicies: [for kp in _demo.kyvernoPolicies {
			apiVersion: _apiVersion
			kind:       "XKyvernoPolicy"
			metadata: name: kp.name
			spec: {
				name:    kp.name
				policy:  kp.policy
				tier:    kp.tier
				cluster: kp.cluster
				owner:   kp.owner
			}
		}]
		argoEventBuses: [for eb in _demo.argoEventBuses {
			apiVersion: _apiVersion
			kind:       "XArgoEventBus"
			metadata: name: eb.name
			spec: {
				name:      eb.name
				namespace: eb.namespace
				tier:      eb.tier
				cluster:   eb.cluster
				owner:     eb.owner
				config:    eb.config
			}
		}]
		argoEventSources: [for es in _demo.argoEventSources {
			apiVersion: _apiVersion
			kind:       "XArgoEventSource"
			metadata: name: es.name
			spec: {
				name:      es.name
				namespace: es.namespace
				tier:      es.tier
				cluster:   es.cluster
				owner:     es.owner
				config:    es.config
			}
		}]
		argoSensors: [for s in _demo.argoSensors {
			apiVersion: _apiVersion
			kind:       "XArgoSensor"
			metadata: name: s.name
			spec: {
				name:      s.name
				namespace: s.namespace
				tier:      s.tier
				cluster:   s.cluster
				owner:     s.owner
				config:    s.config
			}
		}]
		argoAppProjects: [for ap in _demo.argoAppProjects {
			apiVersion: _apiVersion
			kind:       "XArgoAppProject"
			metadata: name: ap.name
			spec: {
				name:      ap.name
				namespace: ap.namespace
				tier:      ap.tier
				cluster:   ap.cluster
				owner:     ap.owner
				config:    ap.config
			}
		}]
		argoApplicationSets: [for as in _demo.argoApplicationSets {
			apiVersion: _apiVersion
			kind:       "XArgoApplicationSet"
			metadata: name: as.name
			spec: {
				name:      as.name
				namespace: as.namespace
				tier:      as.tier
				cluster:   as.cluster
				owner:     as.owner
				config:    as.config
			}
		}]
		certificates: [for c in _demo.certificates {
			apiVersion: _apiVersion
			kind:       "XCertificate"
			metadata: name: c.name
			spec: {
				name:      c.name
				namespace: c.namespace
				tier:      c.tier
				cluster:   c.cluster
				owner:     c.owner
				cert:      c.cert
			}
		}]
		clusterExternalSecrets: [for ces in _demo.clusterExternalSecrets {
			apiVersion: _apiVersion
			kind:       "XClusterExternalSecret"
			metadata: name: ces.name
			spec: {
				name:           ces.name
				tier:           ces.tier
				cluster:        ces.cluster
				owner:          ces.owner
				template:       ces.template
				namespaceSelectors: ces.namespaceSelectors
			}
		}]
		cronJobs: [for cj in _demo.cronJobs {
			apiVersion: _apiVersion
			kind:       "XCronJob"
			metadata: name: cj.name
			spec: {
				name:      cj.name
				namespace: cj.namespace
				tier:      cj.tier
				cluster:   cj.cluster
				owner:     cj.owner
				cronJob:   cj.cronJob
			}
		}]
		clusterRoles: [for cr in _demo.clusterRoles {
			apiVersion: _apiVersion
			kind:       "XClusterRole"
			metadata: name: cr.name
			spec: {
				name:    cr.name
				tier:    cr.tier
				cluster: cr.cluster
				owner:   cr.owner
				rules:   cr.rules
			}
		}]
		clusterRoleBindings: [for crb in _demo.clusterRoleBindings {
			apiVersion: _apiVersion
			kind:       "XClusterRoleBinding"
			metadata: name: crb.name
			spec: {
				name:     crb.name
				tier:     crb.tier
				cluster:  crb.cluster
				owner:    crb.owner
				roleRef:  crb.roleRef
				subjects: crb.subjects
			}
		}]
		externalSecrets: [for es in _demo.externalSecrets {
			apiVersion: _apiVersion
			kind:       "XExternalSecret"
			metadata: name: es.name
			spec: {
				name:      es.name
				namespace: es.namespace
				tier:      es.tier
				cluster:   es.cluster
				owner:     es.owner
				secret:    es.secret
			}
		}]
		clusterSecretStores: [for css in _demo.clusterSecretStores {
			apiVersion: _apiVersion
			kind:       "XClusterSecretStore"
			metadata: name: css.name
			spec: {
				name:    css.name
				tier:    css.tier
				cluster: css.cluster
				owner:   css.owner
				store:   css.store
			}
		}]
		jobs: [for j in _demo.jobs {
			apiVersion: _apiVersion
			kind:       "XJob"
			metadata: name: j.name
			spec: {
				name:      j.name
				namespace: j.namespace
				tier:      j.tier
				cluster:   j.cluster
				owner:     j.owner
				job:       j.job
			}
		}]
		serviceAccounts: [for sa in _demo.serviceAccounts {
			apiVersion: _apiVersion
			kind:       "XServiceAccount"
			metadata: name: sa.name
			spec: {
				name:      sa.name
				namespace: sa.namespace
				tier:      sa.tier
				cluster:   sa.cluster
				owner:     sa.owner
				if sa.annotations != _|_ {
					annotations: sa.annotations
				}
				if sa.labels != _|_ {
					labels: sa.labels
				}
			}
		}]
		objectPatches: [for op in _demo.objectPatches {
			apiVersion: _apiVersion
			kind:       "XObjectPatch"
			metadata: name: op.name
			spec: {
				name:      op.name
				targetRef: op.targetRef
				tier:      op.tier
				cluster:   op.cluster
				owner:     op.owner
				if op.annotations != _|_ {
					annotations: op.annotations
				}
				if op.labels != _|_ {
					labels: op.labels
				}
			}
		}]
		ingresses: [for ig in _demo.ingresses {
			apiVersion: _apiVersion
			kind:       "XIngress"
			metadata: name: ig.name
			spec: {
				name:             ig.name
				namespace:        ig.namespace
				tier:             ig.tier
				cluster:          ig.cluster
				owner:            ig.owner
				host:             ig.host
				serviceName:      ig.serviceName
				servicePort:      ig.servicePort
				ingressClassName: ig.ingressClassName
				if ig.annotations != _|_ {
					annotations: ig.annotations
				}
				if ig.path != _|_ {
					path: ig.path
				}
				if ig.tlsSecretName != _|_ {
					tlsSecretName: ig.tlsSecretName
				}
			}
		}]
		metallbPools: [for mp in _demo.metallbPools {
			apiVersion: _apiVersion
			kind:       "XMetalLBPool"
			metadata: name: mp.name
			spec: {
				name:      mp.name
				addresses: mp.addresses
				tier:      mp.tier
				cluster:   mp.cluster
				owner:     mp.owner
				if mp.namespace != _|_ {
					namespace: mp.namespace
				}
				if mp.autoAssign != _|_ {
					autoAssign: mp.autoAssign
				}
				if mp.avoidBuggyIPs != _|_ {
					avoidBuggyIPs: mp.avoidBuggyIPs
				}
			}
		}]
		externalBackends: [for eb in _demo.externalBackends {
			apiVersion: _apiVersion
			kind:       "XExternalBackend"
			metadata: name: eb.name
			spec: {
				name:        eb.name
				namespace:   eb.namespace
				tier:        eb.tier
				cluster:     eb.cluster
				owner:       eb.owner
				targetIP:    eb.targetIP
				targetPort:  eb.targetPort
				servicePort: eb.servicePort
				if eb.protocol != _|_ {
					protocol: eb.protocol
				}
				if eb.appProtocol != _|_ {
					appProtocol: eb.appProtocol
				}
				if eb.annotations != _|_ {
					annotations: eb.annotations
				}
			}
		}]
		serversTransports: [for st in _demo.serversTransports {
			apiVersion: _apiVersion
			kind:       "XServersTransport"
			metadata: name: st.name
			spec: {
				name:      st.name
				namespace: st.namespace
				tier:      st.tier
				cluster:   st.cluster
				owner:     st.owner
				if st.insecureSkipVerify != _|_ {
					insecureSkipVerify: st.insecureSkipVerify
				}
			}
		}]
		exposedServices: [for es in _demo.exposedServices {
			apiVersion: _apiVersion
			kind:       "XExposedService"
			metadata: name: es.name
			spec: {
				name:       es.name
				namespace:  es.namespace
				selector:   es.selector
				targetPort: es.targetPort
				omniPort:   es.omniPort
				omniLabel:  es.omniLabel
				omniPrefix: es.omniPrefix
				tier:       es.tier
				cluster:    es.cluster
				owner:      es.owner
				if es.port != _|_ {
					port: es.port
				}
				if es.portName != _|_ {
					portName: es.portName
				}
			}
		}]
		databases: [for db in _demo.databases {
			apiVersion: _apiVersion
			kind:       "XDatabase"
			metadata: name: db.name
			spec: {
				name:       db.name
				engine:     db.engine
				version:    db.version
				size:       db.size
				storageGB:  db.storageGB
				tier:       db.tier
				cluster:    db.cluster
				owner:      db.owner
			}
		}]
	}
}

// When -t cluster=<name> is set, emit only that cluster; otherwise emit all.
if _cluster != "" {
	clusters: (_allClusters & {[_cluster]: _})[_cluster]
}
if _cluster == "" {
	clusters: _allClusters
}

// Flat list of all manifests in apply order: XRDs → Compositions → Composites.
_clusterComposites: {
	for _name, _c in _allClusters {
		(_name): list.Concat([
			_c.namespaces,
			_c.roleBindings,
			_c.resourceQuotas,
			_c.networkPolicies,
			_c.helmReleases,
			_c.storageClasses,
			_c.nodeTaints,
			_c.kyvernoPolicies,
			_c.argoEventBuses,
			_c.argoEventSources,
			_c.argoSensors,
			_c.argoAppProjects,
			_c.argoApplicationSets,
			_c.certificates,
			_c.clusterExternalSecrets,
			_c.cronJobs,
			_c.clusterRoles,
			_c.clusterRoleBindings,
			_c.externalSecrets,
			_c.clusterSecretStores,
			_c.jobs,
			_c.serviceAccounts,
			_c.objectPatches,
			_c.ingresses,
			_c.metallbPools,
			_c.externalBackends,
			_c.serversTransports,
			_c.exposedServices,
			_c.databases,
		])
	}
}

if _cluster != "" {
	manifests: list.Concat([
		_platformXRDs,
		_platformComps,
		_clusterComposites[_cluster],
	])
}
if _cluster == "" {
	let _allComposites = list.Concat([for _name, _composites in _clusterComposites {_composites}])
	manifests: list.Concat([
		_platformXRDs,
		_platformComps,
		_allComposites,
	])
}
