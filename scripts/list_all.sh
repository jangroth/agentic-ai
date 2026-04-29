#!/usr/bin/env bash
set -uo pipefail

PROJECTS_DIR="${HOME}/Projects"
THIS_PROJECT="${PROJECTS_DIR}/agentic-ai"
TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT

extract_skill_title() {
    local skill_dir="$1"
    local skill_file
    skill_file=$(find "${skill_dir}" -maxdepth 1 -iname "skill.md" | head -1)
    [[ -n "${skill_file}" ]] && grep -m1 '^# ' "${skill_file}" | sed 's/^# //' || echo "-"
}

extract_command_description() {
    grep -m1 '^description:' "$1" | sed 's/^description:[[:space:]]*//' || echo "-"
}

collect_skills() {
    local scope="$1" skills_dir="$2"
    [[ -d "${skills_dir}" ]] || return
    for skill_dir in "${skills_dir}"/*/; do
        [[ -d "${skill_dir}" ]] || continue
        echo "${scope}	skill	$(basename "${skill_dir}")	$(extract_skill_title "${skill_dir}")" >> "${TMPFILE}"
    done
}

collect_commands() {
    local scope="$1" commands_dir="$2"
    [[ -d "${commands_dir}" ]] || return
    for cmd_file in "${commands_dir}"/*.md; do
        [[ -f "${cmd_file}" ]] || continue
        echo "${scope}	command	$(basename "${cmd_file}" .md)	$(extract_command_description "${cmd_file}")" >> "${TMPFILE}"
    done
}

print_header() {
    printf "  %-20s %-10s %-15s %s\n" "SCOPE" "TYPE" "NAME" "DESCRIPTION"
    printf "  %-20s %-10s %-15s %s\n" "-----" "----" "----" "-----------"
}

print_rows_for_scope() {
    local scope="$1"
    grep "^${scope}	" "${TMPFILE}" | while IFS=$'\t' read -r s type name desc; do
        printf "  %-20s %-10s %-15s %s\n" "${s}" "${type}" "${name}" "${desc}"
    done
}

# --- Collect user scope (sourced from this project, displayed as ~/.claude) ---
collect_skills "~/.claude" "${THIS_PROJECT}/claude/skills"
collect_commands "~/.claude" "${THIS_PROJECT}/claude/commands"

# --- Collect project scopes ---
while IFS= read -r -d '' claude_dir; do
    project_dir=$(dirname "${claude_dir}")
    [[ "${project_dir}" == "${THIS_PROJECT}" ]] && continue
    project=$(basename "${project_dir}")
    collect_skills "${project}" "${claude_dir}/skills"
    collect_commands "${project}" "${claude_dir}/commands"
done < <(find "${PROJECTS_DIR}" -maxdepth 4 -type d -name ".claude" -print0 2>/dev/null | sort -z)

# --- Print ---
echo ""
echo "User scope (~/.claude):"
print_header
print_rows_for_scope "~/.claude"

echo ""
echo "Project scope (~/Projects):"
print_header
grep -v "^~/.claude$(printf '\t')" "${TMPFILE}" | sort | while IFS=$'\t' read -r scope type name desc; do
    printf "  %-20s %-10s %-15s %s\n" "${scope}" "${type}" "${name}" "${desc}"
done || true

echo ""
