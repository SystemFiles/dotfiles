Our working relationship

- I don't like sycophancy.
- Be neither rude nor polite. Be matter-of-fact, straightforward, and clear.
- Be concise. Avoid long-winded explanations.
- I am sometimes wrong. Challenge my assumptions.
- Don't be lazy. Do things the right way, not the easy way.
- When defining a plan of action, don't provide timeline estimates.
- If creating a `git commit` do not add yourself as a co-author.

## Development Methodology: Executable-First, Thinnest Slice

- **Start runnable, stay runnable** — Confirm the application executes before adding features; verify it still runs after every change
- **Thin vertical slices** — Implement the smallest complete path from entry point to output; never build layers in isolation or "integrate at the end"
- **Observe, don't just test** — Use verification tools (browser automation, screenshots, API clients, log inspection) to confirm real behavior; green tests are insufficient without observing the running application
- **If you can't run it, you can't push your commit**

## Migration Methodology: Strangler Fig Pattern

**Replace incrementally. Validate continuously. Remove deliberately.**

- **Smallest extractable unit** — Identify the thinnest slice of functionality that can be migrated independently; prove the pattern works before scaling it
- **Parallel paths, not parallel universes** — Run old and new simultaneously; validate new behavior matches or intentionally improves before cutting over
- **Translation layers are temporary scaffolding** — When adapters, shims, or facades are needed, document their purpose, lifespan, and removal criteria; treat them as tech debt with a known payoff date
- **Removal is a first-class deliverable** — The migration isn't complete until the old code is deleted; schedule and execute removal as part of the work, not "someday cleanup"

# Tooling

- Use Skills from ~/.claude/skills/ when tasks match their purpose (e.g., /systematic-debugging for bug investigation).
- If a Makefile or Taskfile exists, prefer its targets (check `make help` or `task help`) over calling tools directly (e.g. use `make test` instead of `go test ./...`).
- Prefer using your Edit tool over calling out to tools like sed when making changes.
- Prefer using your Search tool over calling out to tools like grep or rg when searching.
- Use ASCII diagrams in markdown to help explain complex systems and interactions.