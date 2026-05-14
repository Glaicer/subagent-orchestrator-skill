#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/Glaicer/skill-subagent-orchestrator/main"

# Determine which platforms to install
INSTALL_CODEX=false
INSTALL_OPENCODE=false

if [ $# -eq 0 ]; then
    INSTALL_CODEX=true
    INSTALL_OPENCODE=true
else
    for arg in "$@"; do
        case "$arg" in
            -codex)
                INSTALL_CODEX=true
                ;;
            -opencode)
                INSTALL_OPENCODE=true
                ;;
            *)
                echo "Unknown argument: $arg" >&2
                echo "Usage: $0 [-codex] [-opencode]" >&2
                exit 1
                ;;
        esac
    done
fi

download_file() {
    local src_url="$1"
    local dest_path="$2"
    local dest_dir
    dest_dir="$(dirname "$dest_path")"

    mkdir -p "$dest_dir"
    echo "Downloading: $src_url -> $dest_path"
    wget -q -O "$dest_path" "$src_url"
}

if [ "$INSTALL_CODEX" = true ]; then
    echo "=== Installing for Codex ==="

    download_file "$REPO_URL/codex/agents/architect.toml" "$HOME/.codex/agents/architect.toml"
    download_file "$REPO_URL/codex/agents/developer.toml" "$HOME/.codex/agents/developer.toml"
    download_file "$REPO_URL/codex/agents/reviewer.toml" "$HOME/.codex/agents/reviewer.toml"

    download_file "$REPO_URL/codex/skills/codex-orchestrator-subagents/SKILL.md" "$HOME/.codex/skills/codex-orchestrator-subagents/SKILL.md"
    download_file "$REPO_URL/codex/skills/codex-orchestrator-subagents/assets/fix-prompt-template.md" "$HOME/.codex/skills/codex-orchestrator-subagents/assets/fix-prompt-template.md"
    download_file "$REPO_URL/codex/skills/codex-orchestrator-subagents/assets/task-prompt-template.md" "$HOME/.codex/skills/codex-orchestrator-subagents/assets/task-prompt-template.md"
    download_file "$REPO_URL/codex/skills/codex-orchestrator-subagents/references/codex-subagents.md" "$HOME/.codex/skills/codex-orchestrator-subagents/references/codex-subagents.md"
    download_file "$REPO_URL/codex/skills/codex-orchestrator-subagents/references/review-contract.md" "$HOME/.codex/skills/codex-orchestrator-subagents/references/review-contract.md"
    download_file "$REPO_URL/codex/skills/codex-orchestrator-subagents/scripts/init-session.sh" "$HOME/.codex/skills/codex-orchestrator-subagents/scripts/init-session.sh"

    chmod +x "$HOME/.codex/skills/codex-orchestrator-subagents/scripts/init-session.sh"
    echo "Codex installation complete."
fi

if [ "$INSTALL_OPENCODE" = true ]; then
    echo "=== Installing for Opencode ==="

    download_file "$REPO_URL/opencode/agents/architect.md" "$HOME/.config/opencode/agents/architect.md"
    download_file "$REPO_URL/opencode/agents/developer.md" "$HOME/.config/opencode/agents/developer.md"
    download_file "$REPO_URL/opencode/agents/reviewer.md" "$HOME/.config/opencode/agents/reviewer.md"

    download_file "$REPO_URL/opencode/skills/opencode-orchestrator-subagents/SKILL.md" "$HOME/.config/opencode/skills/opencode-orchestrator-subagents/SKILL.md"
    download_file "$REPO_URL/opencode/skills/opencode-orchestrator-subagents/assets/fix-prompt-template.md" "$HOME/.config/opencode/skills/opencode-orchestrator-subagents/assets/fix-prompt-template.md"
    download_file "$REPO_URL/opencode/skills/opencode-orchestrator-subagents/assets/task-prompt-template.md" "$HOME/.config/opencode/skills/opencode-orchestrator-subagents/assets/task-prompt-template.md"
    download_file "$REPO_URL/opencode/skills/opencode-orchestrator-subagents/references/opencode-subagents.md" "$HOME/.config/opencode/skills/opencode-orchestrator-subagents/references/opencode-subagents.md"
    download_file "$REPO_URL/opencode/skills/opencode-orchestrator-subagents/references/review-contract.md" "$HOME/.config/opencode/skills/opencode-orchestrator-subagents/references/review-contract.md"
    download_file "$REPO_URL/opencode/skills/opencode-orchestrator-subagents/scripts/init-session.sh" "$HOME/.config/opencode/skills/opencode-orchestrator-subagents/scripts/init-session.sh"

    chmod +x "$HOME/.config/opencode/skills/opencode-orchestrator-subagents/scripts/init-session.sh"
    echo "Opencode installation complete."
fi

echo "=== All done ==="
