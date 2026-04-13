#!/bin/bash
# Claude Code Efficiency Pack — installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Decusthesupamida/claude-efficiency-skill/main/efficiency-pack/efficiency-pack/install.sh | bash
#
# Override the source with:
#   EFFICIENCY_PACK_REPO=https://raw.githubusercontent.com/<user>/<repo>/<branch>/<path> bash install.sh

set -euo pipefail

# Raw-content URL pointing at the inner pack directory (where CLAUDE.md / .claude/ live).
REPO="${EFFICIENCY_PACK_REPO:-https://raw.githubusercontent.com/Decusthesupamida/claude-efficiency-skill/main/efficiency-pack/efficiency-pack}"
TARGET=".claude"
BEGIN_MARKER="<!-- efficiency-pack:begin -->"
END_MARKER="<!-- efficiency-pack:end -->"

echo "→ Installing Claude Code Efficiency Pack from: $REPO"

mkdir -p "$TARGET/skills" "$TARGET/rules" "$TARGET/hooks"

# Download helper — refuses to overwrite existing user files unless FORCE=1.
download() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" && "${FORCE:-0}" != "1" ]]; then
    echo "⚠  $dest already exists — skipped (set FORCE=1 to overwrite)."
    return 0
  fi
  curl -fsSL "$url" -o "$dest"
}

# Skills (on-demand)
download "$REPO/.claude/skills/task-decomposer.md"  "$TARGET/skills/task-decomposer.md"
download "$REPO/.claude/skills/checkpoint.md"       "$TARGET/skills/checkpoint.md"

# Rules (always-on)
download "$REPO/.claude/rules/context-guardian.md"  "$TARGET/rules/context-guardian.md"

# Hooks — always overwrite these; they are the pack's implementation, not user content.
for h in context-filter.sh token-meter.sh auto-checkpoint.sh session-start.sh; do
  curl -fsSL "$REPO/.claude/hooks/$h" -o "$TARGET/hooks/$h"
done
chmod +x "$TARGET/hooks/"*.sh

# Bench + clean scripts
curl -fsSL "$REPO/bench.sh" -o "bench.sh"
curl -fsSL "$REPO/clean.sh" -o "clean.sh"
chmod +x bench.sh clean.sh

# Optional: merge-settings.sh — used when settings.json already exists.
curl -fsSL "$REPO/merge-settings.sh" -o "merge-settings.sh"
chmod +x merge-settings.sh

# Settings: if present, try automatic merge via jq; otherwise download fresh.
if [[ -f "$TARGET/settings.json" ]]; then
  echo "→ $TARGET/settings.json already exists — attempting automatic merge…"
  if command -v jq >/dev/null 2>&1; then
    curl -fsSL "$REPO/.claude/settings.json" -o "$TARGET/settings.json.pack"
    bash ./merge-settings.sh "$TARGET/settings.json" "$TARGET/settings.json.pack" && \
      rm -f "$TARGET/settings.json.pack" && \
      echo "✓ settings.json merged."
  else
    echo "⚠  jq not available — cannot auto-merge settings.json."
    echo "   Install jq, or hand-merge from: $REPO/.claude/settings.json"
  fi
else
  curl -fsSL "$REPO/.claude/settings.json" -o "$TARGET/settings.json"
fi

# CLAUDE.md: append inside identifiable markers so users can find/remove the block.
fetch_pack_claude_block() {
  printf '\n%s\n' "$BEGIN_MARKER"
  curl -fsSL "$REPO/CLAUDE.md"
  printf '\n%s\n' "$END_MARKER"
}

if [[ -f "CLAUDE.md" ]]; then
  if grep -qF "$BEGIN_MARKER" CLAUDE.md; then
    echo "→ CLAUDE.md already contains efficiency-pack block — skipped."
  else
    fetch_pack_claude_block >> CLAUDE.md
    echo "→ Appended pack preamble to existing CLAUDE.md (between markers)."
  fi
else
  fetch_pack_claude_block > CLAUDE.md
  echo "→ Created CLAUDE.md."
fi

# .gitignore: runtime artifacts must not be committed.
touch .gitignore
for entry in ".claude/checkpoint.md" ".claude/edit-log.tmp" ".claude/metrics.jsonl" ".claude/metrics.jsonl.bak" ".claude/settings.local.json"; do
  if ! grep -qxF "$entry" .gitignore; then
    echo "$entry" >> .gitignore
  fi
done

# Optional dependency check.
if ! command -v jq >/dev/null 2>&1; then
  echo "ℹ  'jq' not found. Hooks work without it (grep/sed fallback)."
  echo "   bench.sh and settings.json auto-merge REQUIRE jq — install from your package manager."
fi

echo ""
echo "✓ Efficiency Pack installed."
echo ""
echo "  Skills:  task-decomposer, checkpoint"
echo "  Rules:   context-guardian"
echo "  Hooks:   context-filter, token-meter, auto-checkpoint, session-start"
echo "  Scripts: ./bench.sh, ./clean.sh, ./merge-settings.sh"
echo ""
echo "  To remove: delete the block between '$BEGIN_MARKER' and '$END_MARKER'"
echo "  in CLAUDE.md and remove the pack files from .claude/."
