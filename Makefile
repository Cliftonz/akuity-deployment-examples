.PHONY: validate export export-cluster apply diff clean delete delete-xrds watch check-shared

# Drift guard: byte-identical files across tier folders should stay identical.
check-shared:
	@./ci/scripts/check-shared-files-identical.sh

# Include Crossplane XRDs and Compositions in export (default: true)
PLATFORM ?= true

# Include shared composite resources in export (default: true)
SHARED ?= true

# Paths to watch for changes (exclude rendered output to avoid export loops)
WATCH_PATHS ?= framework infrastructure ci docs Makefile

# XRDs with immutable scope that may need recreation
XRD_RECREATE ?= xnamespaces.infra.k8 xstorageclasses.infra.k8 xnodetaints.infra.k8

# Recreate immutable-scope XRDs during apply (default: false)
XRD_RECREATE_ENABLED ?= false

# CUE source root
FRAMEWORK ?= framework

# Render output roots
PLATFORM_OUT  ?= platform/crossplane
APPS_OUT      ?= apps

# Validate all CUE schemas and definitions
validate:
	cd $(FRAMEWORK) && cue vet ./...

# Export rendered YAML for all clusters into apps/<cluster>/ trees plus
# shared platform XRDs/Compositions into platform/crossplane/.
export: validate
	@rm -rf $(APPS_OUT)/* $(PLATFORM_OUT)/*
	@mkdir -p $(APPS_OUT) $(PLATFORM_OUT)
	@cd $(FRAMEWORK) && cue export ./export/ -e manifests -t platform=$(PLATFORM) -t shared=$(SHARED) --out yaml \
	  | yq '.[]' \
	  | ../ci/scripts/split-manifests.sh ../$(APPS_OUT)
	@$(MAKE) _hoist-platform OUT=$(APPS_OUT)

# Export rendered YAML for one cluster.
# Usage: make export-cluster CLUSTER=demo
export-cluster: validate
	@test -n "$(CLUSTER)" || (echo "Usage: make export-cluster CLUSTER=demo" && exit 1)
	@rm -rf $(APPS_OUT)/$(CLUSTER) $(PLATFORM_OUT)
	@mkdir -p $(APPS_OUT)/$(CLUSTER) $(PLATFORM_OUT)
	@echo "Exporting $(CLUSTER)..."
	@cd $(FRAMEWORK) && cue export ./export/ -e manifests -t cluster=$(CLUSTER) -t platform=$(PLATFORM) -t shared=$(SHARED) --out yaml \
	  | yq '.[]' \
	  | ../ci/scripts/split-manifests.sh ../$(APPS_OUT)/$(CLUSTER)
	@$(MAKE) _hoist-platform OUT=$(APPS_OUT)/$(CLUSTER)

# Move XRD/Composition output out of the per-cluster apps tree into the
# shared platform/crossplane/ tree. Internal helper; do not invoke directly.
_hoist-platform:
	@if [ -d "$(OUT)/xrds" ]; then \
	  mkdir -p $(PLATFORM_OUT)/xrds && \
	  mv $(OUT)/xrds/* $(PLATFORM_OUT)/xrds/ 2>/dev/null || true; \
	  rmdir $(OUT)/xrds 2>/dev/null || true; \
	fi
	@if [ -d "$(OUT)/compositions" ]; then \
	  mkdir -p $(PLATFORM_OUT)/compositions && \
	  mv $(OUT)/compositions/* $(PLATFORM_OUT)/compositions/ 2>/dev/null || true; \
	  rmdir $(OUT)/compositions 2>/dev/null || true; \
	fi

# Export and apply manifests for a cluster.
# Usage: make apply CLUSTER=demo
apply: export-cluster
	@if [ "$(XRD_RECREATE_ENABLED)" = "true" ]; then \
		$(MAKE) delete-xrds; \
	fi
	@if [ -d "$(PLATFORM_OUT)/xrds" ]; then \
		kubectl apply -R -f $(PLATFORM_OUT)/xrds; \
		kubectl wait --for=condition=Established -f $(PLATFORM_OUT)/xrds --timeout=120s; \
	fi
	@if [ -d "$(PLATFORM_OUT)/compositions" ]; then \
		kubectl apply -R -f $(PLATFORM_OUT)/compositions; \
	fi
	@kubectl apply -R -f $(APPS_OUT)/$(CLUSTER)

# Delete rendered manifests for a cluster.
# Usage: make delete CLUSTER=demo
delete: export-cluster
	kubectl delete -R -f $(APPS_OUT)/$(CLUSTER)

delete-xrds:
	@kubectl delete compositeresourcedefinition $(XRD_RECREATE) --ignore-not-found --wait=false

# Watch for changes, re-export, and re-apply.
# Usage: make watch CLUSTER=demo
watch:
	@test -n "$(CLUSTER)" || (echo "Usage: make watch CLUSTER=demo" && exit 1)
	@command -v fswatch >/dev/null 2>&1 || command -v entr >/dev/null 2>&1 || (echo "Install fswatch (brew install fswatch) or entr (brew install entr)" && exit 1)
	@$(MAKE) apply CLUSTER=$(CLUSTER) PLATFORM=$(PLATFORM)
	@echo "Watching: $(WATCH_PATHS)"
	@if command -v fswatch >/dev/null 2>&1; then \
		fswatch -o $(WATCH_PATHS) | while read -r _; do \
			$(MAKE) apply CLUSTER=$(CLUSTER) PLATFORM=$(PLATFORM); \
		done; \
	else \
		find $(WATCH_PATHS) -type f | entr -r $(MAKE) apply CLUSTER=$(CLUSTER) PLATFORM=$(PLATFORM); \
	fi

# Show diff between current rendered output and fresh export.
diff:
	@echo "Checking for drift in $(APPS_OUT)/ and $(PLATFORM_OUT)/..."
	@ci/scripts/export.sh --dry-run

# Remove CUE caches.
clean:
	rm -rf $(FRAMEWORK)/cue.mod/pkg/ $(FRAMEWORK)/cue.mod/usr/
