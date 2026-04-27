#!/usr/bin/env bash
input=$(cat)

# ── Core fields ───────────────────────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name')
model_ctx=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
session_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# ── Git ───────────────────────────────────────────────────────────────────────
git_branch=$(echo "$input" | jq -r '.worktree.branch // empty')
if [ -z "$git_branch" ]; then
  git_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
fi

git_diff=""
if [ -n "$git_branch" ]; then
  git_add=$(git -C "$cwd" diff HEAD --numstat 2>/dev/null | awk '{s+=$1} END {print s+0}')
  git_del=$(git -C "$cwd" diff HEAD --numstat 2>/dev/null | awk '{s+=$2} END {print s+0}')
  if [ "$((git_add + git_del))" -gt 0 ]; then
    git_diff="(+${git_add},-${git_del})"
  fi
fi

# ── Model context size label ──────────────────────────────────────────────────
model_ctx_label=""
if [ -n "$model_ctx" ] && [ "$model_ctx" -gt 0 ] 2>/dev/null; then
  if [ "$model_ctx" -ge 1000000 ]; then
    model_ctx_label="$(echo "$model_ctx / 1000000" | bc)M ctx"
  else
    model_ctx_label="$(echo "$model_ctx / 1000" | bc)k ctx"
  fi
fi

# ── Context window display ────────────────────────────────────────────────────
ctx_str=""
if [ -n "$used_pct" ]; then
  ctx_pct="$(printf '%.0f' "$used_pct")%"
  if [ -n "$total_in" ] && [ "$total_in" -gt 0 ] 2>/dev/null; then
    ctx_k="$(printf '%.1f' "$(echo "$total_in / 1000" | bc -l)")k"
    ctx_str="Ctx: ${ctx_k} (${ctx_pct})"
  else
    ctx_str="Ctx: (${ctx_pct})"
  fi
fi

# ── Session duration ──────────────────────────────────────────────────────────
duration_str=""
if [ -n "$session_duration_ms" ] && [ "$session_duration_ms" -gt 0 ] 2>/dev/null; then
  dur_s=$((session_duration_ms / 1000))
  dur_m=$((dur_s / 60))
  dur_h=$((dur_m / 60))
  dur_m_rem=$((dur_m % 60))
  if [ "$dur_h" -gt 0 ]; then
    duration_str="${dur_h}h${dur_m_rem}m"
  else
    duration_str="${dur_m}m"
  fi
fi

# ── Cost ──────────────────────────────────────────────────────────────────────
cost_str=""
if [ -n "$session_cost" ] && [ "$(echo "$session_cost > 0" | bc -l 2>/dev/null)" = "1" ]; then
  cost_str=$(printf '$%.2f' "$session_cost")
fi

# ── Rate limits with time remaining ──────────────────────────────────────────
fmt_remaining() {
  local reset_at=$1
  [ -z "$reset_at" ] && return
  local now
  now=$(date +%s)
  local secs=$(( reset_at - now ))
  [ "$secs" -le 0 ] && return
  local h=$((secs / 3600))
  local m=$(( (secs % 3600) / 60 ))
  if [ "$h" -gt 0 ]; then
    printf "~%dh%02dm" "$h" "$m"
  else
    printf "~%dm" "$m"
  fi
}

five_hour=${five_hour:-0}
rate_5h="5h $(printf '%.0f' "$five_hour")%"
rem=$(fmt_remaining "$five_hour_reset")
[ -n "$rem" ] && rate_5h="$rate_5h $rem"

rate_7d=""
if [ -n "$seven_day" ]; then
  rate_7d="7d $(printf '%.0f' "$seven_day")%"
  rem=$(fmt_remaining "$seven_day_reset")
  [ -n "$rem" ] && rate_7d="$rate_7d $rem"
fi

