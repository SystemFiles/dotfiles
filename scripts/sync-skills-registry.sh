#!/usr/bin/env bash
# Deterministically reconcile locally-installed AI skills into skills-registry.txt.
#
# The `skills` CLI records provenance for every installed skill in a lockfile
# (~/.agents/.skill-lock.json, schema version 3): source, sourceType, sourceUrl,
# skillPath. This script reads that lockfile, reconstructs the registry line for
# each installed skill, and appends any that the registry does not already
# declare — one entry at a time, in sorted order, so runs are reproducible.
#
# It is idempotent: a skill already covered by the registry (either as an
# explicit `skill=<name>` entry or via a bare all-skills entry for the same
# source) is skipped. Local-path skills are skipped with a warning because they
# have no shareable git source to pin.
#
# Usage:
#   scripts/sync-skills-registry.sh            # write missing entries
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
for arg in "$@"; do
  case "${arg}" in
    --dry-run|-n) DRY_RUN=true ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "sync-skills-registry: unknown argument '${arg}'" >&2; exit 2 ;;
  esac
done

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
# without a skill= token (i.e. "all skills from this source").
declare -A DECLARED_SKILL DECLARED_ALL_SOURCE
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
      skill=*) DECLARED_SKILL["${t#skill=}"]=1; has_skill=true ;;
    esac
  done
  ${has_skill} || DECLARED_ALL_SOURCE["${src}"]=1
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

added=0 skipped=0
mapfile -t names < <(jq -r '.skills | keys[]' "${SKILL_LOCK}" | sort)

for name in "${names[@]}"; do
  [ -z "${name}" ] && continue
  source="$(jq -r --arg n "${name}" '.skills[$n].source // ""' "${SKILL_LOCK}")"
  source_type="$(jq -r --arg n "${name}" '.skills[$n].sourceType // ""' "${SKILL_LOCK}")"
  source_url="$(jq -r --arg n "${name}" '.skills[$n].sourceUrl // ""' "${SKILL_LOCK}")"

  if [ -n "${DECLARED_SKILL[${name}]:-}" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  reg_src="$(registry_source "${source}" "${source_type}" "${source_url}")"
  if [ -z "${reg_src}" ]; then
    echo "sync-skills-registry: skip '${name}' — local/unsourced install (${source_type:-unknown}); no shareable git source to pin."
    skipped=$((skipped + 1))
    continue
  fi

  if [ -n "${DECLARED_ALL_SOURCE[${reg_src}]:-}" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  entry="${reg_src} skill=${name}"
  if ${DRY_RUN}; then
    echo "sync-skills-registry: would add: ${entry}"
  else
    printf '%s\n' "${entry}" >>"${REGISTRY}"
    echo "sync-skills-registry: added:    ${entry}"
  fi
  added=$((added + 1))
done

if ${DRY_RUN}; then
  echo "sync-skills-registry: ${added} entr$([ "${added}" -eq 1 ] && echo y || echo ies) missing, ${skipped} already covered (dry run; registry unchanged)."
else
  echo "sync-skills-registry: ${added} added, ${skipped} already covered."
fi
