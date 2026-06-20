# AI-Tool Configuration

This repo is **AI-native and vendor-neutral**: one canonical persona, consumed by
each tool through thin symlink shims, a declarative skills registry installed
by the `skills` CLI, and a set of vendored subagents exposed through a symlink
shim. There is no duplicated per-tool rule/agent/command content.

## Architecture

```
                ┌───────────────────────────┐
                │  dot_agents/AGENTS.md      │  (chezmoi source, canonical persona)
                └─────────────┬─────────────┘
                              │ chezmoi apply
                              ▼
                     ~/.agents/AGENTS.md        ◄── single source of truth
                       ▲                ▲
        chezmoi symlink│                │chezmoi symlink
                       │                │
        ~/.claude/CLAUDE.md      ~/.codex/AGENTS.md
        (Claude Code reads)      (Codex reads)

        ~/.cursor : no global rules file → set manually in Settings → User Rules
```

## Canonical Persona

- **Source:** `dot_agents/AGENTS.md` → **target:** `~/.agents/AGENTS.md`.
- Edit the persona **once** here; every tool picks it up on the next `chezmoi apply`.
- Claude Code reads `~/.claude/CLAUDE.md`, a managed symlink created by
  `dot_claude/symlink_CLAUDE.md.tmpl` (body: `{{ .chezmoi.homeDir }}/.agents/AGENTS.md`).
- Codex reads `~/.codex/AGENTS.md`, a managed symlink created by
  `dot_codex/symlink_AGENTS.md.tmpl`.
- Verify with `readlink ~/.claude/CLAUDE.md` and `readlink ~/.codex/AGENTS.md`.

### Cursor caveat

Cursor has **no supported global rules file** and does not read a user-level
`~/.cursor/AGENTS.md`. Set the persona once per machine via
**Cursor → Settings → User Rules** (paste the contents of `~/.agents/AGENTS.md`),
or rely on a per-project `AGENTS.md`. A Cursor persona symlink would be inert, so
none is created.

## Skills

Skills are declared in `skills-registry.txt` (repo root, **not deployed**) and
installed by `.chezmoiscripts/run_install-skills.sh.tmpl` on every `chezmoi apply`.

```
skills-registry.txt   one entry per line: <source> [version=REF] [skill=NAME] [agents=a,b]
   │  {{ include "skills-registry.txt" }} (read at render time)
   ▼
run_install-skills.sh.tmpl   guard: skills_enabled == true AND npx present (else exit 0)
   │  per entry → npx skills add <source[/tree/REF]> [--skill NAME] -g -a <agents> -y
   ▼
   ~/.agents/skills/<skill>            ◄── canonical (skills CLI owns this)
        ▲                 ▲
   ~/.cursor/skills/<s>   ~/.claude/skills/<s>   (symlinks into the canonical copy)
```

- **Registry grammar:** one entry per line; `#` and blank lines ignored; first token
  is the source; optional `key=value` tokens `version=`, `skill=`, `agents=`.
- **Defaults:** `agents=cursor,claude-code`; `skill=*` (all skills) when omitted;
  latest default-branch ref when `version=` omitted; symlink install (never `--copy`).
- **Version pinning:** the `skills` CLI has no `--version` flag; a non-empty
  `version=` is resolved to a `https://github.com/<owner>/<repo>/tree/<ref>` source URL.
- **Toggle:** the `skills_enabled` chezmoi data value (default `true`) gates the
  installer. With `skills_enabled = false` or no `npx` on `PATH`, the script prints a
  skip message and exits 0 (resilient apply).
- **Add a skill:** append one line to `skills-registry.txt`, then `chezmoi apply`.
- **Reconcile installed skills:** `task skills:sync` reads the `skills` CLI lockfile
  (`~/.agents/.skill-lock.json`) and, for each locally-installed skill the registry
  does not already declare, prompts to confirm before appending it
  (`[y]`es / `[n]`o / `[a]`ll / `[q]`uit; Enter = no). Pass `-- --yes` to add every
  missing entry without prompting, or use `task skills:sync:check` for a dry run.
  Local-path installs are skipped (no shareable git source); the pass is idempotent,
  so re-running adds nothing new.

## Subagents

