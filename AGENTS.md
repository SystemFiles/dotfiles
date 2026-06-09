# Dotfiles Agent Guide

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/): shell, editor,
AI-tool persona, Git/jj config, and supporting tooling for macOS and Linux.

## Quick Facts

- **Languages:** Shell (bash/zsh), Go text/template (chezmoi templating)
- **Manager:** chezmoi (v2.62.1+); **packages:** Homebrew (`dot_Brewfile.tmpl`)
- **VCS:** jj-first (Jujutsu), colocated with git; **trunk:** `master`
- **No CI, linters, or test framework** — quality is verified via `chezmoi diff`/`verify`

## Quick Commands

```bash
chezmoi diff            # preview pending changes (always before apply)
chezmoi apply           # deploy source state to ~/
chezmoi execute-template < file.tmpl   # test .tmpl rendering
brew bundle --global    # install packages after apply
```

## Architecture at a Glance

- AI persona is canonical at `~/.agents/AGENTS.md` (source: `dot_agents/AGENTS.md`);
  `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` are symlink shims to it. No
  duplicated per-tool rule/agent/command content. Skills are declared in
  `skills-registry.txt` and installed by a `run_` script via the `skills` CLI.
- Source naming uses chezmoi prefixes (`dot_`, `private_`, `symlink_`, `run_`),
  with `.chezmoiignore` (not deployed) and `.chezmoiremove` (deleted from `~/`).

## Sensitive Files

Never commit secrets. `private_dot_ssh/` and `private_dot_gnupg/` hold config
templates only; machine-specific values are prompted at init time.

## Detailed Instructions

- [chezmoi Conventions & Common Tasks](docs/ai/chezmoi-conventions.md) — naming, commands, adding dotfiles, setup
- [AI-Tool Configuration](docs/ai/ai-config.md) — canonical persona, symlink shims, skills registry, ownership boundary
- [Workflow](docs/ai/workflow.md) — jj-first VCS, branching, Conventional Commits, sensitive files
- [Testing & Quality Gates](docs/ai/testing.md) — chezmoi diff/verify/execute-template
