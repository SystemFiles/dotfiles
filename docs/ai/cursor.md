# Cursor dotfiles (Chezmoi)

This document describes what Cursor-related config is synced via Chezmoi and how it aligns with the rest of your dotfiles.

## What is synced

All of the following live under **~/.cursor/** and are managed by **dot_cursor/** in this repo:

| Source in repo        | Installed path             | Purpose |
|-----------------------|----------------------------|--------|
| dot_cursor/agents/    | ~/.cursor/agents/          | Custom sub-agents (same content as dot_claude/agents/). |
| dot_cursor/commands/  | ~/.cursor/commands/        | Slash commands/prompts (same content as dot_claude/commands/). |
| dot_cursor/rules/     | ~/.cursor/rules/           | Global “always apply” rules (CLAUDE.md-style content in .mdc format). |

- **Agents:** One `.md` file per agent (e.g. senior-engineer, codebase-analyzer, web-search-researcher) with YAML frontmatter (`name`, `description`) and markdown body. Cursor uses these for user-level sub-agents.
- **Commands:** One `.md` file per command (create_plan, iterate_plan, research_codebase, create_handoff) with frontmatter and body. These are your slash-command prompts.
- **Rules:** At least one `.mdc` file (e.g. global.mdc) with `alwaysApply: true` and CLAUDE.md-style content (critical rules, role, development standards, workflow, communication).

Content is aligned with **dot_claude/** (agents, commands, and CLAUDE.md) so Cursor and Claude Code share the same agents, commands, and rule set.

## What is not synced

- **IDE settings** (e.g. theme, keybindings, Cursor-specific UI settings) live outside the home dotfiles (e.g. macOS: `~/Library/Application Support/Cursor/User/`). They are not in this repo. If you rely on specific IDE settings, configure them once per machine or document them here.
- **Ephemeral/sensitive under ~/.cursor/** are not in the repo: e.g. agent-cli-state.json, statsig-cache.json, prompt_history.json, cli-config.json, mcp.json, chats/, ai-tracking/, projects/, and *.bak under commands.

## User-level vs project-level

- **User-level (this repo):** ~/.cursor/agents/, ~/.cursor/commands/, ~/.cursor/rules/ — applied by Chezmoi to your home directory; same on every machine where you run `chezmoi apply`.
- **Project-level:** In a project you can also have `.cursor/agents/`, `.cursor/commands/`, `.cursor/rules/` (and .cursorrules). Those are not managed by this repo; they are per-project and usually in version control for that project.

## Find-skills and other skills

The **find-skills** skill (from https://skills.sh/vercel-labs/skills/find-skills) is installed automatically on every `chezmoi apply` via a run script, for Cursor and Claude Code, with global install and non-interactive flags. Other skills can be added manually or by extending the run script.

## After apply

Run `chezmoi apply` as usual. Your ~/.cursor/agents/, ~/.cursor/commands/, and ~/.cursor/rules/ will be updated from dot_cursor/. Restart Cursor if agents or commands don’t appear until the next time it reads those directories.
