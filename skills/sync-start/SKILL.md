---
name: sync-start
description: Show changes from other parallel sessions since this session last checked in, triggered ONLY by the explicit `/sync-start` slash command. Never auto-trigger on natural-language phrases like "sync check", "catch up on other sessions", "was haben die anderen gemacht", or similar — this skill should remain user-initiated. Reads `.sync/_shared.md` and all other per-session status files, highlights items tagged at the current session.
---

# Sync Start

Show what has changed in other sessions and in `_shared.md` since this session last checked in.

## Steps

1. **Determine current session name:**
   - If remembered from earlier `/sync-init` in this conversation → use that
   - Else: read `.sync/_active.json`, list all session names, ask user which one is "this session"
   - If `.sync/` doesn't exist → tell user to run `/sync-init <name>` first and exit.

2. **Read `_active.json`** — get current session's `last_seen_shared` and `last_seen_sessions` map.

3. **Check `_shared.md`:**
   - Read file's mtime (`stat -f %m .sync/_shared.md` on macOS; `stat -c %Y` on Linux)
   - If mtime > `last_seen_shared` → read file, show "Shared Context updates since last check" section

4. **Check other session files:** For each `.sync/*.md` file (except `_shared.md` and `<current-session>.md`):
   - Get mtime
   - If mtime > `last_seen_sessions[<name>]` (or never seen) → flag as "new/updated"
   - Read file, summarize:
     - Last-active timestamp
     - Scope (1 line)
     - Any **Open questions** tagged `@<current-session>` → highlight these prominently
     - Top 3 entries under "Next steps" / "Touched files"

5. **Update `_active.json`:** set `sessions.<current>.last_seen_shared` = now, and `sessions.<current>.last_seen_sessions[<other>]` = now for each one shown.

## Output format

```
📋 Sync check für Session: <current-name>

═══ Shared Context (updated X min ago) ═══
<relevant diff, or "nichts Neues">

═══ Andere Sessions ═══
▸ checkout-redesign (last active 2h ago)
  Scope: Neues Checkout-Flow mit Stripe
  ⚠️  @<current-name>: Brauchst du User-Session im Cookie oder Header?
  Next: Payment-Intent endpoint finalisieren

▸ auth-feature (last active 10min ago, updated since last check)
  ...

═══ Für dich direkt ═══
- checkout-redesign fragt: <question>
- (none)
```

If no other sessions exist, say: "Du bist die einzige registrierte Session. Leg los."

Remember after this command: user has seen all updates.
