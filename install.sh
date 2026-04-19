#!/usr/bin/env bash
# install.sh — symlink vibe-session-sync skills into ~/.agents/skills/ + ~/.claude/skills/
#
# Safe to re-run. Refuses to overwrite real directories (only replaces its own symlinks).
# After running, restart Claude Code / Codex so the new skills are picked up.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${HOME}/.agents/skills"
CLAUDE_DIR="${HOME}/.claude/skills"

SKILLS=(pm-consultant sync-init sync-start sync-end sync-status feierabend)

mkdir -p "$AGENTS_DIR" "$CLAUDE_DIR"

echo "Installing skills from: $REPO_DIR/skills"
echo "  → $AGENTS_DIR (primary, used by Codex)"
echo "  → $CLAUDE_DIR (symlink, used by Claude Code)"
echo

installed=0
skipped=0

for skill in "${SKILLS[@]}"; do
  src="${REPO_DIR}/skills/${skill}"
  dst="${AGENTS_DIR}/${skill}"
  link="${CLAUDE_DIR}/${skill}"

  if [ ! -d "$src" ]; then
    echo "  ✗ ${skill}: source missing ($src) — skipping"
    skipped=$((skipped+1))
    continue
  fi

  # If something exists at dst and isn't a symlink, refuse to overwrite.
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  ⚠ ${skill}: $dst exists and is not a symlink — leave it alone, move/delete manually if you want the repo version"
    skipped=$((skipped+1))
    continue
  fi

  # Remove old symlink, create fresh one pointing into the repo.
  rm -f "$dst"
  ln -s "$src" "$dst"

  # Same for the Claude-Code-visible symlink.
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "  ⚠ ${skill}: $link exists and is not a symlink — leaving it"
  else
    rm -f "$link"
    ln -s "$dst" "$link"
  fi

  echo "  ✓ ${skill}"
  installed=$((installed+1))
done

echo
echo "Summary: ${installed} installed · ${skipped} skipped"
echo
echo "Next:"
echo "  1. Restart Claude Code / Codex"
echo "  2. Open any project, run /pm-consultant to kick off"
echo "  3. Read ./CHEATSHEET.md or open ./workflow.html for the full workflow"
