#!/bin/bash
# merge-settings.sh — Merge efficiency-pack hooks into an existing Claude Code settings.json.
#
# Usage:
#   ./merge-settings.sh <user-settings.json> <pack-settings.json>
#
# Behaviour:
#   - Preserves every non-hook key in the user's settings.json (permissions, env, etc.).
#   - Appends the pack's hook entries (SessionStart, PreToolUse/Read,
#     PostToolUse/Read, PostToolUse/Write|Edit|MultiEdit|NotebookEdit) to existing arrays.
#   - Idempotent: if a pack hook command is already present, it is NOT duplicated.
#   - Writes atomically via a .tmp file so a failure never corrupts the user's settings.
#
# Requires: jq.

set -euo pipefail

USER_FILE="${1:-.claude/settings.json}"
PACK_FILE="${2:-.claude/settings.json.pack}"

if ! command -v jq >/dev/null 2>&1; then
  echo "merge-settings.sh: jq is required." >&2
  exit 1
fi

if [[ ! -f "$USER_FILE" ]]; then
  echo "merge-settings.sh: $USER_FILE not found." >&2
  exit 2
fi

if [[ ! -f "$PACK_FILE" ]]; then
  echo "merge-settings.sh: $PACK_FILE not found." >&2
  exit 2
fi

# Validate both inputs are parseable JSON before touching anything.
jq empty "$USER_FILE" >/dev/null 2>&1 || { echo "merge-settings.sh: $USER_FILE is not valid JSON." >&2; exit 3; }
jq empty "$PACK_FILE" >/dev/null 2>&1 || { echo "merge-settings.sh: $PACK_FILE is not valid JSON." >&2; exit 3; }

# Backup the user's file once (if no backup yet).
BACKUP="${USER_FILE}.bak"
if [[ ! -f "$BACKUP" ]]; then
  cp "$USER_FILE" "$BACKUP"
  echo "merge-settings.sh: backed up original to $BACKUP"
fi

TMP="${USER_FILE}.tmp.$$"

# jq program:
#   For each event (SessionStart, PreToolUse, PostToolUse) in the pack,
#   for each matcher block, append to the user's matching event array.
#   A pack "hooks[].command" that already appears in the user's file is skipped.
jq -s '
  def pack_commands(event):
    (.[1].hooks[event] // []) | map(.hooks[]?.command) | unique;

  def user_commands(event):
    (.[0].hooks[event] // []) | map(.hooks[]?.command) | unique;

  def merge_event(event):
    (.[0].hooks[event] // []) as $user
    | (.[1].hooks[event] // []) as $pack
    | ($user | map(.hooks[]?.command) | map(select(. != null))) as $existing
    | $user + (
        $pack | map(
          .hooks |= map(select(.command as $c | ($existing | index($c)) | not))
        ) | map(select((.hooks // []) | length > 0))
      );

  .[0]
  | .hooks = ((.[0].hooks // {}) | . as $h | $h
      | .SessionStart = (([.[0], .[1]] | merge_event("SessionStart")) // [])
      | .PreToolUse   = (([.[0], .[1]] | merge_event("PreToolUse"))   // [])
      | .PostToolUse  = (([.[0], .[1]] | merge_event("PostToolUse"))  // [])
    )
' "$USER_FILE" "$PACK_FILE" > "$TMP" 2>/dev/null || {
  # The fancy jq above is finicky across versions. Fall back to a simpler,
  # well-tested approach: concatenate hook arrays, then dedupe by .command.
  jq -s '
    def dedupe_hooks:
      . as $arr
      | reduce range(0; length) as $i ([];
          . as $acc
          | ($arr[$i]) as $entry
          | ($entry.hooks // []) as $cmds
          | ($acc | map(.hooks[]?.command) | map(select(. != null))) as $seen
          | $acc + [
              $entry | .hooks = (($cmds | map(select(.command as $c | ($seen | index($c)) | not))))
            ]
          | map(select((.hooks // []) | length > 0))
        );

    .[0] as $u | .[1] as $p
    | $u
    | .hooks = (
        ($u.hooks // {}) as $uh
        | ($p.hooks // {}) as $ph
        | {
            SessionStart: (( ($uh.SessionStart // []) + ($ph.SessionStart // []) ) | dedupe_hooks),
            PreToolUse:   (( ($uh.PreToolUse   // []) + ($ph.PreToolUse   // []) ) | dedupe_hooks),
            PostToolUse:  (( ($uh.PostToolUse  // []) + ($ph.PostToolUse  // []) ) | dedupe_hooks)
          }
          + ($uh | with_entries(select(.key | test("SessionStart|PreToolUse|PostToolUse") | not)))
      )
  ' "$USER_FILE" "$PACK_FILE" > "$TMP"
}

# Sanity check the output before replacing.
if ! jq empty "$TMP" >/dev/null 2>&1; then
  echo "merge-settings.sh: merge produced invalid JSON — aborting. Original untouched." >&2
  rm -f "$TMP"
  exit 4
fi

mv "$TMP" "$USER_FILE"
echo "merge-settings.sh: merged pack hooks into $USER_FILE (backup at $BACKUP)."
