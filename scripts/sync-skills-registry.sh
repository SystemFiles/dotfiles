#!/usr/bin/env bash
# Interactively reconcile locally-installed AI skills into skills-registry.txt.
#
# The `skills` CLI records provenance for every installed skill in a lockfile
# (~/.agents/.skill-lock.json, schema version 3): source, sourceType, sourceUrl,
# skillPath. This script reads that lockfile, reconstructs the registry line for
# each installed skill, and — for any the registry does not already declare —
# prompts you to confirm before appending it. Candidates are processed one at a
# time, in sorted order, so runs are reproducible.
#
# It is idempotent: a skill already covered by the registry (either as an
# explicit `skill=<name>` entry or via a bare all-skills entry for the same
# source) is skipped without a prompt. Local-path skills are skipped with a
# warning because they have no shareable git source to pin.
#
# At each prompt: [y]es add it, [n]o skip it, [a]ll add it plus every remaining
# candidate without further prompts, [q]uit stop now. Enter alone means no.
#
# Usage:
#   scripts/sync-skills-registry.sh            # confirm each missing entry
#   scripts/sync-skills-registry.sh --yes      # add all missing entries, no prompts
#   scripts/sync-skills-registry.sh --dry-run  # report only, write nothing
#
# Env overrides (mainly for testing):
#   SKILL_LOCK   path to the skills CLI lockfile (default ~/.agents/.skill-lock.json)
#   REGISTRY     path to the registry file       (default <repo>/skills-registry.txt)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REGISTRY="${REGISTRY:-${REPO_ROOT}/skills-registry.txt}"
SKILL_LOCK="${SKILL_LOCK:-${HOME}/.agents/.skill-lock.json}"

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
  case "${arg}" in
    --dry-run|-n) DRY_RUN=true ;;
    --yes|-y) ASSUME_YES=true ;;
    -h|--help)
      sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "sync-skills-registry: unknown argument '${arg}'" >&2; exit 2 ;;
  esac
done

if ${DRY_RUN} && ${ASSUME_YES}; then
  echo "sync-skills-registry: --dry-run and --yes are mutually exclusive." >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "sync-skills-registry: jq is required but not on PATH." >&2; exit 1; }

if [ ! -f "${SKILL_LOCK}" ]; then
  echo "sync-skills-registry: no lockfile at ${SKILL_LOCK}; nothing installed to sync."
  exit 0
fi
if [ ! -f "${REGISTRY}" ]; then
  echo "sync-skills-registry: registry not found at ${REGISTRY}." >&2
  exit 1
fi

# Existing registry state: skill names already declared, and sources declared
# without a skill= token (i.e. "all skills from this source"). macOS ships bash
# 3.2 (no associative arrays), so these sets are newline-delimited strings
# queried with set_contains via a here-string (no pipe → no pipefail/SIGPIPE).
set_contains() { # set_contains <newline-delimited-set> <value>
  grep -Fxq -- "$2" <<<"$1"
}

