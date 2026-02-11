# Codex Configuration (Chezmoi)

This folder mirrors Codex configuration into your home directory.

## What gets installed
- `dot_codex/AGENTS.md` -> `~/.codex/AGENTS.md` (global Codex instructions).
- `dot_codex/config.toml` -> `~/.codex/config.toml` (model settings and instruction fallbacks).
- `dot_codex/rules/default.rules` -> `~/.codex/rules/default.rules` (command approval rules).
- `dot_codex/prompts/*` -> `~/.codex/prompts/*` (Claude-style command prompts for Codex slash commands).
- `dot_agents/skills/*` -> `~/.agents/skills/*` (legacy Codex skills converted from Claude commands).

## Skills
Codex loads skills from user and repo locations, including `~/.agents/skills`. Skills are directories that contain a `SKILL.md` file with required `name` and `description` fields. You can invoke skills explicitly by running `/skills` or typing `$` to mention a skill in the CLI/IDE, or let Codex choose implicitly based on the skill description. If a skill update does not appear, restart Codex.

## Prompt Commands
Claude command parity prompts now live in `~/.codex/prompts`:
- `/create_plan`
- `/iterate_plan`
- `/research_codebase`
- `/create_handoff`
