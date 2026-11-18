#!/usr/bin/env bash
set -uo pipefail

PROJECTS_DIR="${HOME}/Projects"
THIS_PROJECT="${PROJECTS_DIR}/agentic-ai"
CLAUDE_DIR="${HOME}/.claude"
PLUGINS_JSON="${CLAUDE_DIR}/plugins/installed_plugins.json"
DESC_MAX=70
ROWS=$(mktemp)
BROKEN=$(mktemp)
trap 'rm -f "${ROWS}" "${BROKEN}"' EXIT

# Frontmatter `description:`, unquoted, folded to one line, truncated.
extract_description() {
    local file="$1" desc
    [[ -f "${file}" ]] || { echo "-"; return; }
    desc=$(awk '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        collecting && /^[[:space:]]+/ { sub(/^[[:space:]]+/, ""); out = out (out ? " " : "") $0; next }
        collecting { exit }
        /^description:/ {
            sub(/^description:[[:space:]]*/, "")
            if ($0 ~ /^[>|][-+]?$/ || $0 == "") { collecting = 1; next }
            out = $0; exit
        }
        END { print out }
    ' "${file}")
    desc="${desc#[\"\']}"
    desc="${desc%[\"\']}"
    [[ -z "${desc}" ]] && { echo "-"; return; }
    (( ${#desc} > DESC_MAX )) && desc="${desc:0:DESC_MAX-1}…"
    echo "${desc}"
}

skill_file() {
    find "$1" -maxdepth 1 -iname "skill.md" | head -1
}

# A single-hop symlink whose target resolves into this repo's claude/ dir.
is_tracked() {
    local path="${1%/}"
    [[ -L "${path}" ]] || return 1
    [[ "$(readlink "${path}")" == "${THIS_PROJECT}/claude/"* ]]
}

# section, scope, type, name, tracked, description
add_row() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "${ROWS}"
}

# Disabled plugin installs are counted, not listed.
PLUGIN_STATE=""
PLUGIN_HIDDEN=0
add_plugin_row() {
    if [[ "${PLUGIN_STATE}" == "enabled" ]]; then
        add_row "plugins" "$@"
    else
        PLUGIN_HIDDEN=$((PLUGIN_HIDDEN + 1))
    fi
}

find_broken_links() {
    local dir="$1" entry
    [[ -d "${dir}" ]] || return
    for entry in "${dir}"/*; do
        [[ -L "${entry}" && ! -e "${entry}" ]] && echo "${entry} -> $(readlink "${entry}")" >> "${BROKEN}"
    done
}

# Collect skills/commands/agents from a .claude-style dir.
collect_dir() {
    local section="$1" scope="$2" base="$3" track="$4" path name tracked
    for path in "${base}/skills"/*/; do
        [[ -d "${path}" ]] || continue
        name=$(basename "${path}")
        [[ "${base}" == "${CLAUDE_DIR}" && "${name}" == "synced" ]] && continue
        tracked="-"
        [[ "${track}" == "yes" ]] && { is_tracked "${path}" && tracked="yes" || tracked="no"; }
        add_row "${section}" "${scope}" "skill" "${name}" "${tracked}" "$(extract_description "$(skill_file "${path}")")"
    done
    local kind
    for kind in commands agents; do
        for path in "${base}/${kind}"/*.md; do
            [[ -f "${path}" ]] || continue
            tracked="-"
            [[ "${track}" == "yes" ]] && { is_tracked "${path}" && tracked="yes" || tracked="no"; }
            add_row "${section}" "${scope}" "${kind%s}" "$(basename "${path}" .md)" "${tracked}" "$(extract_description "${path}")"
        done
    done
}

collect_synced() {
    local file
    while IFS= read -r file; do
        add_row "synced" "claude.ai" "skill" "$(basename "$(dirname "${file}")")" "-" "$(extract_description "${file}")"
    done < <(find "${CLAUDE_DIR}/skills/synced" -mindepth 3 -maxdepth 3 -iname "skill.md" 2>/dev/null | sort)
}

# Paths a plugin manifest field names (string or array), defaulting to ./<kind>/.
manifest_paths() {
    local manifest="$1" kind="$2"
    if [[ -f "${manifest}" ]]; then
        jq -r --arg k "${kind}" '.[$k] // ("./" + $k + "/") | if type == "array" then .[] else . end' "${manifest}"
    else
        echo "./${kind}/"
    fi
}

plugin_enabled() {
    local key="$1" scope="$2" project="$3" f
    local files=("${CLAUDE_DIR}/settings.json")
    [[ "${scope}" != "user" ]] && files=("${project}/.claude/settings.json" "${project}/.claude/settings.local.json")
    for f in "${files[@]}"; do
        [[ -f "${f}" ]] && [[ "$(jq -r --arg k "${key}" '.enabledPlugins[$k] // empty' "${f}")" == "true" ]] && return 0
    done
    return 1
}

collect_plugins() {
    [[ -f "${PLUGINS_JSON}" ]] || return
    local key scope project install manifest name state rel target dir file
    while IFS=$'\t' read -r key scope project install; do
        name="${key%@*}"
        manifest="${install}/.claude-plugin/plugin.json"
        state="disabled"
        plugin_enabled "${key}" "${scope}" "${project}" && state="enabled"
        PLUGIN_STATE="${state}"
        PLUGIN_HIDDEN=0
        local label="${name} (${scope}"
        [[ "${scope}" != "user" ]] && label+=": $(basename "${project}")"
        label+=", ${state})"

        while IFS= read -r rel; do
            target="${install}/${rel#./}"
            target="${target%/}"
            if [[ -n "$(skill_file "${target}" 2>/dev/null)" ]]; then
                add_plugin_row "${label}" "skill" "$(basename "${target}")" "-" "$(extract_description "$(skill_file "${target}")")"
            else
                for dir in "${target}"/*/; do
                    file=$(skill_file "${dir}" 2>/dev/null)
                    [[ -n "${file}" ]] || continue
                    add_plugin_row "${label}" "skill" "$(basename "${dir}")" "-" "$(extract_description "${file}")"
                done
            fi
        done < <(manifest_paths "${manifest}" skills)

        local kind
        for kind in commands agents; do
            while IFS= read -r rel; do
                target="${install}/${rel#./}"
                if [[ -f "${target}" ]]; then
                    add_plugin_row "${label}" "${kind%s}" "$(basename "${target}" .md)" "-" "$(extract_description "${target}")"
                else
                    for file in "${target%/}"/*.md; do
                        [[ -f "${file}" ]] || continue
                        add_plugin_row "${label}" "${kind%s}" "$(basename "${file}" .md)" "-" "$(extract_description "${file}")"
                    done
                fi
            done < <(manifest_paths "${manifest}" "${kind}")
        done
        (( PLUGIN_HIDDEN > 0 )) && add_row "plugins" "${label}" "-" "-" "-" "${PLUGIN_HIDDEN} items not loaded"
    done < <(jq -r '.plugins | to_entries[] | .key as $k | .value[] | [$k, .scope, (.projectPath // "-"), .installPath] | @tsv' "${PLUGINS_JSON}")
}

collect_projects() {
    local claude_dir project_dir
    while IFS= read -r -d '' claude_dir; do
        project_dir=$(dirname "${claude_dir}")
        [[ "${project_dir}" == "${THIS_PROJECT}" ]] && continue
        collect_dir "projects" "${project_dir#"${PROJECTS_DIR}/"}" "${claude_dir}" "no"
    done < <(find "${PROJECTS_DIR}" -maxdepth 4 -type d -name ".claude" -print0 2>/dev/null | sort -z)
}

# Aligns columns per section; TRACKED only where it means something.
print_section() {
    local section="$1" title="$2" with_tracked="$3"
    echo ""
    echo "${title}:"
    if ! grep -q "^${section}	" "${ROWS}"; then
        echo "  (none)"
        return
    fi
    grep "^${section}	" "${ROWS}" | awk -F'\t' -v tracked="${with_tracked}" '
        BEGIN { n = 0 }
        {
            n++
            scope[n] = $2; type[n] = $3; name[n] = $4; trk[n] = $5; desc[n] = $6
            if (length($2) > ws) ws = length($2)
            if (length($4) > wn) wn = length($4)
        }
        END {
            if (ws < 5) ws = 5
            if (wn < 4) wn = 4
            if (tracked == "yes") {
                printf "  %-*s  %-7s  %-*s  %-7s  %s\n", ws, "SCOPE", "TYPE", wn, "NAME", "TRACKED", "DESCRIPTION"
                for (i = 1; i <= n; i++) printf "  %-*s  %-7s  %-*s  %-7s  %s\n", ws, scope[i], type[i], wn, name[i], trk[i], desc[i]
            } else {
                printf "  %-*s  %-7s  %-*s  %s\n", ws, "SCOPE", "TYPE", wn, "NAME", "DESCRIPTION"
                for (i = 1; i <= n; i++) printf "  %-*s  %-7s  %-*s  %s\n", ws, scope[i], type[i], wn, name[i], desc[i]
            }
        }'
}

# --- Collect (user scope reads the live ~/.claude, not the repo mirror, so untracked drift shows up) ---
# shellcheck disable=SC2088  # literal label
collect_dir "user" "~/.claude" "${CLAUDE_DIR}" "yes"
collect_synced
collect_plugins
collect_projects
for d in skills commands agents; do
    find_broken_links "${CLAUDE_DIR}/${d}"
done

# --- Print ---
print_section "user" "User scope (~/.claude)" "yes"
print_section "synced" "Synced from claude.ai" "no"
print_section "plugins" "Plugins" "no"
print_section "projects" "Project scope (~/Projects)" "no"

echo ""
if [[ -s "${BROKEN}" ]]; then
    echo "Broken links:"
    sed 's/^/  /' "${BROKEN}"
    echo ""
    exit 1
fi
