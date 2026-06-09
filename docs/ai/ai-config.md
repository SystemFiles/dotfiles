# AI-Tool Configuration

This repo is **AI-native and vendor-neutral**: one canonical persona, consumed by
each tool through thin symlink shims, plus a declarative skills registry installed
by the `skills` CLI. There is no duplicated per-tool rule/agent/command content.

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
  (`~/.agents/.skill-lock.json`) and appends any locally-installed skill the registry
  does not already declare, one entry at a time. Use `task skills:sync:check` for a
  dry run. Local-path installs are skipped (no shareable git source); the pass is
  idempotent, so re-running adds nothing new.

## Ownership Boundary

The `skills` CLI owns `~/.agents/skills/**` and the vendor `*/skills/**` symlinks
(`~/.cursor/skills`, `~/.claude/skills`, `~/.codex/skills`). chezmoi **ignores** those
paths (`.chezmoiignore`) so the two tools never conflict. Because `.chezmoiremove`
cannot delete ignored paths, one-time cleanup of stale `~/.agents/skills/*` is done by
`.chezmoiscripts/run_once_before_01-remove-stale-agent-skills.sh.tmpl`.

## What Is Not Managed

- **IDE settings** (themes, keybindings) live outside the home dotfiles
  (e.g. macOS `~/Library/Application Support/Cursor/User/`) and are configured per machine.
- **Per-tool settings** intentionally removed in this overhaul (Claude `settings.json`,
  Codex `config.toml`/`rules`, statusline scripts) are not restored here; they can be
  re-added later as small per-tool files.
- **Ephemeral/sensitive runtime state** under `~/.cursor`, `~/.claude`, `~/.codex`
  (caches, history, project state) is not in the repo.

## After Apply

Run `chezmoi apply` as usual. Restart the tool if it does not pick up the new persona
or skills until it next reads those directories.
