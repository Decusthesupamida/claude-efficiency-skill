#!/bin/bash
# token-meter.sh
# Hook type: PostToolUse (matcher: Read)
# Records the size of every file Claude reads so users can measure real
# context consumption instead of trusting marketing numbers.
#
# Output: .claude/metrics.jsonl — one JSON object per read.
#   { "ts": "...", "file": "...", "bytes": N, "approx_tokens": N/4 }
#
# Aggregate with:  jq -s 'map(.bytes)|add' .claude/metrics.jsonl

set -u

INPUT="$(cat)"

if command -v jq >/dev/null 2>&1; then
  TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  TOOL=$(printf '%s' "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
  FILE=$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
fi

[[ "$TOOL" != "Read" ]] && exit 0
[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

# Strip real + literal newlines and CR from FILE to prevent log/JSON injection.
FILE=${FILE//$'\n'/}
FILE=${FILE//$'\r'/}
FILE=${FILE//'\n'/_}
FILE=${FILE//'\r'/_}

BYTES=$(wc -c < "$FILE" 2>/dev/null | tr -d ' ')
[[ -z "$BYTES" || ! "$BYTES" =~ ^[0-9]+$ ]] && exit 0

APPROX_TOKENS=$((BYTES / 4))
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

mkdir -p .claude

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ts "$TS" --arg file "$FILE" --argjson bytes "$BYTES" --argjson tok "$APPROX_TOKENS" \
    '{ts:$ts, file:$file, bytes:$bytes, approx_tokens:$tok}' >> .claude/metrics.jsonl
else
  ESCAPED_FILE=$(printf '%s' "$FILE" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"ts":"%s","file":"%s","bytes":%s,"approx_tokens":%s}\n' \
    "$TS" "$ESCAPED_FILE" "$BYTES" "$APPROX_TOKENS" >> .claude/metrics.jsonl
fi

exit 0
