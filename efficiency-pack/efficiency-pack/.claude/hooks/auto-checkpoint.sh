#!/bin/bash
# auto-checkpoint.sh
# Hook type: PostToolUse (matcher: Write|Edit|MultiEdit)
# Appends each file-producing tool call to .claude/edit-log.tmp so the
# checkpoint skill can reference what changed in the current session.
#
# Claude Code hooks API:
#   - stdin: JSON with { "tool_name": "...", "tool_input": { "file_path": "..." }, "tool_response": {...} }
#   - exit 0 = success (silent)

set -u

INPUT="$(cat)"

if command -v jq >/dev/null 2>&1; then
  TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
else
  TOOL=$(printf '%s' "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
  FILE=$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
fi

case "$TOOL" in
  Write|Edit|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
esac

[[ -z "$FILE" ]] && exit 0

# Strip real + literal newlines/carriage returns — either would corrupt the line-oriented log.
# jq decodes \n in JSON strings to real LF; the grep/sed fallback leaves literal \n.
# Replace both forms with a visible placeholder so the log stays single-line and grep-safe.
strip() { local v="$1"; v=${v//$'\n'/}; v=${v//$'\r'/}; v=${v//'\n'/_}; v=${v//'\r'/_}; v=${v//'|'/_}; printf '%s' "$v"; }
FILE=$(strip "$FILE")
TOOL=$(strip "$TOOL")

mkdir -p .claude
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
printf '%s | %s | %s\n' "$TIMESTAMP" "$TOOL" "$FILE" >> .claude/edit-log.tmp

# Keep log bounded — trim to last 500 entries.
if [[ $(wc -l < .claude/edit-log.tmp 2>/dev/null || echo 0) -gt 500 ]]; then
  tail -n 500 .claude/edit-log.tmp > .claude/edit-log.tmp.new && mv .claude/edit-log.tmp.new .claude/edit-log.tmp
fi

exit 0
