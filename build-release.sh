#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TARGET_DIR=".target"
ARCHIVE="${TARGET_DIR}/subagent-orchestrator.tar.gz"

mkdir -p "${TARGET_DIR}"

echo "Packing codex/ and opencode/ into ${ARCHIVE}..."
tar -czf "${ARCHIVE}" codex/ opencode/

echo "Created: ${ARCHIVE}"