DECLARED_SKILLS=""
DECLARED_ALL_SOURCES=""
while IFS= read -r raw; do
  line="${raw#"${raw%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [ -z "${line}" ] && continue
  [[ "${line}" == \#* ]] && continue
  read -ra toks <<<"${line}"
  src="${toks[0]}"
  has_skill=false
  for t in "${toks[@]:1}"; do
    case "${t}" in
      skill=*) DECLARED_SKILLS="${DECLARED_SKILLS}${t#skill=}"$'\n'; has_skill=true ;;
    esac
  done
  ${has_skill} || DECLARED_ALL_SOURCES="${DECLARED_ALL_SOURCES}${src}"$'\n'
done <"${REGISTRY}"

# Map the lockfile's source into a registry source token. Prefer the GitHub
# `owner/repo` shorthand the registry already uses; otherwise normalize the
# clone URL. Returns empty for sources with no shareable git origin.
registry_source() {
  local source="$1" source_type="$2" source_url="$3"
  if [[ "${source}" == */* && "${source}" != /* && "${source}" != .* && "${source}" != *://* ]]; then
    printf '%s' "${source}"
    return 0
  fi
  case "${source_type}" in
    local|path|file) printf '' ;;
    *)
      local u="${source_url:-${source}}"
      u="${u%.git}"
      printf '%s' "${u}"
      ;;
  esac
}

# Ask whether to append one entry. The main loop reads the lockfile stream on
# fd 0 (process substitution), so prompts must talk to the controlling terminal
# directly via /dev/tty. Sets PROMPT_REPLY to one of: y n a q. Enter means no;
# EOF (e.g. ^D) is treated as quit.
PROMPT_REPLY=""
prompt_confirm() { # prompt_confirm <entry>
  local entry="$1" ans
  while :; do
    printf 'Add "%s"? [y]es/[n]o/[a]ll/[q]uit (default no): ' "${entry}" >/dev/tty
    if ! IFS= read -r ans </dev/tty; then
      printf '\n' >/dev/tty
      PROMPT_REPLY=q
      return 0
    fi
    case "${ans}" in
      y|Y|yes|YES)   PROMPT_REPLY=y; return 0 ;;
      ''|n|N|no|NO)  PROMPT_REPLY=n; return 0 ;;
      a|A|all|ALL)   PROMPT_REPLY=a; return 0 ;;
      q|Q|quit|QUIT) PROMPT_REPLY=q; return 0 ;;
      *) printf 'Please answer y, n, a, or q.\n' >/dev/tty ;;
    esac
  done
}

# Interactive confirmation (the default) needs a usable controlling terminal.
# --yes and --dry-run never prompt, so they don't require one.
INTERACTIVE=false
if [ -r /dev/tty ] && [ -w /dev/tty ]; then INTERACTIVE=true; fi

added=0 skipped=0 declined=0
QUIT=false

# bash 3.2 has no mapfile; stream the sorted skill names through process
# substitution so the loop body runs in the current shell and the counters
# persist after the loop.
while IFS= read -r name; do
  [ -z "${name}" ] && continue
  source="$(jq -r --arg n "${name}" '.skills[$n].source // ""' "${SKILL_LOCK}")"
  source_type="$(jq -r --arg n "${name}" '.skills[$n].sourceType // ""' "${SKILL_LOCK}")"
  source_url="$(jq -r --arg n "${name}" '.skills[$n].sourceUrl // ""' "${SKILL_LOCK}")"

  if set_contains "${DECLARED_SKILLS}" "${name}"; then
    skipped=$((skipped + 1))
    continue
  fi

  reg_src="$(registry_source "${source}" "${source_type}" "${source_url}")"
  if [ -z "${reg_src}" ]; then
    echo "sync-skills-registry: skip '${name}' — local/unsourced install (${source_type:-unknown}); no shareable git source to pin."
    skipped=$((skipped + 1))
    continue
  fi

  if set_contains "${DECLARED_ALL_SOURCES}" "${reg_src}"; then
    skipped=$((skipped + 1))
    continue
  fi

  entry="${reg_src} skill=${name}"

  if ${DRY_RUN}; then
    echo "sync-skills-registry: would add: ${entry}"
    added=$((added + 1))
    continue
  fi

  if ! ${ASSUME_YES}; then
    if ! ${INTERACTIVE}; then
      echo "sync-skills-registry: no terminal for interactive confirmation; pass --yes to add all or --dry-run to preview." >&2
      exit 1
    fi
    prompt_confirm "${entry}"
    case "${PROMPT_REPLY}" in
      n) echo "sync-skills-registry: declined: ${entry}"; declined=$((declined + 1)); continue ;;
      q) echo "sync-skills-registry: quit — skipping remaining candidates."; QUIT=true; break ;;
      a) ASSUME_YES=true ;;
    esac
  fi

  printf '%s\n' "${entry}" >>"${REGISTRY}"
  echo "sync-skills-registry: added:    ${entry}"
  added=$((added + 1))
done < <(jq -r '.skills | keys[]' "${SKILL_LOCK}" | sort)

if ${DRY_RUN}; then
  echo "sync-skills-registry: ${added} entr$([ "${added}" -eq 1 ] && echo y || echo ies) missing, ${skipped} already covered (dry run; registry unchanged)."
else
  summary="sync-skills-registry: ${added} added, ${skipped} already covered"
  [ "${declined}" -gt 0 ] && summary="${summary}, ${declined} declined"
  ${QUIT} && summary="${summary} (quit early)"
  echo "${summary}."
fi
