# Claude Code Efficiency Pack

This project uses the **Efficiency Pack** — skills, rules, and hooks designed to
maximize output per session, reduce token waste, and survive rate-limit interruptions.

---

## Active rules (always loaded)

@.claude/rules/context-guardian.md

## Active skills (loaded on demand)

@.claude/skills/task-decomposer.md
@.claude/skills/checkpoint.md

## Active hooks (enforced by the harness)

- **PreToolUse / Read** → `context-filter.sh` blocks reads of `node_modules/`, lock files, build artifacts, minified bundles.
- **PostToolUse / Read** → `token-meter.sh` logs every read to `.claude/metrics.jsonl` (real bytes, approx tokens).
- **PostToolUse / Write|Edit|MultiEdit|NotebookEdit** → `auto-checkpoint.sh` appends changed files to `.claude/edit-log.tmp`.
- **SessionStart** → `session-start.sh` injects `.claude/checkpoint.md` into context if it exists.

---

## Quick reference

| Situation | What Claude will do |
|---|---|
| You give a multi-step task | Propose a plan, wait for your confirmation |
| You confirm the plan | Execute one step at a time, checkpoint after each |
| Session is interrupted | `SessionStart` hook auto-injects the checkpoint next launch |
| You say "resume from checkpoint" | Pick up from the exact next step |
| Claude tries to read `node_modules/` | Hook blocks it; Claude is told why |

## Tips

- Say **"skip planning"** to bypass task-decomposer for a one-shot task.
- Say **"show checkpoint"** or **"reset checkpoint"** anytime.
- Say **"disable context-guardian for this task"** to loosen the minimal-read rule temporarily.
- Inspect real token cost: `./bench.sh` or `jq -s 'map(.approx_tokens)|add' .claude/metrics.jsonl`.
- Add project-specific ignore patterns to `.claude/hooks/context-filter.sh`.

---

*Efficiency Pack — made for Claude Pro users who want to do more before hitting rate limits.*
*Contributing to this repo? See [CONTRIBUTING.md](CONTRIBUTING.md).*
