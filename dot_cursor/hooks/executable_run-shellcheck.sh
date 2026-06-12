#!/usr/bin/env bash
# Cursor afterFileEdit hook — run shellcheck on shell scripts the agent creates
# or modifies.
#
# afterFileEdit is observe-only (it cannot block or feed context back to the
# agent), so findings surface in Cursor's Hooks output channel / Settings ->
# Hooks. If shellcheck is not installed, the hook warns there and exits 0.
#
# `-e` is intentionally omitted: a hook must never abort the edit flow on an
# internal hiccup. Every step is guarded and the script always exits 0.
set -uo pipefail

# Cursor may launch hooks with a minimal PATH; make Homebrew tools discoverable
# (Apple Silicon + Intel). System paths already cover apt-installed tools.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

input="$(cat)"

# Edited file path: prefer jq, fall back to a tolerant sed parse.
if command -v jq >/dev/null 2>&1; then
  file_path="$(printf '%s' "${input}" | jq -r '.file_path // empty' 2>/dev/null || true)"
else
  file_path="$(printf '%s' "${input}" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
fi

[ -n "${file_path}" ] && [ -f "${file_path}" ] || exit 0

# Skip chezmoi/Go templates: not valid shell until rendered.
case "${file_path}" in
  *.tmpl) exit 0 ;;
esac

# Act only on shell scripts: by extension, or by an sh-family shebang.
is_shell=false
case "${file_path}" in
  *.sh | *.bash | *.ksh | *.zsh) is_shell=true ;;
  *)
    first_line="$(head -n1 "${file_path}" 2>/dev/null || true)"
    if grep -Eq '^#!.*(/(ba|da|k|z)?sh|env[[:space:]]+(ba|da|k|z)?sh)([[:space:]]|$)' <<<"${first_line}"; then
      is_shell=true
    fi
    ;;
esac
${is_shell} || exit 0

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck-hook: shellcheck not installed; skipping ${file_path}. Install with 'brew install shellcheck'." >&2
  exit 0
fi

echo "shellcheck-hook: linting ${file_path}" >&2
shellcheck "${file_path}" >&2 || true
exit 0
