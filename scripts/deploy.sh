#!/usr/bin/env bash
# deploy.sh — render and deploy a k8s YAML with live substitution
# Usage: deploy.sh <yaml-file> [secret-yaml] [secret-yaml-2]
# Set NOPROMPT=1 to skip interactive prompts and use saved defaults.
set -euo pipefail

YAML_FILE="$1"
EXTRA="${2:-}"       # optional secret yaml to apply first
EXTRA2="${3:-}"      # optional second secret yaml to apply first

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DEFAULTS="${SCRIPT_DIR}/../.push-defaults"
AC_DEFAULTS="${SCRIPT_DIR}/../../agent-swarm/.push-defaults"
if [[ -f "$AC_DEFAULTS" ]]; then
    DEFAULTS_FILE="$AC_DEFAULTS"
else
    DEFAULTS_FILE="$LOCAL_DEFAULTS"
fi
if [[ ! -f "$DEFAULTS_FILE" && ! -f "$LOCAL_DEFAULTS" ]]; then
    echo "Error: no .push-defaults found. Run a build target first." >&2
    exit 1
fi

# ── Read saved values (agent-swarm first, then local) ────────────────────────
_get() {
    local val=""
    [[ -f "$DEFAULTS_FILE" ]] && val=$(grep "^${1}=" "$DEFAULTS_FILE" | cut -d= -f2- || true)
    [[ -z "$val" && -f "$LOCAL_DEFAULTS" && "$LOCAL_DEFAULTS" != "$DEFAULTS_FILE" ]] && \
        val=$(grep "^${1}=" "$LOCAL_DEFAULTS" | cut -d= -f2- || true)
    echo "$val"
}

REGISTRY=$(              _get REGISTRY)
IMAGE_TAG=$(             _get IMAGE_TAG);  IMAGE_TAG="${IMAGE_TAG:-latest}"
SAVED_NAMESPACE=$(       _get NAMESPACE)
SAVED_PULL_SECRET_FILE=$(_get IMAGE_PULL_SECRET_FILE)

if [[ -z "$REGISTRY" ]]; then
    echo "Error: REGISTRY not set in .push-defaults. Run a build target first." >&2
    exit 1
fi

echo ""
echo "=== Deploy: $(basename "$YAML_FILE") ==="
echo "    Registry : ${REGISTRY}"
echo "    IMAGE_TAG: ${IMAGE_TAG}"

# ── Prompt: namespace ────────────────────────────────────────────────────────
if [[ "${NOPROMPT:-}" == "1" ]]; then
    NAMESPACE="${SAVED_NAMESPACE}"
    IMAGE_PULL_SECRET_FILE="${SAVED_PULL_SECRET_FILE}"
    echo "    Namespace: ${NAMESPACE:-<cluster default>}"
    echo "    imagePullSecret file: ${IMAGE_PULL_SECRET_FILE:-<none>}"
else
    if [[ -n "$SAVED_NAMESPACE" ]]; then
        read -rp "Namespace             [${SAVED_NAMESPACE}] (Enter=keep, '-'=clear): " INPUT
        if [[ "$INPUT" == "-" ]]; then
            NAMESPACE=""
        else
            NAMESPACE="${INPUT:-$SAVED_NAMESPACE}"
        fi
    else
        read -rp "Namespace             (Enter for cluster default): " NAMESPACE
    fi

    # ── Prompt: imagePullSecret file ─────────────────────────────────────────────
    if [[ -n "$SAVED_PULL_SECRET_FILE" ]]; then
        read -rp "imagePullSecret file  [${SAVED_PULL_SECRET_FILE}] (Enter=keep, '-'=clear): " INPUT
        if [[ "$INPUT" == "-" ]]; then
            IMAGE_PULL_SECRET_FILE=""
        else
            IMAGE_PULL_SECRET_FILE="${INPUT:-$SAVED_PULL_SECRET_FILE}"
        fi
    else
        read -rp "imagePullSecret file  (Enter to skip): " IMAGE_PULL_SECRET_FILE
    fi
fi

# ── Extract pull secret name from file ───────────────────────────────────────
IMAGE_PULL_SECRET=""
if [[ -n "$IMAGE_PULL_SECRET_FILE" && -f "$IMAGE_PULL_SECRET_FILE" ]]; then
    IMAGE_PULL_SECRET=$(grep -A5 '^metadata:' "$IMAGE_PULL_SECRET_FILE" | grep '^\s*name:' | head -1 | awk '{print $2}')
fi

# ── Persist machine-specific defaults to local file ─────────────────────────
{
    grep -v '^IMAGE_PULL_SECRET_FILE=' "$LOCAL_DEFAULTS" 2>/dev/null \
        | grep -v '^NAMESPACE=' \
        | grep -v '^REGISTRY=' \
        | grep -v '^IMAGE_TAG=' || true
    [[ -n "$NAMESPACE"               ]] && echo "NAMESPACE=${NAMESPACE}"
    [[ -n "$IMAGE_PULL_SECRET_FILE"  ]] && echo "IMAGE_PULL_SECRET_FILE=${IMAGE_PULL_SECRET_FILE}"
} > "${LOCAL_DEFAULTS}.tmp" && mv "${LOCAL_DEFAULTS}.tmp" "$LOCAL_DEFAULTS"

# ── Render YAML ──────────────────────────────────────────────────────────────
render() {
    local pull_block=""
    if [[ -n "$IMAGE_PULL_SECRET" ]]; then
        pull_block="  imagePullSecrets:\n    - name: ${IMAGE_PULL_SECRET}"
    fi

    if [[ -n "$IMAGE_PULL_SECRET" ]]; then
        sed \
            -e "s|REGISTRY|${REGISTRY}|g" \
            -e "s|IMAGE_TAG|${IMAGE_TAG}|g" \
            -e "s|  IMAGE_PULL_SECRET_BLOCK|${pull_block}|" \
            "$YAML_FILE"
    else
        sed \
            -e "s|REGISTRY|${REGISTRY}|g" \
            -e "s|IMAGE_TAG|${IMAGE_TAG}|g" \
            -e "/  IMAGE_PULL_SECRET_BLOCK/d" \
            "$YAML_FILE"
    fi
}

# ── Deploy ───────────────────────────────────────────────────────────────────
NS_FLAG=()
if [[ -n "$NAMESPACE" ]]; then
    NS_FLAG=(-n "$NAMESPACE")
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "    Creating namespace: ${NAMESPACE}"
        kubectl create namespace "$NAMESPACE"
    fi
fi

[[ -n "$IMAGE_PULL_SECRET_FILE" ]] && kubectl apply "${NS_FLAG[@]}" -f "$IMAGE_PULL_SECRET_FILE"
[[ -n "$EXTRA"  ]] && kubectl apply "${NS_FLAG[@]}" -f "$EXTRA"
[[ -n "$EXTRA2" ]] && kubectl apply "${NS_FLAG[@]}" -f "$EXTRA2"
render | kubectl apply "${NS_FLAG[@]}" -f -
