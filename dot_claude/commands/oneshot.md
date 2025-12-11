---
name: oneshot
description: Research ticket and launch planning session
tags: []
enabled: true
arguments: []
meta:
  agent: claude-code
  agent_display_name: Claude Code
  command_dir: .claude/commands
  command_format: markdown
  command_file_extension: .md
  source_prompt: oneshot
  source_path: .claude/commands
  version: 0.1.0
  updated_at: '2025-12-11T01:33:10.345695+00:00'
  source_type: github
  source_repo: humanlayer/humanlayer
  source_branch: main
---

1. use SlashCommand() to call /ralph_research with the given ticket number
2. launch a new session with `npx humanlayer launch --model opus --dangerously-skip-permissions --dangerously-skip-permissions-timeout 14m --title "plan ENG-XXXX" "/oneshot_plan ENG-XXXX"`
