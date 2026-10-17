#!/usr/bin/env bash
# Cursor afterFileEdit hook — deterministic Markdown lint/format + spellcheck for
# documentation files the agent creates or modifies (*.md / *.markdown).
#
# Two deterministic tools run, in order:
#   1. markdownlint-cli2 --fix  — lint + auto-fix formatting rules, written in place
#   2. codespell                — report common misspellings (report-only: it does
#                                 NOT auto-rewrite, to avoid wrong "corrections")
#
# afterFileEdit is observe-only (it cannot block the edit or feed context back to
# the agent), so findings surface in Cursor's Hooks output channel / Settings ->
# Hooks. markdownlint's --fix edits land directly on disk.
#
# `-e` is intentionally omitted so one tool failing never skips the other or
# aborts the edit flow; every step is guarded and the script always exits 0.
set -uo pipefail

# Cursor may launch hooks with a minimal PATH; make Homebrew + pipx/user-local
# tools discoverable (Apple Silicon + Intel).
export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:${PATH:-}"

input="$(cat)"

# Edited file path: prefer jq, fall back to a tolerant sed parse.
if command -v jq >/dev/null 2>&1; then
  file_path="$(printf '%s' "${input}" | jq -r '.file_path // empty' 2>/dev/null || true)"
else
  file_path="$(printf '%s' "${input}" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
fi

[ -n "${file_path}" ] && [ -f "${file_path}" ] || exit 0

# Act only on Markdown documentation files.
case "${file_path}" in
  *.md | *.markdown) ;;
  *) exit 0 ;;
esac

echo "markdown-hook: lint/format + spellcheck ${file_path}" >&2

# 1) Lint and deterministically auto-fix formatting rules, in place.
#    cli2 auto-discovers any .markdownlint-cli2.* / .markdownlint.* config up the
#    tree, so per-project rules win; otherwise the built-in defaults apply.
markdownlint-cli2 --fix "${file_path}" >&2 || true

# 2) Deterministic spellcheck (report only). Redirect stdout to the Hooks channel.
codespell "${file_path}" >&2 || true

exit 0
