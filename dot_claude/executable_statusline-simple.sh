#!/usr/bin/env bash
# Simple Claude Code statusline inspired by PowerLevel10k
# Displays: os_icon | directory | git_branch [context_used%] vim_mode

# Read JSON input from Claude Code
input=$(cat)

# Colors (using 256-color palette like p10k)
COLOR_OS='\033[38;5;255m'      # White (os_icon)
COLOR_DIR='\033[38;5;178m'     # Orange (dir anchor)
COLOR_DIR_DIM='\033[38;5;246m' # Gray (dir shortened)
COLOR_GIT='\033[38;5;178m'     # Orange (git branch)
COLOR_GIT_ICON='\033[38;5;246m' # Gray (git icon)
COLOR_CONTEXT='\033[38;5;136m' # Brown/Orange (context usage)
COLOR_VIM='\033[38;5;178m'     # Orange (vim mode)
COLOR_RESET='\033[0m'
COLOR_DIM='\033[2m'            # Dimmed text

# Extract data from JSON
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# OS icon (macOS = )
os_icon=""

# Format directory - show last 2 segments with abbreviated parent
dir_name=$(basename "$current_dir")
parent_dir=$(dirname "$current_dir")
parent_name=$(basename "$parent_dir")

# Truncate parent if too long
if [[ ${#parent_name} -gt 20 ]]; then
    parent_name="${parent_name:0:17}…"
fi

dir_display="${COLOR_DIR_DIM}${parent_name}/${COLOR_DIR}${dir_name}${COLOR_RESET}"

# Git info (if in a git repo)
git_info=""
jira_issue=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

    # Extract Jira issue from branch name (e.g., feat/SIGPLA-99 -> SIGPLA-99)
    if [[ "$branch" =~ ([A-Z]+-[0-9]+) ]]; then
        jira_issue="${BASH_REMATCH[1]}"
    fi

    # Count git status indicators (like p10k)
    git_status=$(git status --porcelain 2>/dev/null)
    staged=$(echo "$git_status" | grep -c '^[MADRC]' || true)
    unstaged=$(echo "$git_status" | grep -c '^.[MD]' || true)
    untracked=$(echo "$git_status" | grep -c '^??' || true)

    status_text=""
    [[ $staged -gt 0 ]] && status_text="${status_text}+${staged}"
    [[ $unstaged -gt 0 ]] && status_text="${status_text}!${unstaged}"
    [[ $untracked -gt 0 ]] && status_text="${status_text}?${untracked}"

    # Git icon with branch
    git_info=" ${COLOR_GIT_ICON}${COLOR_DIM}${COLOR_RESET}${COLOR_GIT}${branch}${COLOR_RESET}"
    [[ -n "$status_text" ]] && git_info="${git_info} ${COLOR_DIR_DIM}${status_text}${COLOR_RESET}"
fi

# Context usage
context_info=""
if [[ -n "$context_remaining" ]]; then
    # Show as percentage used (more intuitive)
    context_used=$(awk "BEGIN {printf \"%.0f\", 100 - $context_remaining}")
    context_info=" ${COLOR_DIM}[${COLOR_CONTEXT}${context_used}%${COLOR_DIM}]${COLOR_RESET}"
fi

# Jira info
jira_info=""
if [[ -n "$jira_issue" ]]; then
    jira_info=" ${COLOR_DIM}[${COLOR_RESET}${COLOR_DIR}${jira_issue}${COLOR_DIM}]${COLOR_RESET}"
fi

# Cost info (format to 2 decimal places)
cost_info=""
if [[ -n "$session_cost" && "$session_cost" != "null" ]]; then
    formatted_cost=$(printf "%.2f" "$session_cost")
    cost_info=" ${COLOR_DIM}\$${formatted_cost}${COLOR_RESET}"
fi

# Vim mode indicator (only show in NORMAL mode)
vim_info=""
if [[ "$vim_mode" == "NORMAL" ]]; then
    vim_info=" ${COLOR_VIM}NORMAL${COLOR_RESET}"
fi

# Build statusline
echo -e "${COLOR_OS}${os_icon}${COLOR_RESET} ${dir_display}${git_info}${jira_info}${context_info}${cost_info}${vim_info}"
