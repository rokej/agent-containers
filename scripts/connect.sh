#!/usr/bin/env bash
# connect.sh — port-forward an opencode K8s pod to localhost:4096
# Usage: connect.sh <opencode>
set -euo pipefail

POD="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DEFAULTS="${SCRIPT_DIR}/../.push-defaults"
AC_DEFAULTS="${SCRIPT_DIR}/../../agent-swarm/.push-defaults"

NAMESPACE=""
[[ -f "$LOCAL_DEFAULTS" ]] && NAMESPACE=$(grep '^NAMESPACE=' "$LOCAL_DEFAULTS" | cut -d= -f2- || true)
[[ -z "$NAMESPACE" && -f "$AC_DEFAULTS" ]] && NAMESPACE=$(grep '^NAMESPACE=' "$AC_DEFAULTS" | cut -d= -f2- || true)
if [[ -z "$NAMESPACE" && ! -f "$LOCAL_DEFAULTS" && ! -f "$AC_DEFAULTS" ]]; then
    echo "Error: no .push-defaults found. Run a build target first." >&2
    exit 1
fi

NS_FLAG=()
[[ -n "$NAMESPACE" ]] && NS_FLAG=(-n "$NAMESPACE")

echo ""
echo "=== Connect: ${POD} ==="
[[ -n "$NAMESPACE" ]] && echo "    Namespace: ${NAMESPACE}"
echo "    Forwarding pod/${POD} -> localhost:4096"
echo "    Press Ctrl+C to stop"
echo ""

kubectl port-forward "pod/${POD}" 4096:4096 "${NS_FLAG[@]}"
