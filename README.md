# vibe-session-sync

Six skills for running large projects across multiple parallel AI coding sessions — built for **Claude Code + Codex**, live-coded to solve real pain-points of a solo developer juggling 5+ parallel agents on the same codebase.

A PM-consultant plans and briefs. A sync layer coordinates contracts between sessions. A Feierabend ritual ships cleanly at the end of the day.

> German-first skill content (the author works in German). Commands and semantics are universal.

---

## What's inside

| Skill | Purpose |
|-------|---------|
| **`/pm-consultant`** | Plans the project, proposes work packages, writes session briefings, sets Git identity. Never writes code. |
| **`/sync-init <name>`** | Registers a session in `.sync/` |
| **`/sync-start`** | Shows what other parallel sessions have changed |
| **`/sync-end`** | Status-update + contract-warning + `git commit` (no push) |
| **`/sync-status`** | Table of all sessions + open questions between them |
| **`/feierabend`** | Zero-question session wrap-up: HANDOFF.md + `git push` of all branches |

**Design principles:**

- **Zero-friction.** `/feierabend` never asks questions — parallel scan, write safe artifacts, single report.
- **Warn-only.** `/sync-end` warns on contract-relevant changes but never blocks.
- **No blind code.** `/pm-consultant` advises and produces briefings; users paste them into new sessions.
- **File-based IPC.** Sessions can't wake each other up. Everything flows through `.sync/*.md` and `.plan/*.md`, pulled via `/sync-start`.
- **Clean Git ownership.** Sessions commit at `/sync-end`, `/feierabend` pushes. `/pm-consultant` sets `git config --local` at kickoff. No `--force`, ever.
- **Stack-agnostic.** Everything is Markdown — no JSON schemas, no TypeScript lock-in.

---

## Quick start

```bash
git clone https://github.com/SebastianWiercinski/vibe-session-sync.git
cd vibe-session-sync
./install.sh
```

The install script symlinks `skills/*` into `~/.agents/skills/` and `~/.claude/skills/` (both paths are read by Claude Code and Codex). Existing installations are left untouched — it refuses to overwrite real directories.

Restart Claude Code / Codex so the skills get picked up. Then in any project:

```
/pm-consultant
```

…and follow the prompts. First question: "What are you building?"

---

## The full workflow

Rendered cheatsheet: [**live page**](https://sebastianwiercinski.github.io/vibe-session-sync/) · Plain-text: [**`CHEATSHEET.md`**](./CHEATSHEET.md) · Source: [**`index.html`**](./index.html)

**TL;DR:**

```
Start:    /pm-consultant → Git-Identity + Briefings + Next-Actions-Tabelle
Session:  git checkout <branch> → /sync-init → /sync-start → work
          → /sync-end (commits)  →  /feierabend (pushes)
Check:    /pm-consultant (self-refreshes, verifies identity)
```

---

## Filesystem layout (created in each project)

```
<project>/
├── .plan/                    ← /pm-consultant
│   ├── overview.md           work packages, status, git setup (living)
│   ├── decisions.md          ADRs (append-only)
│   ├── beratung-log.md       every consultation (append-only)
│   └── briefings/            optional: stored session briefings
│
├── .sync/                    ← /sync-*
│   ├── _shared.md            contracts, shared types, breaking changes
│   ├── _active.json          session registry
│   └── <session>.md          per session: scope, files, questions
│
└── HANDOFF.md                ← /feierabend (root, visible in git)
```

**Why not `.claude/`?** Claude Code has a hardcoded sensitive-file protection for `.claude/**` (with exemptions for `commands/`, `agents/`, `skills/`) that can't be bypassed via hooks or `permissionDecision: "allow"`. So we put artifacts at project-root instead.

---

## Git orchestration

Cleanly split so no one steps on anyone's toes:

| Who | What | When |
|-----|------|------|
| `/pm-consultant` | `git config --local user.name/email`, documents identity + branch-policy in `overview.md` | Kickoff |
| `/pm-consultant` | Checks identity match, warns on mismatch, recommends branch per work-package | Every refresh |
| Working session | `git checkout -b <branch>` (if recommended in briefing), then work | Session start |
| `/sync-end` | `git add <touched files>` + `git commit`. **Does not push.** | Each session end |
| `/feierabend` | `git push` of all local branches with unpushed commits, pre-flight-gated | Absolute end of day |
| User manually | Rewrites, force-pushes, cherry-picks, merge-conflict resolves | As needed |

**Pre-flight gates** in `/feierabend`:

1. Remote exists?
2. Nothing uncommitted (tracked)?
3. Tests + typecheck green?
4. Identity match per commit on each branch?

If any gate fails → the push step is skipped with a clear report. Other branches keep pushing. Never `--force`, never blind retries.

---

## Modes

Every session runs in one of three modes — `/pm-consultant` picks per session and notes the choice in the Next-Actions table:

| Mode | When |
|------|------|
| **Plan-Mode** | Risky ops: migrations, prod config, secrets, architecture changes, broad-impact refactors |
| **Auto-Mode** | Standard feature work: new endpoints, new components, tests, clear-scope coding |
| **Bypass-Permissions** | Low-risk: docs, markdown edits, `.plan/` updates, repetitive configs |

Both Claude Code and Codex support all three modes (different flag names — `--dangerously-skip-permissions` vs `--yolo` — but same semantics).

---

## Development

Each skill is a single `SKILL.md` file with YAML frontmatter:

```yaml
---
name: skill-name
description: 1 sentence + trigger phrases the LLM matches against
---

# Skill content...
```

Edit in `skills/<name>/SKILL.md`. After changing a skill, restart Claude Code / Codex so it picks up the new version.

Manual test in a scratch repo:

```bash
mkdir -p /tmp/skill-test && cd /tmp/skill-test && git init
# Open Claude Code / Codex here, run /sync-init test-session
# Verify .sync/_shared.md, .sync/_active.json, .sync/test-session.md exist
```

---

## License

MIT — see [LICENSE](./LICENSE). Use freely, modify, redistribute. No warranty.
