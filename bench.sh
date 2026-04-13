#!/bin/bash
# bench.sh — Measure real context consumption recorded by token-meter.sh.
#
# Usage:
#   ./bench.sh                    # summary of current .claude/metrics.jsonl
#   ./bench.sh reset              # wipe metrics (start a fresh run)
#   ./bench.sh top 10             # show 10 largest reads by bytes
#
# Numbers reported:
#   - total_bytes  : sum of all file bytes Claude pulled into context via Read
#   - approx_tokens: total_bytes / 4 (Anthropic's rough heuristic)
#   - reads        : number of Read calls observed
#   - unique_files : distinct file paths read
#
# Token estimate is an order-of-magnitude figure, not a replacement for
# Anthropic's billing. Use it for before/after comparison on the same task.

set -u

METRICS=".claude/metrics.jsonl"

if ! command -v jq >/dev/null 2>&1; then
  echo "bench.sh: jq is required. Install with your package manager." >&2
  exit 1
fi

case "${1:-summary}" in
  reset)
    rm -f "$METRICS"
    echo "reset: $METRICS removed"
    ;;
  top)
    N="${2:-10}"
    if [[ ! "$N" =~ ^[0-9]+$ ]]; then
      echo "bench.sh: 'top' argument must be a positive integer, got: $N" >&2
      exit 2
    fi
    [[ ! -f "$METRICS" ]] && { echo "no metrics yet"; exit 0; }
    jq -c '{file, bytes, approx_tokens}' "$METRICS" \
      | jq -s --argjson n "$N" 'sort_by(-.bytes) | .[0:$n]'
    ;;
  summary|*)
    [[ ! -f "$METRICS" ]] && { echo "no metrics yet — run Claude with this pack installed"; exit 0; }
    jq -s '{
      reads:         length,
      unique_files: (map(.file) | unique | length),
      total_bytes:  (map(.bytes) | add),
      approx_tokens:(map(.approx_tokens) | add)
    }' "$METRICS"
    ;;
esac
