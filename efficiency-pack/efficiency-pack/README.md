# Claude Code Efficiency Pack

> Do more before hitting rate limits.

A set of skills, rules, and hooks for Claude Code that reduces token waste, prevents context bloat,
survives session interruptions, and **measures its own savings** — designed for Claude Pro ($20/mo) users.

## The problem

Claude Pro has a 5-hour rolling session limit. Large tasks hit it fast because:

- Claude reads files it doesn't need (context bloat).
- Wrong assumptions lead to rework (wasted tokens).
- Interrupted sessions restart from zero (no memory).
- You can't tell what's actually expensive until you're rate-limited.

## The solution

Two skills + one rule + four hooks that work together — and log what they save:

| Component | Kind | What it does |
|---|---|---|
| `task-decomposer` | skill (on-demand) | Forces a plan + confirmation before any multi-step task |
| `checkpoint` | skill (on-demand) | Saves progress after each step; auto-injected on next launch |
| `context-guardian` | rule (always-on) | Blocks reads of irrelevant files (node_modules, locks, etc.) |
| `context-filter.sh` | hook | PreToolUse/Read — mechanically enforces context-guardian |
| `token-meter.sh` | hook | PostToolUse/Read — logs bytes to `.claude/metrics.jsonl` |
| `auto-checkpoint.sh` | hook | PostToolUse/Write\|Edit — logs changed files for checkpoint |
| `session-start.sh` | hook | SessionStart — auto-injects unfinished checkpoint |

## Install

```bash
cp -r efficiency-pack/.claude ./
cat efficiency-pack/CLAUDE.md >> CLAUDE.md
printf '.claude/checkpoint.md\n.claude/edit-log.tmp\n.claude/metrics.jsonl\n' >> .gitignore
```

The scripted installer (`install.sh`) does the same plus `chmod +x` on hooks.
Edit the `REPO` variable in `install.sh` before using the `curl | bash` form.

## Usage

Use Claude Code normally. The pack activates automatically.

**Key commands you can say:**
- `"skip planning"` — bypass task-decomposer for a one-shot task
- `"resume from checkpoint"` — continue an interrupted session
- `"show checkpoint"` — see current progress
- `"reset checkpoint"` — start fresh

## Measuring savings (not marketing)

The pack makes no magic claims. It measures what you actually read.

```bash
./bench.sh reset      # wipe metrics
# ...work with Claude...
./bench.sh            # total reads, unique files, bytes, approx tokens
./bench.sh top 10     # 10 largest files pulled into context
```

Run the same task twice — once with the pack disabled, once enabled — and
compare `approx_tokens`. That's your real number.

## Cleaning up between runs

```bash
./clean.sh            # interactive: drop edit-log + metrics
./clean.sh --dry-run  # preview only
./clean.sh --yes      # non-interactive
./clean.sh --yes --all  # also drop .claude/checkpoint.md
```

`clean.sh` only touches runtime artifacts inside `.claude/` (edit-log,
metrics, optionally checkpoint). It never touches `settings.json`, the
`skills/`, `rules/`, or `hooks/` directories, or anything outside `.claude/`.

## What the pack guarantees

- ✅ Every Read matching a blocked pattern is rejected by the hook, not just by soft prompt.
- ✅ Every successful Read is logged with byte count — savings are auditable.
- ✅ Every Write/Edit is logged; checkpoints include the actual file list.
- ✅ On session start, an unfinished checkpoint appears in context without you typing anything.

## What it doesn't do

- Does not report Anthropic billing tokens (use their dashboard).
- Does not shrink responses — that's the model's job.
- Does not replace `/compact`, memory, or MCP. It stacks with them.

## Structure

```
your-project/
├── .claude/
│   ├── settings.json                 ← hook registration
│   ├── rules/
│   │   └── context-guardian.md       ← always-on: minimal-read rule
│   ├── skills/
│   │   ├── task-decomposer.md        ← on-demand: plan-before-code
│   │   └── checkpoint.md             ← on-demand: resume-from-interrupt
│   └── hooks/
│       ├── context-filter.sh         ← PreToolUse/Read    — block
│       ├── token-meter.sh            ← PostToolUse/Read   — measure
│       ├── auto-checkpoint.sh        ← PostToolUse/Write+ — log
│       └── session-start.sh          ← SessionStart       — restore
├── CLAUDE.md                         ← loads rules + skills
├── bench.sh                          ← aggregate metrics
└── clean.sh                          ← remove runtime artifacts
```

## License

MIT
