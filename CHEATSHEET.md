# Workflow: PM-Berater + Session-Sync

Nur die 6 Skills die wir dafür gebaut haben — Multi-Session-Workflow für große Projekte.
Liegen in `~/.agents/skills/`, laufen in **Claude Code + Codex**.

---

## Die 6 Commands

| Command | Wann | Zweck |
|---------|------|-------|
| `/pm-consultant` | Projektstart + alle paar Tage | Plant, berät, generiert Briefings — nie Code |
| `/sync-init <name>` | 1× am Start jeder Session | Registriert Session |
| `/sync-start` | Anfang jeder Arbeits-Session | Zeigt was andere Sessions gemacht haben |
| `/sync-end` | Vor Pause / Session-Ende | Status-Update + Contract-Warnung |
| `/sync-status` | Jederzeit | Tabelle aller Sessions |
| `/feierabend` | Ganz am Ende | Zero-question Abschluss + HANDOFF.md |

---

## Der perfekte Workflow

### 1. Kickoff (1× pro Projekt, Solo-Session)

```
/pm-consultant
```
→ Er fragt 3 Dinge (Was baust du, Greenfield?, Deadline-Gefühl?)
→ Schlägt **3–7 Work Packages** + Dependency-Graph vor
→ Diskutiert Session-Splits (was parallel, was seriell)
→ Legt `.plan/` (im Projekt-Root, NICHT unter `.claude/`) an: `overview.md`, `decisions.md`, `beratung-log.md`

Dann:
```
"schreib mir briefings für alle packages"
```
→ Copy-Paste-Ready Markdown-Blöcke pro Session

---

### 2. Parallele Arbeit (N Sessions gleichzeitig)

**Jede Session — immer derselbe Einstieg:**

```
[Briefing aus Phase 1 in den Chat pasten]
/sync-init auth-feature          # eigener Name
/sync-start                       # was machen die anderen?
```

**Während der Arbeit:**
- Contract-Änderung (API, Types, DB-Schema)? → ankündigen, am Ende mit `/sync-end` in `_shared.md` dokumentieren
- Frage an andere Session? → in eigenem Session-File unter "Open questions" mit `@other-session` taggen
- Zwischendurch Überblick nötig? → `/sync-status`

**Session-Ende — immer in dieser Reihenfolge:**

```
/sync-end        # Status + Contract-Check (ja/gesehen/nein)
/feierabend      # Abschluss-Report + HANDOFF.md
```

---

### 3. Regelmäßiger Strategie-Check (alle 2–3 Tage)

```
/pm-consultant
```
→ Er liest **still**: `.plan/` + `.sync/` + `HANDOFF.md` + `git log` seit letzter Beratung
→ Zeigt Delta:
   - ✓ Erledigt (mit Commits)
   - ⚠️ Abweichungen vom Plan
   - 🔄 Neue Contract-Changes
   - 📝 Offene Action-Items vom letzten Mal

Dann freies Gespräch:
- Entscheidungen → neue ADRs in `decisions.md`
- Neue Pakete → Plan-Update + neue Briefings
- Blockierte Session → Re-Priorisierung

**Und immer am Ende:** "Next Actions"-Tabelle mit konkreten `/sync-init <name>`-Befehlen + empfohlenem Modus (Plan / Auto / Bypass-Permissions) + 1-Satz-Briefing pro Session.

---

## Dateisystem

Alle Workflow-Artefakte liegen **im Projekt-Root, NICHT unter `.claude/`** — Claude Code hat für `.claude/` eine hardcoded sensitive-file protection, die bei jedem Write prompted (auch im Bypass-Permissions-Modus).

```
<projekt>/
├── .plan/                  ← /pm-consultant
│   ├── overview.md         Work Packages + Status (living)
│   ├── decisions.md        ADRs (append-only)
│   ├── beratung-log.md     Jede Beratung (append-only)
│   └── briefings/          Optional: gespeicherte Briefings
│
├── .sync/                  ← /sync-*
│   ├── _shared.md          Contracts, Types, Breaking Changes
│   ├── _active.json        Session-Registry
│   └── <session>.md        Pro Session: Scope, Files, Fragen
│
└── HANDOFF.md              ← /feierabend (Root-Level, sichtbar in git)
```

---

## Goldene Regeln

1. **`/pm-consultant` schreibt nie Code.** Implementierung → immer neue Session mit Briefing.
2. **`/sync-end` blockt nie.** Contract-Warnung = "ja / gesehen / nein", kein Stopp.
3. **Eine Session = ein Name.** `/sync-init` einmal, dann bleibt er stecken.
4. **`_shared.md` ist die Wahrheit** für alles zwischen Sessions.
5. **`@<session>`-Tags** nutzen — der Empfänger sieht sie bei `/sync-start`.
6. **Nach Pause immer erst `/pm-consultant`** — nie blind reinspringen, er hat den Überblick.

---

## Git-Policy (wer committet, wer pusht)

Klare Zuständigkeiten — keine manuelle Pflege mehr:

| Wer | Was | Wann |
|-----|-----|------|
| **`/pm-consultant`** Kickoff | Setzt `git config --local user.name/email`, dokumentiert Identity + Branch-Policy in `.plan/overview.md` | Einmal beim Projekt-Start |
| **`/pm-consultant`** Refresh | Prüft Identity-Match, warnt bei Mismatch, schlägt neue Branches pro WP vor (Next-Actions-Tabelle hat Branch-Spalte) | Bei jeder Beratung |
| **Working Session** | `git checkout -b <branch>` (falls im Briefing empfohlen) — dann arbeiten | Am Session-Start |
| **`/sync-end`** | `git add <touched files>` + `git commit` mit sauberer Message. **NICHT pushen.** | Pro Session-Ende, 1 Commit |
| **`/feierabend`** | `git push` wenn Pre-flight grün (Upstream, clean, tests green, Identity-Match) | Am absoluten Session-Ende |
| **User manuell** | Rewrites (rebase, filter-branch), Force-Pushes, cherry-picks, Resolves von Merge-Konflikten | Bei Bedarf |

**Pre-flight-Fails beim Push werden im `/feierabend`-Report geskipped + gemeldet** — nie blockiert, nie geforced.

**Branch-Strategie:** pm-consultant entscheidet pro Work-Package mit (Spalte in Next-Actions):
- `main` bei Solo-Session + kleinem Scope
- `feat/<name>` bei parallelen Sessions (sonst Merge-Chaos)
- `fix/`, `chore/`, `spike/` je nach Kontext

---

## TL;DR

```
Start:    /pm-consultant → Git-Identity + Briefings + Next-Actions-Tabelle
Session:  git checkout <branch> → /sync-init → /sync-start → arbeiten
          → /sync-end (committed) → /feierabend (pusht)
Check:    /pm-consultant (er refreshed sich selbst, prüft Identity)
```
