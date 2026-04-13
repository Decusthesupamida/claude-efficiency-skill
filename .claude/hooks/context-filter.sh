#!/bin/bash
# context-filter.sh
# Hook type: PreToolUse (matcher: Read)
# Blocks reads of files that context-guardian should never load.
#
# Claude Code hooks API:
#   - stdin: JSON with { "tool_name": "...", "tool_input": { "file_path": "..." } }
#   - stdout: JSON decision { "decision": "block", "reason": "..." } to block
#   - exit 0 + no decision = allow; non-zero exit = error shown to Claude

set -u

INPUT="$(cat)"

# Parse with jq if available; fall back to grep/sed.
if command -v jq >/dev/null 2>&1; then
  TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  TOOL=$(printf '%s' "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
  FILE=$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
fi

# Only intercept Read — other tools pass through.
if [[ "$TOOL" != "Read" ]]; then
  exit 0
fi

# Empty file_path = nothing to check.
if [[ -z "$FILE" ]]; then
  exit 0
fi

# Substring patterns (directory segments, extensions).
BLOCKED_PATTERNS=(
  "node_modules/"
  ".gradle/"
  "/build/"
  "/target/"
  "/dist/"
  ".next/"
  "__pycache__"
  ".pytest_cache"
  ".venv/"
  ".mypy_cache"
  ".turbo/"
  ".cache/"
)

# Suffix patterns (file extensions / lock files).
BLOCKED_SUFFIXES=(
  ".lock"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "Gemfile.lock"
  "poetry.lock"
  "Cargo.lock"
  ".log"
  ".tmp"
  ".cache"
  ".min.js"
  ".min.css"
)

emit_block() {
  local reason="$1"
  printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$reason" | jq -Rs . 2>/dev/null || printf '"%s"' "$reason")"
  exit 0
}

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if [[ "$FILE" == *"$pattern"* ]]; then
    emit_block "context-guardian: '$FILE' matches blocked path pattern '$pattern'. If truly needed, state the reason and use Bash(cat) or ask the user to unblock."
  fi
done

for suffix in "${BLOCKED_SUFFIXES[@]}"; do
  if [[ "$FILE" == *"$suffix" ]]; then
    emit_block "context-guardian: '$FILE' matches blocked suffix '$suffix' (lock/generated/minified). These rarely help and waste tokens."
  fi
done

exit 0
