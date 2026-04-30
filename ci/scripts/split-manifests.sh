#!/usr/bin/env bash
# split-manifests.sh — Split a YAML stream into individual files.
# Each file is named {kind}-{metadata.name}.yaml (lowercased).
# Files are organized into subdirectories by resource type.
# Handles both --- separated and concatenated YAML documents.
#
# Usage: cat manifests.yaml | ./ci/scripts/split-manifests.sh <output-dir>

set -euo pipefail

OUTDIR="${1:?Usage: split-manifests.sh <output-dir>}"
mkdir -p "$OUTDIR"

INDEX=0
DOC=""

# Map kind to subdirectory
subdir_for_kind() {
    case "$1" in
        compositeresourcedefinition) echo "xrds" ;;
        composition)                echo "compositions" ;;
        nodetaint)                  echo "nodes" ;;
        networkpolicy)              echo "policies" ;;
        resourcequota)              echo "policies" ;;
        helmrelease)                echo "helm" ;;
        rolebinding)                echo "rbac" ;;
        namespace)                  echo "namespaces" ;;
        xnodetaint)                 echo "nodes" ;;
        xnetworkpolicy)             echo "policies" ;;
        xresourcequota)             echo "policies" ;;
        xhelmrelease)               echo "helm" ;;
        xrolebinding)               echo "rbac" ;;
        xnamespace)                 echo "namespaces" ;;
        xstorageclass)              echo "storage" ;;
        xingress)                   echo "networking" ;;
        xmetallbpool)               echo "networking" ;;
        ingress)                    echo "networking" ;;
        xdatabase)                  echo "databases" ;;
        *)                          echo "" ;;
    esac
}

flush_doc() {
    if [[ -z "$DOC" ]]; then
        return
    fi

    KIND=$(echo "$DOC" | yq '.kind' | tr '[:upper:]' '[:lower:]')
    NAME=$(echo "$DOC" | yq '.metadata.name')

    if [[ "$KIND" == "null" || "$NAME" == "null" ]]; then
        echo "  WARN: skipping document $INDEX (missing kind or metadata.name)" >&2
        DOC=""
        return
    fi

    SUBDIR=$(subdir_for_kind "$KIND")
    if [[ -n "$SUBDIR" ]]; then
        mkdir -p "$OUTDIR/$SUBDIR"
        FILEPATH="$SUBDIR/${KIND}-${NAME}.yaml"
    else
        FILEPATH="${KIND}-${NAME}.yaml"
    fi

    echo "$DOC" > "$OUTDIR/$FILEPATH"
    echo "  $FILEPATH"
    DOC=""
    INDEX=$((INDEX + 1))
}

while IFS= read -r line; do
    # Skip --- separators
    if [[ "$line" == "---" ]]; then
        flush_doc
        continue
    fi

    # Detect new document: apiVersion at column 0 means a new resource
    if [[ "$line" =~ ^apiVersion: && -n "$DOC" ]]; then
        flush_doc
    fi

    if [[ -n "$DOC" ]]; then
        DOC="$DOC"$'\n'"$line"
    else
        DOC="$line"
    fi
done

# Flush last document
flush_doc

echo "Wrote $INDEX manifests to $OUTDIR"
