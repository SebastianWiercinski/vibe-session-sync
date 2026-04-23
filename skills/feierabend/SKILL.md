---
name: feierabend
description: End-of-session routine, triggered ONLY by the explicit `/feierabend` slash command. Never auto-trigger on natural-language phrases like "wrap up", "end of session", "pack up", or similar conversational/thinking language — this skill performs git pushes and must stay user-initiated. Scans git/tests/memory/plans in parallel, writes safe artifacts (HANDOFF, additive memory, sync-end) silently, produces one zero-question report with copy-paste-ready commit draft and TODO list for the user.
---

# Feierabend

Finish this coding session with minimal friction. **Ziel: keine Fragen, maximal ein Report.**

## Prinzipien
- **Parallelisiere** Phase 1 aggressiv — alle read-only Checks in einem Rutsch
- **Safe stuff auto-schreiben**, nie fragen
- **Unsafe stuff reporten**, nie machen
- **Nichts fragen außer es sind echte Daten in Gefahr**
- **Keine Zusammenfassung nach dem Report** — der Report IST die Zusammenfassung

---

## Phase 1: Parallel Scan (read-only, alles gleichzeitig)

Run folgende Checks **parallel** in einem Message-Block:

### Git
- `git status --short` (modified + untracked)
- `git log --oneline @{push}..HEAD 2>/dev/null || echo "no upstream"` (unpushed)
- `git branch --show-current`
- `git diff --stat HEAD` (size der uncommitted work)
- `git stash list` (gibt's alte Stashes?)

### Quality Gates — nur was existiert
Detecte und führe aus (nur wenn vorhanden):
- `package.json` scripts: `test`, `lint`, `typecheck` (NICHT `build` — oft zu lang)
- Python: `pytest --collect-only -q` (nur sammeln, dann bei Bedarf `pytest -x`)
- Rust: `cargo check` (schneller als `cargo test`)
- Go: `go vet ./...`

Capture Exit-Code + letzte ~10 Zeilen Output. Nicht blockieren wenn fail.

### Session-Intern (kein Tool-Call)
Aus dem Conversation-Verlauf extrahieren:
- Was wurde erledigt? (Files touched, Features gebaut)
- Was ist offen? (User sagte "später" / nicht fertig / Errors)
- Welche User-Facts kamen neu dazu? (Präferenzen, Projekt-Fakten)
- Welche Feedback-Regeln wurden gesetzt/bestätigt?

### Memory
- Read `MEMORY.md` (im auto-memory directory)
- Kandidaten für neue Memories? (nur additive — neue Facts, neue Rules)
- Stale-Kandidaten? (zu flaggen, nicht zu löschen)

### Plans & TODOs
- `ls .plan/ 2>/dev/null` — offene Plans?
- Eigenes TodoWrite-Board: was ist pending?

### Sync-State (falls sync aktiv)
- `test -d .sync && cat .sync/_active.json`
- Wenn aktiv: aktuelle Session identifizieren (remembered name oder aus _active.json)

---

## Phase 2: Auto-Write Safe Artifacts (OHNE Nachfrage)

### 2.1 HANDOFF.md schreiben

Pfad: `HANDOFF.md` im Projekt-Root (overwrite). Liegt bewusst **nicht** unter `.claude/` — Claude Code's hardcoded sensitive-file protection würde sonst jedes Write prompten.

```markdown
# Session Handoff
_Session ended: <iso-timestamp> · Branch: <branch>_

## Was wurde erledigt
- <bullet, mit file refs wo sinnvoll>

## Offene Fäden
- <bullet>

## Nächste Session startet hier
<konkrete erste Action: file path + was zu tun ist>

## Status der Quality Gates
- Tests: <pass/fail/skip>
- Lint/Typecheck: <...>
- Uncommitted: X files / Unpushed: Y commits
```

### 2.2 Additive Memory-Updates
Nur **neue** Memory-Files anlegen (keine Überschreibungen, keine Löschungen).
Kandidaten:
- Neue User-Facts
- Neue Feedback-Rules (wenn klar bestätigt/korrigiert)
- Neue Project-Facts (wenn durable, nicht ephemer)

Für jeden Kandidaten: file anlegen + Pointer in `MEMORY.md` appenden.
**Nie überschreiben.** Wenn Memory stale scheint → im Report flaggen.

### 2.3 Sync-End (falls sync aktiv)
Wenn `.sync/` existiert und aktuelle Session identifizierbar:
- Eigenes Session-File updaten (Touched files, Next steps, Last active)
- `_active.json` last_active updaten
- Contract-Check: wenn Contract-relevant, NICHT fragen — einfach als `[DRAFT — needs review]` in `_shared.md` unter Breaking Changes Log appenden. User kann später manuell prüfen.

### 2.4 Plan-Files abschließen
- Für jeden offenen Plan in `.plan/`: wenn komplett erledigt → auto archivieren (move zu `.plan/archive/` mit timestamp-prefix). Wenn teilweise → nicht anfassen, nur im Report listen.

### 2.5 Git-Push (neu — Feierabend shippt, Sessions committen)

Zuständigkeit: `/sync-end` committed seine Session-Changes, `/feierabend` pusht **alle lokalen Branches mit unpushed Commits** (nicht nur den aktuellen). Ein Aufruf reicht für Multi-Session-Tage.

**Pre-flight (einmalig, gate für den ganzen Push-Schritt):**

1. **Remote existiert?** `git remote 2>/dev/null | head -1`
   - Leer → komplett SKIP. Report: "⊘ Push: kein Remote konfiguriert (`git remote add origin <url>` um zu aktivieren)."

2. **Nothing uncommitted tracked?** `git status --short | grep -v '^??'` leer?
   - Tracked-modified Files da → komplett SKIP. Report: "⚠️ Push skipped: uncommitted changes (`<X>` tracked modifications). Erst /sync-end oder manuell committen."
   - Untracked Files sind ok → aber im Report listen: "Info: <N> untracked files (nicht blockierend)"

3. **Quality Gates grün?** (aus Phase-1-Scan)
   - Tests failed / typecheck failed → komplett SKIP. Report: "⚠️ Tests/Typecheck rot — Push skipped. Fix + erneut /feierabend, oder `git push` manuell wenn bewusst."
   - Lint-Warnings ok, nur Errors blocken.

**Wenn die 3 Pre-flight-Gates grün sind → Multi-Branch-Scan:**

Für jeden **lokalen Branch** (`git for-each-ref --format='%(refname:short)' refs/heads/`) folgende Checks:

a. **Upstream:** `git rev-parse --abbrev-ref <branch>@{upstream} 2>/dev/null`
   - Upstream vorhanden → weiter zu Schritt b (mit Upstream)
   - Kein Upstream → weiter zu Schritt b (ohne Upstream, first-push-Pfad)

b. **Unpushed Commits?** — zwei Varianten je nachdem ob Upstream existiert:
   - **Mit Upstream:** `git log <branch>@{upstream}..<branch> --format='%H %ae' 2>/dev/null`
   - **Ohne Upstream:** `git log <branch> --not --remotes --format='%H %ae' 2>/dev/null`
     (Commits die auf noch keinem Remote-Ref liegen. Robuster als `@{push}` bei abgezweigten Branches ohne eigenes Upstream, weil Commits die über `origin/<parent-branch>` schon gepusht sind, korrekt ausgeschlossen werden.)
   - Leer → skip diesen Branch (nichts unpushed)
   - Nicht leer → Identity-Match pro Commit checken (nächster Schritt)

c. **Identity-Match pro Commit** (falls `.plan/overview.md` Git Setup dokumentiert):
   - Jeder unpushed Commit-Author-Email vs. dokumentierte Email
   - Mismatch gefunden → **diesen Branch NICHT pushen**, im Report flaggen:
     `⚠️ <branch>: <N> unpushed Commits, davon <M> mit Identity-Mismatch (<sha> von <wrong-email>). Rewrite via pm-consultant oder manuell, dann /feierabend erneut.`
   - Alle Match → push freigegeben

d. **Push ausführen:**
   - Mit Upstream: `git push origin <branch>`
   - Ohne Upstream (first push): `git push -u origin <branch>`
   - Bei Erfolg: Report-Eintrag `✓ <branch>: pushed <N> commits → origin/<branch>`
   - Bei Fail (rejected, diverged, non-fast-forward): Report `✗ <branch>: push rejected (<error>) — manuell resolven`, **nicht** retry, **nicht** force. Nächster Branch weiter.

**Wichtig:** Ein einzelner Branch-Fehler bricht den Gesamt-Push NICHT ab. Andere Branches werden trotzdem versucht. Am Ende Zusammenfassung mit Erfolg/Fail pro Branch.

**Report-Eintrag Gesamt:**
```
✓ Push: 2/3 Branches → origin (feat/auth, feat/checkout)
⚠ Skipped: feat/docs (Identity-Mismatch in 1 Commit)
```

Oder bei komplettem Skip:
```
⊘ Push skipped: <kombinierter Grund aus Pre-flight>
```

---

## Phase 3: Single Report (KEINE Fragen)

Ein Block, klar strukturiert. Keine weitere Konversation danach außer User fragt nach.

```
🌅 Feierabend — <time>

═══ Auto-erledigt ═══
✓ HANDOFF.md geschrieben
✓ N neue Memory-Einträge (<namen>)
✓ Sync-end für <session-name> (<N> contract-drafts in _shared.md)
✓ X abgeschlossene Plans archiviert
✓ Push: <N/M> Branches gepusht · <details pro Branch wenn Multi>
Info: <N> untracked files (nicht blockierend)

═══ Status ═══
Git:       <X> uncommitted · <Y> unpushed · branch: <branch>
Tests:     ✅ pass  |  ❌ <N> failing  |  ⊘ not defined
Lint:      ...
Typecheck: ...

═══ Noch zu tun (du, nicht ich) ═══

(Nur wenn Push oder Commit wegen Pre-flight-Fail geskipped wurde — dann:
Commit-Draft / Push-Befehl copy-paste ready, sonst leer.)

CLAUDE.md / AGENTS.md Ergänzungs-Vorschlag (nicht geschrieben):
   → Sektion "Scripts": "pnpm test:e2e läuft Playwright in Docker"
   → Sektion "Conventions": "Errors via Result<T, E> Pattern, nicht throw"

Stale Memory flagged (prüfen/löschen wenn veraltet):
   - memory/old-api.md — erwähnt v1, wir sind auf v2

Offene Plans (nicht archiviert, teilweise erledigt):
   - .plan/auth-refactor.md

═══ Known Issues / Follow-ups ═══
(entweder leer oder als list von spawn_task-Kandidaten)

Schönen Feierabend 🚀
```

### Wenn alles grün und nichts zu tun ist
Kurz halten:
```
🌅 Feierabend — alles grün
✓ HANDOFF.md geschrieben, 0 neue Memories
✓ Clean working tree, keine unpushed commits, tests pass

Schönen Feierabend 🚀
```

---

## Hard rules

- **Niemals** `git commit`, `git add` ausführen — das ist `/sync-end`'s Job
- **`git push` ist erlaubt**, aber nur wenn alle 4 Pre-flight-Checks grün sind (Upstream, clean, tests green, identity match). Sonst SKIP mit Report.
- **Niemals** `git push --force`, `--force-with-lease`, oder auf fremden Branch pushen
- **Niemals** Memory überschreiben oder löschen
- **Niemals** Source-Files anfassen — erlaubte Schreib-Zone ist ausschließlich: `.sync/**`, `.plan/**`, `HANDOFF.md` (plus Memory-Append wie in Phase 2.2 beschrieben)
- **Niemals** `build` laufen lassen wenn nicht als schnell bekannt
- **Niemals** nach dem Report weitermachen / zusammenfassen — Report ist Endpunkt
- **Niemals** fragen außer Daten sind in Gefahr (praktisch nie bei diesem Read-+-Safe-Write-Pattern)
