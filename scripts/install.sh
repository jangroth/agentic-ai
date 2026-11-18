#!/usr/bin/env bash
set -euo pipefail

FORCE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    exit 1
fi
MISSING_DEPS=()
for bin in git gh bc claude; do
    command -v "${bin}" >/dev/null 2>&1 || MISSING_DEPS+=("${bin}")
done
HAS_CLAUDE=1
command -v claude >/dev/null 2>&1 || HAS_CLAUDE=0

CLAUDE_DIR="${HOME}/.claude"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS_DIR="${CLAUDE_DIR}/plugins"

BASE_SETTINGS="${REPO_DIR}/claude/settings.json"
LOCAL_SETTINGS="${REPO_DIR}/claude/settings.local.json"
DST_SETTINGS="${CLAUDE_DIR}/settings.json"

mkdir -p "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/commands"

# Collect planned symlinks as "src|dst" pairs (settings.json is handled separately: merged, not linked)
PLANNED=()
for skill in "${REPO_DIR}/claude/skills/"/*/; do
    PLANNED+=("${skill}|${CLAUDE_DIR}/skills/$(basename "${skill}")")
done
for cmd in "${REPO_DIR}/claude/commands/"/*; do
    PLANNED+=("${cmd}|${CLAUDE_DIR}/commands/$(basename "${cmd}")")
done
PLANNED+=(
    "${REPO_DIR}/claude/statusline-command.sh|${CLAUDE_DIR}/statusline-command.sh"
    "${REPO_DIR}/claude/CLAUDE.md|${CLAUDE_DIR}/CLAUDE.md"
)

# Classify each planned symlink. A real (non-symlink) file/dir at dst is content that
# hasn't been integrated into this repo yet, so it's never auto-overwritten, even with --force.
CONFLICTS=()
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
        printf "  [CONFLICT] %s  <-- real file/directory, will NOT be touched\n" "${dst}"
        CONFLICTS+=("${dst}")
    fi
done

# --- settings.json: merge base + local, and never silently clobber unintegrated live content ---
MERGED_TMP="$(mktemp)"
trap 'rm -f "${MERGED_TMP}"' EXIT

if [[ -f "${LOCAL_SETTINGS}" ]]; then
    jq -s '.[0] * .[1]' "${BASE_SETTINGS}" "${LOCAL_SETTINGS}" > "${MERGED_TMP}"
else
    jq '.' "${BASE_SETTINGS}" > "${MERGED_TMP}"
fi

# Drift only matters for a real generated/hand-edited file. A leftover symlink from an
# older version of this script points AT the repo file, so there's nothing to lose there.
SETTINGS_HAS_DRIFT=0
if [[ -f "${DST_SETTINGS}" && ! -L "${DST_SETTINGS}" ]]; then
    if ! diff -q <(jq -S . "${DST_SETTINGS}") <(jq -S . "${MERGED_TMP}") >/dev/null 2>&1; then
        SETTINGS_HAS_DRIFT=1
    fi
fi

if [[ "${SETTINGS_HAS_DRIFT}" -eq 1 && "${FORCE}" -eq 0 ]]; then
    printf "  [CONFLICT] %s  <-- differs from claude/settings.json + settings.local.json, will NOT be touched\n" "${DST_SETTINGS}"
else
    if [[ -f "${LOCAL_SETTINGS}" ]]; then
        printf "  [MERGE]    %s  <-- claude/settings.json + claude/settings.local.json\n" "${DST_SETTINGS}"
    else
        printf "  [MERGE]    %s  <-- claude/settings.json (no claude/settings.local.json on this machine)\n" "${DST_SETTINGS}"
    fi
fi

# --- Plugins: install what the merged settings enable but this machine lacks (user scope) ---
MARKETPLACES_TO_ADD=()
PLUGINS_TO_INSTALL=()
while IFS=$'\t' read -r name source; do
    [[ -n "${name}" ]] || continue
    if ! jq -e --arg n "${name}" 'has($n)' "${PLUGINS_DIR}/known_marketplaces.json" >/dev/null 2>&1; then
        MARKETPLACES_TO_ADD+=("${name}|${source}")
    fi
done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[] | [.key, (.value.source.repo // .value.source.url // .value.source.path)] | @tsv' "${MERGED_TMP}")
while IFS= read -r key; do
    [[ -n "${key}" ]] || continue
    if ! jq -e --arg k "${key}" '.plugins[$k] // [] | any(.scope == "user")' "${PLUGINS_DIR}/installed_plugins.json" >/dev/null 2>&1; then
        PLUGINS_TO_INSTALL+=("${key}")
    fi
done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "${MERGED_TMP}")

for entry in ${MARKETPLACES_TO_ADD[@]+"${MARKETPLACES_TO_ADD[@]}"}; do
    printf "  [MARKET]   %s  <-- %s\n" "${entry%%|*}" "${entry##*|}"
done
for key in ${PLUGINS_TO_INSTALL[@]+"${PLUGINS_TO_INSTALL[@]}"}; do
    if [[ "${HAS_CLAUDE}" -eq 1 ]]; then
        printf "  [PLUGIN]   %s\n" "${key}"
    else
        printf "  [SKIP]     plugin %s  <-- claude CLI not found\n" "${key}"
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo ""
    echo "Missing: ${MISSING_DEPS[*]}. The status line needs git and bc; /todo needs gh; plugins need claude."
fi
echo ""

if [[ "${SETTINGS_HAS_DRIFT}" -eq 1 ]]; then
    echo "${DST_SETTINGS} has content that doesn't match this repo"
    echo "(- = only on this machine right now, + = what the repo would produce):"
    echo ""
    diff -u <(jq -S . "${DST_SETTINGS}") <(jq -S . "${MERGED_TMP}") | sed 's/^/  /' || true
    echo ""
    if [[ "${FORCE}" -eq 0 ]]; then
        echo "This would be refused (or, with --force, overwritten — a .bak is kept either way)."
        echo ""
    fi
fi

# Prints what would be/was left untouched. Returns 1 if there's anything to report, 0 otherwise.
report_conflicts() {
    if [[ ${#CONFLICTS[@]} -eq 0 && ! ( "${SETTINGS_HAS_DRIFT}" -eq 1 && "${FORCE}" -eq 0 ) ]]; then
        return 0
    fi
    echo "Left untouched:"
    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        for c in "${CONFLICTS[@]}"; do
            echo "  - ${c}"
        done
    fi
    if [[ "${SETTINGS_HAS_DRIFT}" -eq 1 && "${FORCE}" -eq 0 ]]; then
        echo "  - ${DST_SETTINGS}"
    fi
    echo "Resolve manually (settings.json can also be forced with --force), then re-run."
    return 1
}

if [[ "${DRY_RUN}" -eq 1 ]]; then
    if report_conflicts; then
        echo "Dry run: everything above would apply cleanly. Nothing was changed."
        exit 0
    fi
    echo ""
    echo "Dry run only — nothing was changed."
    exit 1
fi

read -r -p "Proceed with installation? [y/N] " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
for entry in "${PLANNED[@]}"; do
    src="${entry%%|*}"
    dst="${entry##*|}"
    if [[ -e "${dst}" && ! -L "${dst}" ]]; then
        continue  # conflict: never touch unintegrated real files/directories
    fi
    ln -sfn "${src}" "${dst}"
    printf "  Linked %s\n" "${dst}"
done

if [[ "${SETTINGS_HAS_DRIFT}" -eq 0 || "${FORCE}" -eq 1 ]]; then
    if [[ -L "${DST_SETTINGS}" ]]; then
        rm -f "${DST_SETTINGS}"  # break a leftover symlink from an older version of this script
    elif [[ -f "${DST_SETTINGS}" ]]; then
        cp "${DST_SETTINGS}" "${DST_SETTINGS}.bak"
    fi
    cp "${MERGED_TMP}" "${DST_SETTINGS}"
    printf "  Generated %s\n" "${DST_SETTINGS}"
else
    printf "  Skipped %s (unintegrated local changes — see above)\n" "${DST_SETTINGS}"
fi

PLUGIN_FAILURES=()
if [[ "${HAS_CLAUDE}" -eq 1 ]]; then
    for entry in ${MARKETPLACES_TO_ADD[@]+"${MARKETPLACES_TO_ADD[@]}"}; do
        if claude plugin marketplace add "${entry##*|}" >/dev/null 2>&1; then
            printf "  Added marketplace %s\n" "${entry%%|*}"
        else
            PLUGIN_FAILURES+=("marketplace ${entry%%|*}")
        fi
    done
    for key in ${PLUGINS_TO_INSTALL[@]+"${PLUGINS_TO_INSTALL[@]}"}; do
        if claude plugin install "${key}" >/dev/null 2>&1; then
            printf "  Installed plugin %s\n" "${key}"
        else
            PLUGIN_FAILURES+=("plugin ${key}")
        fi
    done
fi

echo ""
STATUS=0
report_conflicts || STATUS=1
if [[ ${#PLUGIN_FAILURES[@]} -gt 0 ]]; then
    echo "Failed: ${PLUGIN_FAILURES[*]}. Retry with 'claude plugin install <name>'."
    STATUS=1
fi
if [[ "${HAS_CLAUDE}" -eq 0 && ${#PLUGINS_TO_INSTALL[@]} -gt 0 ]]; then
    echo "Plugins not installed: claude CLI not found. Install it, then re-run."
    STATUS=1
fi
[[ "${STATUS}" -eq 0 ]] && echo "Done. Claude config symlinked to ${CLAUDE_DIR}"
exit "${STATUS}"
