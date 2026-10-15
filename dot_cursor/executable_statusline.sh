#!/bin/bash
# Cursor CLI status line. Receives session JSON on stdin, prints status rows to
# stdout (rendered above the prompt). Tuned for a jj-first, vim-enabled workflow:
# shows the selected model + params, the working directory, jj change/bookmarks
# (git branch fallback), open PR number, vim mode, a smart-window bar
# (50% of the model's context window, capped at 400k), and account-wide
# billing-cycle spend (macOS keychain token; omitted when unavailable).
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
MODEL="?" PARAMS="" MAXMODE="" CWD="" WT="" VIM="" TOKENS="0" WIN="0" USED_PCT="0"

# Parse all needed fields in one jq pass, joined by the unit-separator (0x1f) so
# empty fields are preserved (a whitespace IFS would collapse adjacent empties).
sep=$'\037'
IFS="$sep" read -r MODEL PARAMS MAXMODE CWD WT VIM TOKENS WIN USED_PCT < <(
  printf '%s' "$payload" | jq -j --arg s "$sep" '
    [ (.model.display_name // "?")
    , (.model.param_summary // "")
    , (if .model.max_mode then "max" else "" end)
    , (.workspace.current_dir // .cwd // "")
    , (.worktree.name // "")
    , (.vim.mode // "")
    , (.context_window.total_input_tokens // 0 | floor | tostring)
    , (.context_window.context_window_size // 0 | floor | tostring)
    , (.context_window.used_percentage // 0 | floor | tostring)
    ] | join($s)' 2>/dev/null
) || true
MODEL=${MODEL:-?}
TOKENS=${TOKENS:-0}
WIN=${WIN:-0}
USED_PCT=${USED_PCT:-0}

# Payload used_percentage is vs the model's full window. Prefer the token
# count; if it's missing, reverse it from used_percentage * window size.
if [ "${TOKENS:-0}" -eq 0 ] 2>/dev/null && [ "${USED_PCT:-0}" -gt 0 ] 2>/dev/null && [ "${WIN:-0}" -gt 0 ] 2>/dev/null; then
  TOKENS=$(( USED_PCT * WIN / 100 ))
fi

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

# --- Smart context window: 50% of the model's window, capped at 400k ---
# Falls back to 120k when the payload omits context_window_size.
SMART_CAP=400000
case "$WIN" in ''|*[!0-9]*) WIN=0 ;; esac
if [ "$WIN" -gt 0 ]; then
  SMART_MAX=$(( WIN / 2 ))
  [ "$SMART_MAX" -gt "$SMART_CAP" ] && SMART_MAX=$SMART_CAP
else
  SMART_MAX=120000
fi
TOKENS=${TOKENS:-0}
case "$TOKENS" in ''|*[!0-9]*) TOKENS=0 ;; esac
PCT=$(( TOKENS * 100 / SMART_MAX ))
[ "$PCT" -gt 100 ] && PCT=100
[ "$PCT" -lt 0 ] && PCT=0

fmt_tok() {
  awk -v t="$1" 'BEGIN {
    if (t >= 1000) {
      k = t / 1000
      if (k == int(k)) printf "%dk", k
      else printf "%.1fk", k
    } else printf "%d", t
  }'
}
TOK_STR=$(fmt_tok "$TOKENS")
MAX_STR=$(fmt_tok "$SMART_MAX")

# --- Line 1: model · directory · vcs · pr · vim ---
line1="${CYAN}${MODEL}${R}"
[ -n "$PARAMS" ] && line1="${line1} ${DIM}${PARAMS}${R}"
[ -n "$MAXMODE" ] && line1="${line1} ${YELLOW}max${R}"
line1="${line1}  ${BLUE}${LOC}${R}"
[ -n "$VCS" ] && line1="${line1}  ${GREEN}${VCS}${R}"
[ -n "$PR" ] && line1="${line1}  ${CYAN}${PR}${R}"
[ -n "$VIM" ] && line1="${line1}  ${MAGENTA}[${VIM}]${R}"

# --- Line 2: smart-window usage bar (green -> yellow -> red by fill) ---
BAR_WIDTH=12
FILLED=$(( PCT * BAR_WIDTH / 100 ))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
[ "$FILLED" -lt 0 ] && FILLED=0

if [ "$PCT" -lt 50 ]; then BARC="$GREEN"
elif [ "$PCT" -lt 80 ]; then BARC="$YELLOW"
else BARC="$RED"; fi

# Filled cells take the color of their position on the smart-window scale so the
# bar itself walks green -> yellow -> red as it fills; empty cells stay dim.
bar=""
_i=0
while [ "$_i" -lt "$BAR_WIDTH" ]; do
  _i=$((_i + 1))
  _cell_pct=$(( _i * 100 / BAR_WIDTH ))
  if [ "$_i" -le "$FILLED" ]; then
    if [ "$_cell_pct" -lt 50 ]; then _c="$GREEN"
    elif [ "$_cell_pct" -lt 80 ]; then _c="$YELLOW"
    else _c="$RED"; fi
    bar="${bar}${_c}█"
  else
    bar="${bar}${DIM}░"
  fi
done
unset _i _cell_pct _c

line2="${DIM}smart${R} ${bar}${R} ${BARC}${TOK_STR}/${MAX_STR}${R} ${BARC}${PCT}%${R}"

# --- Billing-cycle spend (account-wide, NOT this session) ---
# cursor.com/api/usage-summary authenticates with the dashboard cookie
# WorkosCursorSessionToken=<user_id>::<jwt>; the CLI's keychain token works.
# Amounts are cents. Cached 5 min, refreshed in the background like the PR lookup.
_cost_cache="/tmp/cursor-sl-cost-$(id -u)"
_cost_json=""
_cost_stale=1
if [ -f "$_cost_cache" ]; then
  _cost_json=$(cat "$_cost_cache" 2>/dev/null) || true
  _cmt=$(stat -f %m "$_cost_cache" 2>/dev/null || stat -c %Y "$_cost_cache" 2>/dev/null || echo 0)
  [ $((_now - _cmt)) -lt 300 ] && _cost_stale=0
fi
if [ "$_cost_stale" -eq 1 ] && command -v curl >/dev/null 2>&1; then
  (
    _t=$(security find-generic-password -s cursor-access-token -w 2>/dev/null) || _t=""
    if [ -z "$_t" ]; then
      _t=$(sqlite3 "$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb" \
        "select value from ItemTable where key='cursorAuth/accessToken'" 2>/dev/null) || _t=""
    fi
    [ -n "$_t" ] || exit 0
    _sub=$(printf '%s' "$_t" | cut -d. -f2 | tr '_-' '/+' \
      | awk '{l=length($0)%4; if(l) $0=$0 substr("===",1,4-l); print}' \
      | base64 -d 2>/dev/null | jq -r '.sub // empty' 2>/dev/null)
    [ -n "$_sub" ] || exit 0
    _resp=$(curl -s -m 8 -H "Cookie: WorkosCursorSessionToken=${_sub##*|}%3A%3A${_t}" \
      https://cursor.com/api/usage-summary 2>/dev/null) || exit 0
    printf '%s' "$_resp" | jq -e '.billingCycleStart' >/dev/null 2>&1 || exit 0
    printf '%s' "$_resp" > "${_cost_cache}.$$" && mv "${_cost_cache}.$$" "$_cost_cache"
  ) >/dev/null 2>&1 &
fi
COST=""
if [ -n "$_cost_json" ]; then
  COST=$(printf '%s' "$_cost_json" | jq -r '
    def d: (. // 0) / 100 | (. * 100 | round / 100) | tostring
      | if test("\\.") then (if test("\\.[0-9]$") then . + "0" else . end) else . + ".00" end
      | "$" + .;
    def day: sub("\\.[0-9]+Z$"; "Z") | fromdate | strftime("%b %-d");
    (.individualUsage.overall) as $o
    | (.teamUsage.onDemand.used // 0) as $od
    | "\(.billingCycleStart | day)–\(.billingCycleEnd | day) cycle: \($o.used | d)"
      + (if $o.limit then " / \($o.limit | d) (\(($o.used * 100 / $o.limit) | floor)%)" else "" end)
      + (if $od > 0 then " + on-demand \($od | d)" else "" end)
  ' 2>/dev/null) || COST=""
fi
[ -n "$COST" ] && line2="${line2}  ${DIM}│${R} ${YELLOW}${COST}${R}"

printf '%s\n%s' "$line1" "$line2"