# ── Transcript: tool history + agent count ────────────────────────────────────
tool_history=""
agent_total=0
agent_active=0
mcp_count=0

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  all_tools=$(jq -r '
    select(.type == "assistant") |
    .message.content[]? |
    select(.type == "tool_use") |
    .name
  ' "$transcript_path" 2>/dev/null)

  if [ -n "$all_tools" ]; then
    agent_total=$(echo "$all_tools" | grep -c '^Agent$' 2>/dev/null || echo 0)
    mcp_count=$(echo "$all_tools" | grep -c '^mcp__' 2>/dev/null || echo 0)

    # Count completed agents (tool results for Agent calls)
    agent_done=$(jq -r '
      select(.type == "tool") |
      .content[]? |
      select(.type == "tool_result") |
      .tool_use_id
    ' "$transcript_path" 2>/dev/null | wc -l | tr -d ' ')
    agent_active=$(( agent_total - agent_done ))
    [ "$agent_active" -lt 0 ] && agent_active=0
  fi

  labeled_tools=$(jq -r '
    select(.type == "assistant") |
    .message.content[]? |
    select(.type == "tool_use") |
    (.name as $n | .input |
      if $n == "Read" or $n == "Edit" or $n == "Write" then
        $n + " " + (.file_path // "" | split("/") | last)
      elif $n == "Grep" then
        $n + " " + (.pattern // "")[0:20]
      elif $n == "Glob" then
        $n + " " + (.pattern // "")[0:20]
      elif $n == "Bash" then
        $n + " " + (.command // "")[0:20]
      elif $n == "Agent" then
        "Agent[" + (.subagent_type // "?") + "]"
      else
        $n
      end
    )
  ' "$transcript_path" 2>/dev/null | tail -5)

  if [ -n "$labeled_tools" ]; then
    tool_history=$(echo "$labeled_tools" | awk '
      {
        if ($0 == prev) { count++ }
        else {
          if (NR > 1) { printf "%s%s", sep, (count > 1 ? prev " x" count : prev); sep = " › " }
          prev = $0; count = 1
        }
      }
      END { if (NR > 0) printf "%s%s", sep, (count > 1 ? prev " x" count : prev) }
    ')
  fi
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
SEP=" \033[90m|\033[0m "

seg() {
  # seg COLOR TEXT
  printf "%b%s\033[0m" "$1" "$2"
}

# ── Line 1: model | context | branch | git diff ───────────────────────────────
model_label="$model"
[ -n "$model_ctx_label" ] && model_label="$model ($model_ctx_label)"
seg "\033[33m" "$model_label"

[ -n "$ctx_str" ] && printf "%b" "$SEP" && seg "\033[0m" "$ctx_str"

if [ -n "$git_branch" ]; then
  printf "%b" "$SEP"
  seg "\033[32m" "⌥ $git_branch"
fi

[ -n "$session_name" ] && printf "%b" "$SEP" && seg "\033[36m" "$session_name"

if [ -n "$git_diff" ]; then
  printf "%b" "$SEP"
  seg "\033[33m" "$git_diff"
fi

printf "\n"

# ── Line 2: dir | duration | cost | rate limits ───────────────────────────────
username=$(whoami)
dir_label="${username}/$(basename "$cwd")"
seg "\033[34m" "$dir_label"

[ -n "$duration_str" ] && printf "%b" "$SEP" && seg "\033[0m" "$duration_str"

[ -n "$cost_str" ]     && printf "%b" "$SEP" && seg "\033[32m" "$cost_str"

[ -n "$rate_5h" ] && printf "%b" "$SEP" && seg "\033[35m" "$rate_5h"
[ -n "$rate_7d" ] && printf "%b" "$SEP" && seg "\033[35m" "$rate_7d"

printf "\n"

# ── Line 3: agents | mcp | tool history ──────────────────────────────────────
line3=""

if [ "$agent_total" -gt 0 ] 2>/dev/null; then
  seg "\033[35m" "Agents ${agent_active}/${agent_total}"
  line3="y"
fi

if [ "$mcp_count" -gt 0 ] 2>/dev/null; then
  [ -n "$line3" ] && printf "%b" "$SEP"
  seg "\033[35m" "MCP ${mcp_count}"
  line3="y"
fi

if [ -n "$tool_history" ]; then
  [ -n "$line3" ] && printf "%b" "$SEP"
  seg "\033[90m" "$tool_history"
  line3="y"
fi

[ -n "$line3" ] && printf "\n"

exit 0
