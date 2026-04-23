---
name: sync-end
description: Update this session's status file and flag contract-relevant changes, triggered ONLY by the explicit `/sync-end` slash command. Never auto-trigger on natural-language phrases like "sync end", "update my session status", "log this session", "sync out", or similar conversational language — this skill creates a git commit and must stay user-initiated. Writes touched files, next steps, open questions to the session file; prompts once about contract-relevant changes but always allows user to dismiss; warns on contracts but never blocks.
---

# Sync End

Update the current session's status file based on work done in this conversation. Warn on contract-relevant changes but never block.

## Steps

1. **Determine current session name:**
   - Remembered from `/sync-init` in this conversation → use that
   - Else: read `_active.json`, ask user which session is this
   - If `.sync/` missing → suggest `/sync-init <name>` first.

2. **Review this conversation:** Collect based on what was actually done in this session:
   - **Touched files:** all files edited/created via Write/Edit tools this conversation
   - **Key decisions:** user-facing decisions made (what was built, what was rejected)
   - **Planned next steps:** what's still open / what comes next
   - **Open questions:** anything that depends on another session's work (tag with `@<session-name>`)

3. **Update `.sync/<current>.md`:**
   - Update `Last active` timestamp
   - Replace/merge "Touched files" section with current list (dedupe, keep most recent N=20)
   - Update "Next steps" (replace — it's current-state, not a log)
   - Append to "Open questions for other sessions" (don't wipe previous ones unless resolved)
   - If scope was clarified this conversation, update "Scope"

4. **Contract-relevance check.** Determine if this session touched anything others might depend on:
   - Shared types, interfaces, API endpoints (request/response shapes)
   - Database schemas, migration files
   - Env var contracts, config keys
   - Shared utility signatures
   - Public routes / URL structures
   - Event names, message formats (queues, webhooks)

   If **yes** → show user a short summary of the contract-relevant changes and ask:
   > "Diese Änderungen könnten andere Sessions betreffen:
   > - <change 1>
   > - <change 2>
   >
   > Soll ich sie in `_shared.md` eintragen? [ja / habe ich gesehen / nein]"

   - **ja** → append to `_shared.md` under "Breaking Changes Log" with format:
     `YYYY-MM-DD HH:MM @<session-name> — <description + file refs>`
     Also update relevant section (Contracts / Shared Types / etc.) if it's a durable fact, not just a one-off change.
   - **habe ich gesehen** → only add a line under "Breaking Changes Log" tagged `acknowledged` with brief description. Don't expand the contract sections.
   - **nein** → skip entirely.

   **Never block**, never fail — even on "nein", proceed.

5. **Update `_active.json`:** `sessions.<current>.last_active` = now, `sessions.<current>.branch` = current branch.

6. **Git Commit** (diese Session committed ihre eigene Arbeit — aber pusht NICHT; das macht `/feierabend`):

   **Hinweis:** Jeder `/sync-end`-Aufruf erzeugt genau einen Commit. Wenn du in derselben Session mehrfach `/sync-end` machst (z.B. Pause → weiterarbeiten → Pause), entstehen mehrere Commits. Das ist gewollt, aber wenn du das vermeiden willst: arbeite am Stück bis logischer Abschluss, dann erst `/sync-end`.


   a. **Identity-Check (gate):**
      - Read `.plan/overview.md` "Git Setup"-Sektion falls vorhanden
      - Current config: `git config user.name` + `git config user.email`
      - Wenn overview.md eine Identity dokumentiert und sie ≠ current config → **Commit NICHT ausführen**, stattdessen:
        ```
        ⚠️ Git-Identity-Mismatch
        overview.md: <name> <email>
        git config:  <name> <email>
        Fix: git config --local user.name "<name>" && git config --local user.email "<email>"
        Dann /sync-end erneut.
        ```
      - Wenn overview.md keine Identity dokumentiert → mit aktueller Config weitermachen (warnen wenn Default/Mismatch offensichtlich global ist).

   b. **Staged-Files bestimmen:**
      - `git status --short` — was ist uncommitted?
      - Wenn nichts → skip Commit (Report: "✓ No changes to commit")
      - Sonst: Liste aus Step 2 "Touched files" + falls `.sync/` tracked ist, auch `.sync/<current>.md` + `.sync/_active.json` (+ ggf. `.sync/_shared.md` wenn contract-check "ja" oder "gesehen" war)
      - Vorsicht bei Files die diese Session **nicht** touched hat aber uncommitted sind → **NICHT** adden. Im Report listen: "⚠️ Uncommitted außerhalb Session-Scope: <files> — manuell handhaben"

   c. **Commit-Message aus Session-Kontext bauen** (1-Zeiler-Summary + Detail-Bullets):
      ```
      <session-name>: <was wurde gemacht, 1 Zeile ≤60 Zeichen>

      - <key change 1 aus touched files + decisions>
      - <key change 2>
      - <... max ~5 bullets>

      Session: <session-name> · <N> files
      ```
      Summary ableiten aus Scope + Key-Decisions aus dieser Conversation. Bei Contract-Änderung → Summary-Prefix `feat(contract):`, bei Bugfix → `fix:`, sonst frei.

   d. **Commit ausführen:**
      - `git add <file1> <file2> ...` (explizit, nie `-A`)
      - `git commit -m "..."` mit HEREDOC für saubere Formatierung
      - **NIEMALS `git push`** — das ist `/feierabend`'s Job

   e. **Bei Pre-Commit-Hook-Fehler:** Output zeigen, Commit nicht wiederholen. User fixt manuell, dann `/sync-end` erneut.

7. **Summary output:**
   ```
   ✓ Session <name> aktualisiert
     - X files touched, Y next steps, Z open questions
   ✓ Contract-Check: <keine Änderungen | X Änderungen dokumentiert | Änderungen acknowledged>
   ✓ Git: committed <short-sha> "<summary>" (<N> files)
     — oder —
   ✓ Git: nothing to commit
     — oder —
   ⚠️ Git: Identity-Mismatch, Commit skipped (siehe oben)

   Nächste Session die mit dir arbeitet sieht das via /sync-start.
   Push passiert am Ende mit /feierabend.
   ```
