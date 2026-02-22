---
name: init
description: Generate a comprehensive AGENTS.md for the current project using the agentsmd-generator skill
---

# Init — Generate AGENTS.md

When this command is invoked, you MUST immediately execute the agentsmd-generator skill to produce a full `AGENTS.md` document for this project.

## Instructions

1. **Read the skill definition** from `~/.agents/skills/agentsmd-generator/SKILL.md` — this contains the authoritative, detailed process you must follow.
2. **Execute all four phases** described in the skill:
   - **Phase 1** — Understand the repository (survey layout, read docs, build tree, identify automation, catalog tooling, clarify testing)
   - **Phase 2** — Plan the AGENTS.md structure
   - **Phase 3** — Compose the AGENTS.md file using the skill's template and writing guidance
   - **Phase 4** — Validate and wrap up (self-review, formatting, handoff summary)
3. **Write the `AGENTS.md` file** to the project root.
4. **Present a summary** of what was documented and any follow-up suggestions.

## Important

- Do NOT just tell the user to run the skill — YOU must execute it.
- Do NOT skip reading the SKILL.md file; it contains critical details beyond what is summarized here.
- If the skill file is missing, inform the user and suggest running `chezmoi apply` to install it.
- Ask clarifying questions when conventions, ownership, or workflows are ambiguous (as the skill instructs).
