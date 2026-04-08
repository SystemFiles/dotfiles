---
name: chezmoi-sync
description: Interactively review and sync drift between local files and chezmoi-tracked state, file by file with diffs
---

# Chezmoi Sync

You are helping the user identify and resolve drift between their local filesystem and their chezmoi-managed dotfiles. Work through this interactively, file by file, showing clear diffs.

## Invocation

Check if the argument `sync-all` (or `--sync-all`) was passed when this command was invoked. If it was, set `SYNC_ALL=true` — you will re-add all tracked drifted files without prompting for each one (but still show diffs). Otherwise `SYNC_ALL=false`.

## Phase 1: Tracked Files with Drift

### Step 1: Get the full diff

Run:

```bash
chezmoi diff
```

This outputs a unified diff (like `git diff`) of what `chezmoi apply` would change — i.e. the difference between what chezmoi thinks the files should look like and what's actually on disk. Parse this output carefully.

- Lines starting with `diff --git a/` (or `---`/`+++`) tell you which file is being discussed.
- chezmoi diff shows what *apply* would do: if local has drifted from the chezmoi source, the diff shows source → local direction from chezmoi's perspective.

### Step 2: Identify tracked files that have drifted

Run:

```bash
chezmoi managed
```

This lists every file currently tracked by chezmoi (one path per line, relative to the home directory, e.g. `.zshrc`, `.config/nvim/init.lua`).

Cross-reference the diff output against this list to produce two separate sets:
1. **Tracked + drifted**: files that appear in both `chezmoi managed` and `chezmoi diff`
2. **Untracked + present in diff**: files in the diff that are NOT in `chezmoi managed` (these are new local files chezmoi doesn't know about yet)

### Step 3: Process tracked drifted files

If there are no tracked drifted files, say so and skip to Phase 2.

Otherwise, announce:

```
Found N tracked file(s) with local drift. Reviewing each one.
```

For each tracked drifted file (in the order they appeared in the diff):

#### 3a. Show the diff for this file

Extract and display the per-file diff section. To get a clean diff for a single file, run:

```bash
chezmoi diff -- <absolute-path-to-file>
```

For example: `chezmoi diff -- ~/.zshrc`

Display it in a fenced code block with `diff` syntax highlighting so additions/removals are clear.

Explain in one sentence what the diff means: e.g. "Your local `~/.zshrc` has 3 lines that differ from what chezmoi has stored."

#### 3b. Ask or auto-sync

If `SYNC_ALL=true`:
- Run `chezmoi re-add <absolute-path>` immediately
- Report: `✓ Re-added ~/.zshrc`
- Continue to the next file

If `SYNC_ALL=false`:
- Ask the user:

  ```
  Re-add this file to chezmoi? (y/n/skip-all)
    y        — run chezmoi re-add for this file
    n        — leave it as-is
    skip-all — stop reviewing tracked files and move to Phase 2
  ```

- If `y`: run `chezmoi re-add <absolute-path>` and report success
- If `n`: note it was skipped, move to next file
- If `skip-all`: stop Phase 1 and proceed to Phase 2

### Step 4: Phase 1 summary

After processing all tracked files, print a brief summary:

```
Phase 1 complete.
  Re-added: N file(s)
  Skipped:  N file(s)
```

---

## Phase 2: New Local Files (Not Yet Tracked)

### Step 5: Check for untracked files in the diff

Use the set of untracked files identified in Step 2.

Additionally, to catch files that chezmoi is aware of as new (not yet added), you can run:

```bash
chezmoi status
```

Lines beginning with `?` indicate files chezmoi has detected but doesn't yet manage. Merge these with the untracked files from the diff.

If there are no untracked/new files, say so and skip to the final summary.

### Step 6: Ask whether to review new files

```
Found N new local file(s) not yet tracked by chezmoi.
Would you like to review and potentially add them? (y/n)
```

If `n`: skip to the final summary.

### Step 7: Process each new file

For each untracked file:

#### 7a. Show the file contents or diff

Run:

```bash
chezmoi diff -- <absolute-path>
```

If that produces no output (chezmoi doesn't know about it at all), show the file contents instead:

```bash
cat <absolute-path>
```

Display in a fenced code block.

#### 7b. Ask whether to add it

```
Add ~/.some/new/file to chezmoi? (y/n)
  y — run chezmoi add <absolute-path>
  n — skip
```

- If `y`: run `chezmoi add <absolute-path>` and report success
- If `n`: skip

---

## Final Summary

After both phases are complete, print a concise summary:

```
Chezmoi sync complete.

Phase 1 (tracked files):
  Re-added: N
  Skipped:  N

Phase 2 (new files):
  Added:    N
  Skipped:  N

Reminder: run `chezmoi apply` if you want to go the other direction (push chezmoi state → disk).
```

---

## Notes

- Always use absolute paths (e.g., `~/.zshrc` or `$HOME/.zshrc`) when calling `chezmoi re-add` or `chezmoi add`.
- If any command fails, show the error output and ask the user how to proceed — don't silently skip.
- The `sync-all` override applies only to Phase 1 (tracked files). Phase 2 always asks explicitly since adding new files to chezmoi is a deliberate decision.