Six vendored [humanlayer](https://github.com/humanlayer/humanlayer/tree/main/.claude/agents)
subagents live canonically under `dot_agents/agents/` and are exposed to the tools
through a single chezmoi symlink, mirroring the persona shim pattern.

```
dot_agents/agents/*.md
   │  chezmoi apply
   ▼
~/.agents/agents/*.md            ◄── canonical, vendor-neutral (chezmoi-managed)
   ▲
   │ chezmoi symlink (dot_claude/symlink_agents.tmpl)
   │
~/.claude/agents  ──▶ Claude Code reads it natively; Cursor reads it via its
                      documented user-level `.claude/agents` compatibility.
```

- **Agents:** `codebase-analyzer`, `codebase-locator`, `codebase-pattern-finder`,
  `thoughts-analyzer`, `thoughts-locator`, `web-search-researcher` — each a markdown
  file with YAML frontmatter (`name`, `description`, `tools`, `model`, optional `color`).
- **One mount, two tools:** Claude Code only reads `~/.claude/agents/`; Cursor reads
  both `~/.cursor/agents/` and `~/.claude/agents/`. A single `~/.claude/agents`
  symlink therefore serves both with no duplicate scanning, so no `~/.cursor/agents`
  shim is created. Cursor does **not** read `~/.agents/` directly — the symlink is
  what makes the canonical files visible.
- **Frontmatter normalization:** upstream ships `model: sonnet`; the vendored copies
  use `model: inherit` so the field is valid in Cursor (which expects `inherit` or a
  Cursor model ID) and behaves equivalently in Claude Code. Everything else is verbatim.
- **Codex excluded:** Codex subagents are TOML (`~/.codex/agents/*.toml`), a different
  format with current loading regressions, so this markdown set is not shared with it.
- **Ownership:** unlike `~/.agents/skills/**` (owned by the `skills` CLI), the canonical
  subagent files are chezmoi-managed, and `~/.claude/agents` is a managed symlink — so
  it is excluded from `.chezmoiremove`'s stale-artifact cleanup list.
- **Add a subagent:** drop a `*.md` file in `dot_agents/agents/`, then `chezmoi apply`.
- **Verify:** `readlink ~/.claude/agents` → `~/.agents/agents`; the six files appear
  under `~/.agents/agents/`.

## Cursor CLI Configuration

The Cursor CLI keeps **both** portable preferences and account/runtime state in a
single file, `~/.cursor/cli-config.json`. chezmoi therefore manages it through a
`modify_` script (not as a whole file), so secrets never enter the repo and auth
is never wiped on apply.

```
dot_cursor/executable_statusline.sh ──► ~/.cursor/statusline.sh        (full file)

dot_cursor/modify_cli-config.json
   │  stdin: live ~/.cursor/cli-config.json
   ▼
   jq '. * $desired'                 $desired = portable prefs only
   │   enforced  → statusLine, editor.vimMode, display, model selection,
   │               permissions, notifications/hints/rewind, approvalMode, sandbox
   │   preserved → authInfo, serverConfigCache, privacyCache,
   │               runEverythingSettingsPromptStreak  ◄── account/secret/ephemeral
   ▼
   ~/.cursor/cli-config.json         (merged; auth + caches untouched)
```

- **Why `modify_`:** Cursor co-writes `authInfo` (email/userId/teamId), server +
  privacy caches, and counters into the same file. A plain managed file would
  commit that identity to the repo **and** reset auth on every `chezmoi apply`.
  The script merges in only the keys in its `$desired` block; all other (live)
  keys pass through verbatim.
- **Status line:** `~/.cursor/statusline.sh` shows model + params, cwd, jj
  change/bookmarks (git-branch fallback), vim mode, and a context-usage bar. It
  hardens `PATH` for the CLI's minimal env and no-ops when `jq` is missing.
- **jq dependency:** both pieces need `jq` (declared in `dot_Brewfile.tmpl`).
  Before `brew bundle` installs it, the `modify_` script passes the live file
  through unchanged — re-apply once `jq` is present.
- **Model-pin caveat:** `$desired` pins the default model + params, so an apply
  reverts an interactive model switch. Drop the `model` / `modelParameters` /
  `selectedModel` keys from the script to make the model machine-local.
- **Verify:** `chezmoi diff ~/.cursor/cli-config.json` is empty once applied;
  the status line previews via `echo '<sample-json>' | ~/.cursor/statusline.sh`.

## Ownership Boundary

The `skills` CLI owns `~/.agents/skills/**` and the vendor `*/skills/**` symlinks
(`~/.cursor/skills`, `~/.claude/skills`, `~/.codex/skills`). chezmoi **ignores** those
paths (`.chezmoiignore`) so the two tools never conflict. Because `.chezmoiremove`
cannot delete ignored paths, one-time cleanup of stale `~/.agents/skills/*` is done by
`.chezmoiscripts/run_once_before_01-remove-stale-agent-skills.sh.tmpl`.

## What Is Not Managed

- **IDE settings** (themes, keybindings) live outside the home dotfiles
  (e.g. macOS `~/Library/Application Support/Cursor/User/`) and are configured per machine.
- **Per-tool settings** removed in the AI-native overhaul (Claude `settings.json`,
  Codex `config.toml`/`rules`) are not restored here. The **Cursor CLI** status line
  and portable prefs *are* now managed — see [Cursor CLI Configuration](#cursor-cli-configuration).
- **Ephemeral/sensitive runtime state** under `~/.cursor`, `~/.claude`, `~/.codex`
  (auth, caches, history, project state) is not in the repo — the Cursor
  `modify_` script preserves it on the machine but never commits it.

## After Apply

Run `chezmoi apply` as usual. Restart the tool if it does not pick up the new persona
or skills until it next reads those directories.
