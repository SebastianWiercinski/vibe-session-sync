---
name: sync-status
description: Compact overview of all registered session-sync sessions in this project. Use when the user types `/sync-status`, says "sync status", "welche sessions sind aktiv", "show all sessions", "sync overview". Read-only — shows names, branches, last-active, open questions, scope summaries in a table.
---

# Sync Status

Show a compact overview of all registered sessions and their current state. Read-only — no file updates.

## Steps

1. **Check for sync setup:**
   - If `.sync/` or `.sync/_active.json` missing → say: "Keine Session-Sync in diesem Projekt eingerichtet. Start mit `/sync-init <name>`." Exit.

2. **Read `_active.json`**, get list of all registered sessions.

3. **For each session**, read `.sync/<name>.md` and extract:
   - Session name
   - Branch
   - Last active (humanize: "2h ago", "5min ago", "yesterday")
   - Scope (first non-empty line under "## Scope")
   - Count of open questions
   - Count of touched files
   - Any questions tagged at any session (show `@targets`)

4. **Read `_shared.md`** for mtime — how long since last shared context update.

5. **Output as table:**

   ```
   📊 Session-Sync Übersicht
   Shared context: zuletzt aktualisiert vor X

   ┌─────────────────────┬───────────────┬─────────────┬──────────┬───────────┐
   │ Session             │ Branch        │ Last active │ Files    │ Questions │
   ├─────────────────────┼───────────────┼─────────────┼──────────┼───────────┤
   │ auth-feature        │ feat/auth     │ 10min ago   │ 5        │ 2 → @fe   │
   │ checkout-redesign   │ feat/checkout │ 2h ago      │ 12       │ 1 → @be   │
   │ admin-dashboard     │ feat/admin    │ yesterday   │ 8        │ 0         │
   └─────────────────────┴───────────────┴─────────────┴──────────┴───────────┘

   🔔 Offene Fragen zwischen Sessions:
   - auth-feature → @checkout-redesign: <first open question>
   - checkout-redesign → @auth-feature: <first open question>

   Scope per session:
   - auth-feature:      JWT-based auth mit Refresh-Token-Rotation
   - checkout-redesign: Neues Checkout-Flow mit Stripe Payment Intents
   - admin-dashboard:   Admin-UI für User-Management
   ```

6. If there are stale sessions (last_active > 7 days), flag them:
   `⚠️  <name> war zuletzt vor X Tagen aktiv — noch relevant?`
