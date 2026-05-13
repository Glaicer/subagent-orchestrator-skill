#!/usr/bin/env bash
set -euo pipefail

SESSION_TIMESTAMP="${SESSION_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
AGENT_DIR=".agent/${SESSION_TIMESTAMP}"

mkdir -p "${AGENT_DIR}/tasks" "${AGENT_DIR}/reviews" "${AGENT_DIR}/logs"

cat <<EOF
SESSION_TIMESTAMP=${SESSION_TIMESTAMP}
AGENT_DIR=${AGENT_DIR}
EOF
