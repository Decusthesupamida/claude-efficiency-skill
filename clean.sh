#!/bin/bash
# clean.sh — Remove runtime artifacts produced by the Efficiency Pack.
#
# Usage:
#   ./clean.sh              # interactive: show what would be removed, confirm
#   ./clean.sh --yes        # non-interactive: remove without asking
#   ./clean.sh --dry-run    # show what would be removed, remove nothing
#   ./clean.sh --all        # also drop the current checkpoint (default keeps it)
#   ./clean.sh --help
#
# What it removes:
#   .claude/edit-log.tmp       (always)
#   .claude/metrics.jsonl      (always)
#   .claude/metrics.jsonl.bak  (always, if present)
#   .claude/checkpoint.md      (only with --all)
#
# What it leaves alone:
#   .claude/settings.json, skills/, rules/, hooks/ — the pack itself.
#   Anything outside .claude/ — never touched.

set -u

MODE="interactive"
INCLUDE_CHECKPOINT=0

for arg in "$@"; do
  case "$arg" in
    --yes|-y)      MODE="force" ;;
    --dry-run|-n)  MODE="dry-run" ;;
    --all)         INCLUDE_CHECKPOINT=1 ;;
    --help|-h)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "clean.sh: unknown argument '$arg' (try --help)" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d ".claude" ]]; then
  echo "clean.sh: no .claude/ directory here — nothing to clean."
  exit 0
fi

TARGETS=(
  ".claude/edit-log.tmp"
  ".claude/metrics.jsonl"
  ".claude/metrics.jsonl.bak"
)

if [[ "$INCLUDE_CHECKPOINT" -eq 1 ]]; then
  TARGETS+=(".claude/checkpoint.md")
fi

EXISTING=()
TOTAL_BYTES=0

for t in "${TARGETS[@]}"; do
  if [[ -e "$t" ]]; then
    EXISTING+=("$t")
    sz=$(wc -c < "$t" 2>/dev/null | tr -d ' ')
    [[ -n "$sz" ]] && TOTAL_BYTES=$((TOTAL_BYTES + sz))
  fi
done

if [[ "${#EXISTING[@]}" -eq 0 ]]; then
  echo "clean.sh: nothing to remove — runtime artifacts already gone."
  [[ "$INCLUDE_CHECKPOINT" -eq 0 && -f ".claude/checkpoint.md" ]] && \
    echo "         (checkpoint kept — pass --all to drop it too)"
  exit 0
fi

echo "clean.sh: will remove ${#EXISTING[@]} file(s), ~${TOTAL_BYTES} bytes:"
for f in "${EXISTING[@]}"; do
  printf '  - %s\n' "$f"
done

if [[ "$INCLUDE_CHECKPOINT" -eq 0 && -f ".claude/checkpoint.md" ]]; then
  echo "  (keeping .claude/checkpoint.md — pass --all to drop it)"
fi

case "$MODE" in
  dry-run)
    echo "clean.sh: dry run — no files removed."
    exit 0
    ;;
  interactive)
    printf 'Proceed? [y/N] '
    read -r reply
    case "$reply" in
      y|Y|yes|YES) ;;
      *)
        echo "clean.sh: aborted."
        exit 0
        ;;
    esac
    ;;
  force) ;;
esac

for f in "${EXISTING[@]}"; do
  rm -f -- "$f"
done

echo "clean.sh: removed ${#EXISTING[@]} file(s)."
