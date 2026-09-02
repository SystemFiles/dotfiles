#!/bin/bash
# Cursor CLI status line. Receives session JSON on stdin, prints status rows to
# stdout (rendered above the prompt). Tuned for a jj-first, vim-enabled workflow:
# shows the selected model + params, the working directory, jj change/bookmarks
# (git branch fallback), open PR number, vim mode, and a context-window usage bar.
#
# Cursor CLI statusline JSON contract: stdin session JSON, stdout status rows.
#
# `-e` is intentionally omitted so a hiccup never blanks the status line; the CLI
# keeps the previous text when the script exits non-zero with empty stdout.
#
# Shebang is /bin/bash (not `env bash`): the CLI spawns this with no shell and an
# often-minimal PATH, so `/usr/bin/env bash` cannot find bash.
set -uo pipefail

# The CLI may spawn this with a minimal PATH; make jq/jj discoverable on macOS
# (Homebrew, Apple Silicon + Intel) and Linux (Homebrew/linuxbrew + system).
export PATH="/opt/homebrew/bin:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/bin:/bin:${PATH:-}"

payload=$(cat)

# jq is required to parse the payload. Without it, emit nothing and exit 0 so the
# CLI retains the prior status line rather than showing a broken row.
command -v jq >/dev/null 2>&1 || exit 0

# Defaults so `set -u` never blanks a first paint when jq/read fail (empty or
# non-JSON stdin).
MODEL="?" PARAMS="" MAXMODE="" CWD="" WT="" VIM="" PCT="0" TOKENS="0"

