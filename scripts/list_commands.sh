#!/usr/bin/env bash
set -euo pipefail

PROJECTS_DIR="${HOME}/Projects"
THIS_PROJECT="${PROJECTS_DIR}/agentic-ai"
USER_COMMANDS_DIR="${THIS_PROJECT}/claude/commands"

extract_description() {
    local cmd_file="$1"
    grep -m1 '^description:' "${cmd_file}" | sed 's/^description:[[:space:]]*//' || echo "-"
}

print_row() {
    printf "  %-20s %-15s %s\n" "$1" "$2" "$3"
}

print_header() {
    echo ""
    echo "${1}"
    print_row "SCOPE" "COMMAND" "DESCRIPTION"
    print_row "-----" "-------" "-----------"
}

print_header "User scope (~/.claude):"
if [[ -d "${USER_COMMANDS_DIR}" ]]; then
    for cmd_file in "${USER_COMMANDS_DIR}"/*.md; do
        [[ -f "${cmd_file}" ]] || continue
        cmd=$(basename "${cmd_file}" .md)
        description=$(extract_description "${cmd_file}")
        print_row "~/.claude" "${cmd}" "${description}"
    done
fi

print_header "Project scope (~/Projects):"
while IFS= read -r -d '' commands_dir; do
    project_dir=$(dirname "${commands_dir}")
    project=$(basename "${project_dir%/.claude}")
    [[ "${project_dir}" == "${THIS_PROJECT}/.claude" ]] && continue
    for cmd_file in "${commands_dir}"/*.md; do
        [[ -f "${cmd_file}" ]] || continue
        cmd=$(basename "${cmd_file}" .md)
        description=$(extract_description "${cmd_file}")
        print_row "${project}" "${cmd}" "${description}"
    done
done < <(find "${PROJECTS_DIR}" -maxdepth 4 -type d -name commands -path "*/.claude/commands" -print0 2>/dev/null | sort -z)

echo ""
