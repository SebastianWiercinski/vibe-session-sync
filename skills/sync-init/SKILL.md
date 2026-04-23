---
name: sync-init
description: Initialize session-sync tracking with a chosen name, triggered ONLY by the explicit `/sync-init <name>` slash command. Never auto-trigger on natural-language phrases like "start session sync", "init sync", "register this session", or similar — this skill should remain user-initiated. Sets up `.sync/` structure (project root) with per-session status files and shared contract doc for coordinating multiple parallel Claude/Codex sessions on the same project.
---

# Sync Init

Initialize session-sync for this session.

## Determine session name

Extract the session name from the user's invocation:
- If they typed `/sync-init <name>` → name is `<name>`
- If they said "sync init as X" or similar → name is `X`
- If no name provided → ask once: "Wie soll diese Session heißen? (z.B. `auth-feature`, `checkout-redesign`)"

In the rest of this document, `<name>` refers to the determined session name.

## Steps

1. **Create sync directory** if missing: `.sync/` (at project root — NOT under `.claude/`, since Claude Code's hardcoded `.claude/` sensitive-file protection would keep prompting).

2. **Create `.sync/_shared.md`** if missing, with template:
   ```
   # Shared Context
   _Last modified: <iso-timestamp>_

   ## Contracts / Shared Types / API Surface
   <!-- Document anything multiple sessions depend on: endpoints, schemas, shared types, config keys -->

   ## Breaking Changes Log
   <!-- Append-only. Format: YYYY-MM-DD HH:MM @session-name — description -->

   ## Global Assumptions
   <!-- Architecture decisions, naming conventions, tooling choices -->
   ```

3. **Create `.sync/_active.json`** if missing: `{"sessions": {}}`

4. **Check for name collision:** Read `_active.json`. If `<name>` exists as session key → ask user: overwrite or pick different name?

5. **Detect git branch:** Run `git rev-parse --abbrev-ref HEAD 2>/dev/null` — use result or `"none"`.

6. **Create `.sync/<name>.md`** with template:
   ```
   # <name>
   _Started: <iso-timestamp> · Last active: <iso-timestamp> · Branch: <branch>_

   ## Scope
   <!-- What is this session building? Fill in when you know. -->

   ## Touched files
   <!-- Auto-maintained by /sync-end -->

   ## Contract-relevant changes
   <!-- Anything that touches _shared.md territory -->

   ## Open questions for other sessions
   <!-- Use @other-session-name to tag -->

   ## Next steps
   ```

7. **Update `_active.json`**: add entry under `sessions.<name>`:
   ```json
   {
     "started": "<iso>",
     "last_active": "<iso>",
     "branch": "<branch>",
     "last_seen_shared": "<iso>",
     "last_seen_sessions": {}
   }
   ```

8. **Gitignore decision** — ask user (this is a one-time project-level decision, worth the single question):
   > "Soll `.sync/` in git getrackt werden?
   > — **Ja (tracked)**: Sessions auf verschiedenen Branches sehen sich gegenseitig via git pulls. Empfohlen bei Multi-Branch-Workflow.
   > — **Nein (gitignored)**: Rein lokale Koordination, kein Noise in Commits. Empfohlen wenn alle Sessions am gleichen Branch arbeiten."

   If user picks gitignored: append `.sync/` to `.gitignore` (create if missing).

9. **Remember the session name `<name>`** for the rest of this conversation. Use it automatically in subsequent `/sync-end`, `/sync-start`, `/sync-status` calls — don't ask again unless the conversation is compacted/resumed and the name is unclear.

## Output
Confirm:
- ✓ Session registered as `<name>`
- ✓ Files: `_shared.md`, `_active.json`, `<name>.md`
- ✓ Branch: `<branch>`
- ✓ Gitignore: tracked/ignored
- Nächster Schritt: `/sync-start` um zu sehen was andere Sessions machen, oder direkt loslegen und am Ende `/sync-end`.
