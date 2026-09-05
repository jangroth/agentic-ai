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

# A single-hop symlink whose target resolves into this repo's claude/ dir.
is_tracked() {
    local path="${1%/}"
    [[ -L "${path}" ]] || return 1
    [[ "$(readlink "${path}")" == "${THIS_PROJECT}/claude/"* ]]
}

collect_skills() {
    local scope="$1" skills_dir="$2"
    [[ -d "${skills_dir}" ]] || return
    for skill_dir in "${skills_dir}"/*/; do
        [[ -d "${skill_dir}" ]] || continue
        local tracked="no"
        is_tracked "${skill_dir}" && tracked="yes"
        echo "${scope}	skill	$(basename "${skill_dir}")	${tracked}	$(extract_skill_title "${skill_dir}")" >> "${TMPFILE}"
    done
}

collect_commands() {
    local scope="$1" commands_dir="$2"
    [[ -d "${commands_dir}" ]] || return
    for cmd_file in "${commands_dir}"/*.md; do
        [[ -f "${cmd_file}" ]] || continue
        local tracked="no"
        is_tracked "${cmd_file}" && tracked="yes"
        echo "${scope}	command	$(basename "${cmd_file}" .md)	${tracked}	$(extract_command_description "${cmd_file}")" >> "${TMPFILE}"
    done
}

print_header() {
    printf "  %-20s %-10s %-15s %-9s %s\n" "SCOPE" "TYPE" "NAME" "TRACKED" "DESCRIPTION"
    printf "  %-20s %-10s %-15s %-9s %s\n" "-----" "----" "----" "-------" "-----------"
}

print_rows_for_scope() {
    local scope="$1"
    grep "^${scope}	" "${TMPFILE}" | while IFS=$'\t' read -r s type name tracked desc; do
        printf "  %-20s %-10s %-15s %-9s %s\n" "${s}" "${type}" "${name}" "${tracked}" "${desc}"
    done
}

# --- Collect user scope (read from the live ~/.claude, not the repo mirror, so untracked drift shows up) ---
collect_skills "~/.claude" "${HOME}/.claude/skills"
collect_commands "~/.claude" "${HOME}/.claude/commands"

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
grep -v "^~/.claude$(printf '\t')" "${TMPFILE}" | sort | while IFS=$'\t' read -r scope type name tracked desc; do
    printf "  %-20s %-10s %-15s %-9s %s\n" "${scope}" "${type}" "${name}" "${tracked}" "${desc}"
done || true

echo ""
