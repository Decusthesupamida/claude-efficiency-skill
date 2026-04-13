#!/bin/bash
# session-start.sh
# Hook type: SessionStart
# If .claude/checkpoint.md exists, inject its contents into the session so
# Claude can resume without the user needing to say "resume from checkpoint".
#
# Claude Code hooks API:
#   - stdout: JSON with { "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "..." } }
#   - exit 0 = success

set -u

CHECKPOINT=".claude/checkpoint.md"

if [[ ! -f "$CHECKPOINT" ]]; then
  exit 0
fi

# Skip if checkpoint is empty.
if [[ ! -s "$CHECKPOINT" ]]; then
  exit 0
fi

CONTENT=$(cat "$CHECKPOINT")

HEADER="[efficiency-pack] Found unfinished checkpoint at .claude/checkpoint.md. \
Review it and ask the user: 'Resume from checkpoint? (yes / show full plan / cancel)'. \
Do not act on it automatically. Contents follow:"

FULL="$HEADER"$'\n\n'"$CONTENT"

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$FULL" | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
else
  # Minimal JSON-escape fallback: escape backslashes, quotes, newlines.
  ESCAPED=$(printf '%s' "$FULL" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS="\\n"}{print}')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$ESCAPED"
fi

exit 0
