#!/usr/bin/env bash
set -euo pipefail

PROJECTS_DIR="${HOME}/Projects"
THIS_PROJECT="${PROJECTS_DIR}/agentic-ai"
USER_SKILLS_DIR="${THIS_PROJECT}/claude/skills"

extract_title() {
    local skill_dir="$1"
    local skill_file
    skill_file=$(find "${skill_dir}" -maxdepth 1 -iname "skill.md" | head -1)
    if [[ -n "${skill_file}" ]]; then
        grep -m1 '^# ' "${skill_file}" | sed 's/^# //'
    else
        echo "-"
    fi
}

print_row() {
    printf "  %-20s %-15s %s\n" "$1" "$2" "$3"
}

print_header() {
    echo ""
    echo "${1}"
    print_row "SCOPE" "SKILL" "DESCRIPTION"
    print_row "-----" "-----" "-----------"
}

print_header "User scope (~/.claude):"
if [[ -d "${USER_SKILLS_DIR}" ]]; then
    for skill_dir in "${USER_SKILLS_DIR}"/*/; do
        [[ -d "${skill_dir}" ]] || continue
        skill=$(basename "${skill_dir}")
        title=$(extract_title "${skill_dir}")
        print_row "~/.claude" "${skill}" "${title}"
    done
fi

print_header "Project scope (~/Projects):"
while IFS= read -r -d '' skills_dir; do
    project_dir=$(dirname "${skills_dir}")
    project=$(basename "${project_dir%/.claude}")
    [[ "${project_dir}" == "${THIS_PROJECT}/.claude" ]] && continue
    for skill_dir in "${skills_dir}"/*/; do
        [[ -d "${skill_dir}" ]] || continue
        skill=$(basename "${skill_dir}")
        title=$(extract_title "${skill_dir}")
        print_row "${project}" "${skill}" "${title}"
    done
done < <(find "${PROJECTS_DIR}" -maxdepth 3 -type d -name skills -path "*/.claude/skills" -print0 2>/dev/null | sort -z)

echo ""