# Parse all needed fields in one jq pass, joined by the unit-separator (0x1f) so
# empty fields are preserved (a whitespace IFS would collapse adjacent empties).
sep=$'\037'
IFS="$sep" read -r MODEL PARAMS MAXMODE CWD WT VIM PCT TOKENS < <(
  printf '%s' "$payload" | jq -j --arg s "$sep" '
    [ (.model.display_name // "?")
    , (.model.param_summary // "")
    , (if .model.max_mode then "max" else "" end)
    , (.workspace.current_dir // .cwd // "")
    , (.worktree.name // "")
    , (.vim.mode // "")
    , (.context_window.used_percentage // 0 | floor | tostring)
    , (.context_window.total_input_tokens // 0 | floor | tostring)
    ] | join($s)' 2>/dev/null
) || true
MODEL=${MODEL:-?}
PCT=${PCT:-0}
TOKENS=${TOKENS:-0}

# display_name already includes param_summary on current CLI models
# ("Cursor Grok 4.6 High Fast" + "High Fast" → duplicated suffix). Drop it.
if [ -n "${PARAMS:-}" ]; then
  _bare=$PARAMS
  _bare=${_bare#(}
  _bare=${_bare%)}
  case "$MODEL" in
    *"$_bare") PARAMS="" ;;
  esac
  unset _bare
fi

# Colors
R=$'\033[0m'; DIM=$'\033[90m'
CYAN=$'\033[36m'; BLUE=$'\033[34m'; GREEN=$'\033[32m'
MAGENTA=$'\033[35m'; YELLOW=$'\033[33m'; RED=$'\033[31m'

# --- VCS: jj change + bookmarks, fall back to git branch ---
# --ignore-working-copy so the status line never triggers a working-copy snapshot.
VCS=""
pr_heads=""
add_pr_head() {
  _h=${1%\*}
  [ -n "$_h" ] || return 0
  case "$_h" in master|main|trunk) return 0 ;; esac
  case ",$pr_heads," in *",$_h,"*) return 0 ;; esac
  pr_heads="${pr_heads:+$pr_heads,}$_h"
}

if [ -n "$CWD" ]; then
  # Newline-separated: change id, display bookmarks (may have trailing *),
  # raw bookmark names for gh --head. jj "\037" is NUL+'37', not unit-sep.
  jj_raw=$(cd "$CWD" 2>/dev/null && command -v jj >/dev/null 2>&1 && jj log -r @ \
    --no-graph --ignore-working-copy \
    -T 'change_id.shortest(6) ++ "\n" ++ bookmarks.join(",") ++ "\n" ++ bookmarks.map(|b| b.name()).join(",")' \
    2>/dev/null) || true
  if [ -n "$jj_raw" ]; then
    jj_id=""; jj_bms_disp=""; jj_bms=""
    {
      IFS= read -r jj_id
      IFS= read -r jj_bms_disp
      IFS= read -r jj_bms
    } <<EOF
$jj_raw
EOF
    VCS=${jj_id:-}
    [ -n "${jj_bms_disp:-}" ] && VCS="${VCS} ${jj_bms_disp}"
    _rest=${jj_bms:-}
    while [ -n "${_rest:-}" ]; do
      _h=${_rest%%,*}
      if [ "$_rest" = "$_h" ]; then _rest=""; else _rest=${_rest#*,}; fi
      add_pr_head "$_h"
    done
  fi
  if [ -z "$VCS" ]; then
    branch=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && VCS="git:$branch"
  fi
  add_pr_head "$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null)"
  # @ itself is often an empty jj new after the PR bookmark. Native
  # `gh --head $git_branch` also misses this: HEAD stays on trunk.
  _stack=$(cd "$CWD" 2>/dev/null && command -v jj >/dev/null 2>&1 && jj log \
    -r 'ancestors(@) ~ ancestors(trunk())' \
    --no-graph --ignore-working-copy \
    -T 'bookmarks.map(|b| b.name()) ++ "\n"' 2>/dev/null) || true
  while IFS= read -r _h; do
    add_pr_head "$_h"
  done <<EOF
${_stack:-}
EOF
fi
add_pr_head "${WT:-}"

# Custom statusLine replaces the native footer, including its PR badge.
# Native looks up `gh pr list --head $git_branch`; that misses jj-first
# checkouts where HEAD stays on master and the PR head is a bookmark.
# Cache so a slow gh never blanks this tick; a background refresh fills
# the next one (CLI updateIntervalMs is >= 300ms).
PR=""
_pr_cache="/tmp/cursor-sl-pr-$(id -u)"
_pr_key="${CWD}|${pr_heads}"
_now=$(date +%s)
_pr_stale=1
if [ -f "$_pr_cache" ]; then
  IFS=$'\t' read -r _cts _ckey _cpr < "$_pr_cache" || true
  if [ "${_ckey:-}" = "$_pr_key" ]; then
    PR=${_cpr:-}
    if [ -n "${_cts:-}" ] && [ $((_now - _cts)) -lt 60 ]; then
      _pr_stale=0
    fi
  fi
fi
if [ "$_pr_stale" -eq 1 ] && [ -n "$pr_heads" ] && command -v gh >/dev/null 2>&1; then
  (
    _found=""
    _rest=$pr_heads
    while [ -n "${_rest:-}" ]; do
      _h=${_rest%%,*}
      if [ "$_rest" = "$_h" ]; then _rest=""; else _rest=${_rest#*,}; fi
      _num=$(cd "$CWD" && gh pr list --head "$_h" --state open --json number --jq '.[0].number // empty' 2>/dev/null) || true
      if [ -n "${_num:-}" ]; then _found="#${_num}"; break; fi
    done
    printf '%s\t%s\t%s\n' "$(date +%s)" "$_pr_key" "$_found" > "${_pr_cache}.$$"
    mv "${_pr_cache}.$$" "$_pr_cache"
  ) >/dev/null 2>&1 &
fi

# --- Directory: cwd basename ---
LOC="${CWD##*/}"
[ -z "$LOC" ] && LOC="~"

# --- Tokens, formatted as k ---
TOK_STR=""
if [ "${TOKENS:-0}" -ge 1000 ] 2>/dev/null; then
  TOK_STR=$(awk -v t="$TOKENS" 'BEGIN{printf "%.1fk", t/1000}')
elif [ "${TOKENS:-0}" -gt 0 ] 2>/dev/null; then
  TOK_STR="$TOKENS"
fi

# --- Line 1: model · directory · vcs · pr · vim ---
line1="${CYAN}${MODEL}${R}"
[ -n "$PARAMS" ] && line1="${line1} ${DIM}${PARAMS}${R}"
[ -n "$MAXMODE" ] && line1="${line1} ${YELLOW}max${R}"
line1="${line1}  ${BLUE}${LOC}${R}"
[ -n "$VCS" ] && line1="${line1}  ${GREEN}${VCS}${R}"
[ -n "$PR" ] && line1="${line1}  ${CYAN}${PR}${R}"
[ -n "$VIM" ] && line1="${line1}  ${MAGENTA}[${VIM}]${R}"

# --- Line 2: context usage bar ---
PCT=${PCT:-0}
BAR_WIDTH=12
FILLED=$(( PCT * BAR_WIDTH / 100 ))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
[ "$FILLED" -lt 0 ] && FILLED=0
EMPTY=$(( BAR_WIDTH - FILLED ))

if [ "$PCT" -lt 50 ]; then BARC="$GREEN"
elif [ "$PCT" -lt 80 ]; then BARC="$YELLOW"
else BARC="$RED"; fi

bar=""
[ "$FILLED" -gt 0 ] && { printf -v f "%${FILLED}s" ""; bar="${f// /█}"; }
[ "$EMPTY" -gt 0 ] && { printf -v e "%${EMPTY}s" ""; bar="${bar}${e// /░}"; }

line2="${DIM}ctx${R} ${BARC}${bar}${R} ${DIM}${PCT}%${R}"
[ -n "$TOK_STR" ] && line2="${line2} ${DIM}· ${TOK_STR} tok${R}"

printf '%s\n%s' "$line1" "$line2"
