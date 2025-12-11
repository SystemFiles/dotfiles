---
name: oneshot_plan
description: Execute ralph plan and implementation for a ticket
tags: []
enabled: true
arguments: []
meta:
  agent: claude-code
  agent_display_name: Claude Code
  command_dir: .claude/commands
  command_format: markdown
  command_file_extension: .md
  source_prompt: oneshot_plan
  source_path: .claude/commands
  version: 0.1.0
  updated_at: '2025-12-11T01:33:10.346092+00:00'
  source_type: github
  source_repo: humanlayer/humanlayer
  source_branch: main
---

1. use SlashCommand() to call /ralph_plan with the given ticket number
2. use SlashCommand() to call /ralph_impl with the given ticket number
