#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/commands"

ln -sf "${REPO_DIR}/claude/settings.json" "${CLAUDE_DIR}/settings.json"
ln -sf "${REPO_DIR}/claude/statusline-command.sh" "${CLAUDE_DIR}/statusline-command.sh"

for skill in "${REPO_DIR}/claude/skills/"/*/; do
    ln -sf "${skill}" "${CLAUDE_DIR}/skills/$(basename "${skill}")"
done

for cmd in "${REPO_DIR}/claude/commands/"/*; do
    ln -sf "${cmd}" "${CLAUDE_DIR}/commands/$(basename "${cmd}")"
done

echo "Done. Claude config symlinked to ${CLAUDE_DIR}"
