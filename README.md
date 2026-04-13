# Claude Code Efficiency Pack

> Do more before hitting rate limits.

A set of skills, rules, and hooks for Claude Code that reduces token waste, prevents
context bloat, survives session interruptions, and **measures its own savings** —
designed for Claude Pro ($20/mo) users.

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

**Option A — one-liner (requires `curl`, `bash`, recommended `jq`):**

```bash
curl -fsSL https://raw.githubusercontent.com/Decusthesupamida/claude-efficiency-skill/main/install.sh | bash
```

**Option B — manual:**

```bash
git clone https://github.com/Decusthesupamida/claude-efficiency-skill.git .pack-tmp
cp -r .pack-tmp/.claude ./
cp .pack-tmp/{install.sh,merge-settings.sh,bench.sh,clean.sh} ./
cat .pack-tmp/CLAUDE.md >> CLAUDE.md
rm -rf .pack-tmp
```

Then add runtime artifacts to `.gitignore`:

```
.claude/checkpoint.md
.claude/edit-log.tmp
.claude/metrics.jsonl
.claude/metrics.jsonl.bak
.claude/settings.local.json
```

## Usage

Use Claude Code normally. The pack activates automatically.

**Key commands you can say:**
- `"skip planning"` — bypass task-decomposer for a one-shot task
- `"resume from checkpoint"` — continue an interrupted session
- `"show checkpoint"` — see current progress
- `"reset checkpoint"` — start fresh
- `"disable context-guardian for this task"` — temporarily loosen the minimal-read rule

## Measuring savings (not marketing)

The pack makes no magic claims. It measures what you actually read.

```bash
./bench.sh reset      # wipe metrics
# ...work with Claude...
./bench.sh            # total reads, unique files, bytes, approx tokens
./bench.sh top 10     # 10 largest files pulled into context
```

Run the same task twice — once with the pack disabled, once enabled — and compare
`approx_tokens`. That's your real number.

## Coexistence with other skills / hooks

- **If you already have `settings.json`** — `install.sh` calls `merge-settings.sh` which
  uses `jq` to splice in the four hooks without overwriting your existing config. A backup
  is written to `settings.json.bak`.
- **If you already have a skill named `checkpoint` or `task-decomposer`** — the installer
  refuses to overwrite and prints a warning. Rename one of them, then re-run with `FORCE=1`.
- **If you already have a `CLAUDE.md`** — the pack's fragment is appended between
  `<!-- efficiency-pack:begin -->` / `<!-- efficiency-pack:end -->` markers so you can
  find and remove it later.
- **To disable `context-guardian`** — see the "How to disable" section in
  `.claude/rules/context-guardian.md`. The other components keep working without it.

## Repo layout

The repo **is** the distributable. No nested wrapper directory.

```
claude-efficiency-skill/
├── README.md              ← you are here
├── CLAUDE.md              ← consumer-facing fragment, loaded by Claude Code
├── CONTRIBUTING.md        ← dev guidance for editing the pack itself
├── LICENSE                ← MIT
├── install.sh             ← one-shot installer
├── merge-settings.sh      ← jq-based settings.json merger
├── bench.sh               ← aggregate metrics
├── clean.sh               ← remove runtime artifacts
└── .claude/
    ├── settings.json
    ├── rules/context-guardian.md
    ├── skills/{task-decomposer,checkpoint}.md
    └── hooks/{context-filter,token-meter,auto-checkpoint,session-start}.sh
```

## Dependencies

- `bash` 4+ (macOS ships 3.x — install via brew or use zsh with the `-c` invocation).
- `curl` for the one-liner install.
- `jq` — **recommended**. Without it:
  - Hooks fall back to `grep/sed` parsing (works, slightly less robust).
  - `bench.sh` does not work (no graceful fallback for aggregation).
  - `merge-settings.sh` refuses to run (cannot risk mangling user settings).

## What this pack doesn't do

- Does not report Anthropic billing tokens (use their dashboard).
- Does not shrink responses — that's the model's job.
- Does not replace `/compact`, memory, or MCP servers. It stacks with them.
- Is not a security sandbox. `context-guardian` is a token-economy tool; see its
  "Known limitations" section.

## Contributing

Issues and PRs welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the architectural
ground rules — especially how hook filenames, `install.sh` paths, and skill frontmatter
are coupled. Renaming one thing usually means editing three.

## License

[MIT](LICENSE) — © 2026 Pranko Pavel.
