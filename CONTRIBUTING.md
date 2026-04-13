# Contributing

Guidance for working on the Efficiency Pack itself (as opposed to using it in another project).

## Project purpose

This repo **is** the Claude Code Efficiency Pack — a distributable set of skills, rules, and hooks
for Claude Code users on rate-limited plans. The repo is also the distributable: users `curl | bash`
`install.sh` directly from `main`, or `git clone` and copy `.claude/` into their project.

## Repository layout

```
claude-efficiency-skill/
├── README.md             # user-facing overview + install + how to measure savings
├── CLAUDE.md             # consumer-facing CLAUDE.md fragment (loaded by Claude Code)
├── CONTRIBUTING.md       # this file — dev guidance
├── LICENSE               # MIT
├── install.sh            # curl-piped installer for target projects
├── merge-settings.sh     # jq-based settings.json merger (called by install.sh)
├── bench.sh              # aggregate .claude/metrics.jsonl into readable stats
├── clean.sh              # remove runtime artifacts between benchmark runs
└── .claude/
    ├── settings.json     # hook registration (4 hooks)
    ├── rules/
    │   └── context-guardian.md   # always-on: minimal-read policy
    ├── skills/
    │   ├── task-decomposer.md    # on-demand: plan-before-code
    │   └── checkpoint.md         # on-demand: resume-from-interrupt
    └── hooks/
        ├── context-filter.sh     # PreToolUse/Read:    block node_modules, locks, build artifacts
        ├── token-meter.sh        # PostToolUse/Read:   log bytes to .claude/metrics.jsonl
        ├── auto-checkpoint.sh    # PostToolUse/Edit+:  log changed files to .claude/edit-log.tmp
        └── session-start.sh      # SessionStart:       inject .claude/checkpoint.md if present
```

No nested distributable directory. The repo root **is** the pack.

## How the pieces compose

A pipeline of two skills + one rule + four hooks — each layer enforces the one above it:

1. **task-decomposer** (skill, on-demand) runs at the start of any multi-step request. Forces a plan
   with atomic steps (1–3 files, independently verifiable) and blocks code changes until the user
   confirms.
2. **context-guardian** (rule, always-on) governs every Read decision. Auto-ignore list plus a
   "state why before loading" requirement for anything outside the minimal set. Mechanically
   enforced by `context-filter.sh` (stdout `{"decision":"block","reason":"..."}` for blocked paths).
   Measured by `token-meter.sh` appending `{ts, file, bytes, approx_tokens}` to
   `.claude/metrics.jsonl` on every Read.
3. **checkpoint** (skill) runs after each step. Overwrites `.claude/checkpoint.md` with completed
   steps, next step, and decisions made. `auto-checkpoint.sh` feeds it raw edit events from
   `.claude/edit-log.tmp`; `session-start.sh` auto-injects the checkpoint back into context on next
   launch via `hookSpecificOutput.additionalContext`.

All four hooks use the Claude Code hook API: JSON on stdin with `tool_name` and `tool_input.*`,
JSON decisions on stdout. `jq` is preferred; each hook has a `grep/sed` fallback so installs
without `jq` still work (with a few caveats — see README).

## Coupling hazards — renaming ≠ free

- **Skill / rule filenames** are referenced by `@…` loads in `CLAUDE.md`, by `install.sh` curl
  targets, and by frontmatter `name:` fields. Renaming one requires editing all three.
- **Hook matchers and skill contracts are coupled.** `auto-checkpoint.sh` matches
  `Write|Edit|MultiEdit|NotebookEdit` because `checkpoint.md` promises a checkpoint after every
  file-producing step. Adding a new edit-like tool requires updating both.
- **Hook API contract is non-negotiable.** Hooks read JSON from stdin (`.tool_name`,
  `.tool_input.file_path`) and emit decisions on stdout. Do **not** revert to
  `$CLAUDE_TOOL_NAME` env vars — those don't exist in Claude Code and silently break the hook.
- **Shell scripts target bash on Linux/macOS/WSL.** Unix paths, `set -u`, `jq`-preferred with
  `grep/sed` fallback. Do not port to `.cmd` / `.ps1` without also updating `settings.json`.
- **Skill docs are the executable spec.** There is no runtime; Claude reads the markdown and
  follows it. Prose changes = behaviour changes. Keep numbered procedural sections precise.

## Common dev commands

```bash
# Syntax-check every shell script (CI parity)
for f in *.sh .claude/hooks/*.sh; do bash -n "$f" && echo "✓ $f"; done

# Smoke-test context-filter.sh (stdin JSON, stdout decision)
echo '{"tool_name":"Read","tool_input":{"file_path":"node_modules/foo.js"}}' \
  | bash .claude/hooks/context-filter.sh
# expect: {"decision":"block","reason":"context-guardian: ..."}

# Smoke-test auto-checkpoint.sh
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.ts"}}' \
  | bash .claude/hooks/auto-checkpoint.sh
cat .claude/edit-log.tmp  # expect: one line with ts | Edit | src/foo.ts

# Aggregate real token spend for a benchmark run
jq -s 'map(.approx_tokens) | add' .claude/metrics.jsonl
./bench.sh summary

# Reset runtime artifacts between benchmark runs
./clean.sh --yes         # keeps checkpoint.md
./clean.sh --yes --all   # also drops checkpoint.md
```

## Release tarball

The repo root **is** the tarball source. To produce a release artifact (e.g. for a GitHub Release):

```bash
# Tar the working tree excluding git and runtime junk
tar --exclude='.git' --exclude='.idea' --exclude='.claude/checkpoint.md' \
    --exclude='.claude/edit-log.tmp' --exclude='.claude/metrics.jsonl' \
    --exclude='.claude/metrics.jsonl.bak' --exclude='.claude/settings.local.json' \
    -czf claude-efficiency-skill.tar.gz \
    --transform 's,^,claude-efficiency-skill/,' \
    README.md CLAUDE.md LICENSE install.sh merge-settings.sh bench.sh clean.sh .claude
```

## PR checklist

Before opening a PR:

- [ ] All `.sh` scripts pass `bash -n` (syntax check).
- [ ] All hooks still emit valid JSON on stdout (smoke-tested with sample JSON stdin).
- [ ] `install.sh` still has `set -euo pipefail` and respects `FORCE=1` for overwrites.
- [ ] Any renamed file has its references updated in: `CLAUDE.md` (@-loads), `install.sh` (curl
      paths), `settings.json` (if a hook).
- [ ] Shell scripts committed with executable bit — check `git ls-files --stage | grep '\.sh$'`
      shows `100755`.
- [ ] No absolute paths (`C:\Users\`, `/home/`, etc.) and no secrets leaked into tracked files.
- [ ] README table still matches reality if components were added/removed/renamed.
