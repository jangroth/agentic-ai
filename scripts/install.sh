#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/commands"

# Collect planned symlinks as "src|dst" pairs
PLANNED=()
for skill in "${REPO_DIR}/claude/skills/"/*/; do
    PLANNED+=("${skill}|${CLAUDE_DIR}/skills/$(basename "${skill}")")
done
for cmd in "${REPO_DIR}/claude/commands/"/*; do
    PLANNED+=("${cmd}|${CLAUDE_DIR}/commands/$(basename "${cmd}")")
done
PLANNED+=(
    "${REPO_DIR}/claude/settings.json|${CLAUDE_DIR}/settings.json"
    "${REPO_DIR}/claude/statusline-command.sh|${CLAUDE_DIR}/statusline-command.sh"
)

# Classify each planned symlink
CONFLICTS=0
echo ""
echo "Planned actions:"
for entry in "${PLANNED[@]}"; do
    src="${entry%%|*}"
    dst="${entry##*|}"
    if [[ ! -e "${dst}" && ! -L "${dst}" ]]; then
        printf "  [NEW]      %s\n" "${dst}"
    elif [[ -L "${dst}" ]]; then
        printf "  [RELINK]   %s\n" "${dst}"
    else
        printf "  [CONFLICT] %s  <-- real file/directory, will not overwrite\n" "${dst}"
        CONFLICTS=$((CONFLICTS + 1))
    fi
done
echo ""

read -r -p "Proceed with installation? [y/N] " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
for entry in "${PLANNED[@]}"; do
    src="${entry%%|*}"
    dst="${entry##*|}"
    ln -sf "${src}" "${dst}"
    printf "  Linked %s\n" "${dst}"
done
echo ""
echo "Done. Claude config symlinked to ${CLAUDE_DIR}"
