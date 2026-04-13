# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project purpose

This repo is the **Claude Code Efficiency Pack** — a distributable set of skills and hooks for Claude Code users on rate-limited plans. It is not an application; it produces `.claude/` artifacts that get copied into *other* projects to reduce token waste and survive session interruptions.

## Repository layout

The repo has a dual layout that is easy to misread:

- **Root** — `README.md`, `CLAUDE.md`, `efficiency-pack.tar.gz` (release artifact), and the `efficiency-pack/` directory.
- **`efficiency-pack/efficiency-pack/`** — the **actual distributable**, mirroring the target-project layout a consumer ends up with:
  ```
  efficiency-pack/efficiency-pack/
  ├── CLAUDE.md                         # appended to consumer's CLAUDE.md by installer
  ├── install.sh                        # curl-piped installer
  ├── README.md
  └── .claude/
      ├── settings.json                 # hook registration
      ├── rules/
      │   └── context-guardian.md       # always-on: minimal-read policy
      ├── skills/
      │   ├── task-decomposer.md        # on-demand: plan-before-code
      │   └── checkpoint.md             # on-demand: resume-from-interrupt
      └── hooks/
          ├── context-filter.sh         # PreToolUse/Read: blocks node_modules, locks, build artifacts
          ├── token-meter.sh            # PostToolUse/Read: logs bytes to .claude/metrics.jsonl
          ├── auto-checkpoint.sh        # PostToolUse/Write|Edit: logs to .claude/edit-log.tmp
          └── session-start.sh          # SessionStart: auto-injects existing checkpoint.md
  ```
- **`efficiency-pack.tar.gz`** — packaged release artifact of the above.

Source of truth is `efficiency-pack/efficiency-pack/.claude/...`. No root-level duplicates — they were removed in favour of a single location to avoid drift.

## How the pieces compose

The pack is a pipeline of two skills + one rule + four hooks — each layer enforces the one above it:

1. **task-decomposer** (skill, on-demand) runs at the *start* of any multi-step request. Forces a plan with atomic steps (1-3 files, independently verifiable) and blocks code changes until the user confirms.
2. **context-guardian** (rule, always-on) governs every Read decision. Auto-ignore list (node_modules, build artifacts, lock files, binaries, auto-gen) plus a "state why before loading" requirement for anything outside the minimal set. Mechanically enforced by `context-filter.sh`, which returns `{"decision":"block","reason":"..."}` on stdout for blocked paths. Measured by `token-meter.sh`, which appends `{ts, file, bytes, approx_tokens}` to `.claude/metrics.jsonl` on every Read so users can verify savings.
3. **checkpoint** (skill) runs *after each step*. Overwrites `.claude/checkpoint.md` with completed steps, next step, and decisions made. `auto-checkpoint.sh` feeds it raw edit events from `.claude/edit-log.tmp`; `session-start.sh` auto-injects the checkpoint back into context on next launch via `hookSpecificOutput.additionalContext`.

All four hooks use the real Claude Code hook API: JSON on stdin with `tool_name` and `tool_input.*`, JSON decisions on stdout. `jq` is preferred; each hook has a `grep/sed` fallback so installs without `jq` still work.

## Install mechanics

`install.sh` is meant to be piped from GitHub (`curl … | bash`) in a target project:

- Downloads skills + hooks into `./.claude/`, `chmod +x` on hooks.
- **Preserves existing `.claude/settings.json`** (prints a warning; hooks must be merged by hand).
- **Appends** the pack's `CLAUDE.md` to an existing `CLAUDE.md` instead of overwriting.
- Adds `.claude/checkpoint.md` and `.claude/edit-log.tmp` to `.gitignore`.

The `REPO` URL placeholder (`YOUR_USER`) in `install.sh` is still unfilled — update before publishing.

## Editing conventions specific to this repo

- **Do not rename skills/rules.** Filenames (`task-decomposer.md`, `checkpoint.md`, `context-guardian.md`) are referenced by `@…` loads in the consumer `CLAUDE.md`, by `install.sh` curl targets, and implicitly by the skill `name:` frontmatter. Renaming means editing all three.
- **Hook matchers and skill contracts are coupled.** `auto-checkpoint.sh` matches `Write|Edit|MultiEdit` because `checkpoint.md` promises a checkpoint after every file-producing step. Adding a new edit-like tool requires updating both.
- **Hook API contract.** Hooks read JSON from stdin (`.tool_name`, `.tool_input.file_path`) and emit decisions on stdout (`{"decision":"block","reason":"..."}` for PreToolUse, `{"hookSpecificOutput":{...}}` for SessionStart). Do **not** revert to `$CLAUDE_TOOL_NAME` env vars — those don't exist in Claude Code and silently break the hook.
- **Shell scripts target bash on Linux/macOS/WSL.** Unix paths, `set -u`, `jq`-preferred with `grep/sed` fallback. Do not port to `.cmd`/`.ps1` without also updating `settings.json`.
- **Skill docs are the executable spec.** There is no runtime; Claude reads the markdown and follows it. Prose changes = behavior changes. Keep frontmatter `name`/`description`/`when_to_use` and the numbered procedural sections precise.

## Common commands

There is no build or test system. Typical operations:

```bash
# Re-pack the distributable after editing efficiency-pack/efficiency-pack/
tar -czf efficiency-pack.tar.gz -C efficiency-pack efficiency-pack

# Local install into a sibling project (skip the curl flow)
cp -r efficiency-pack/efficiency-pack/.claude /path/to/target-project/
cat efficiency-pack/efficiency-pack/CLAUDE.md >> /path/to/target-project/CLAUDE.md

# Smoke-test a hook in isolation (stdin JSON, stdout decision)
echo '{"tool_name":"Read","tool_input":{"file_path":"node_modules/foo.js"}}' \
  | bash efficiency-pack/efficiency-pack/.claude/hooks/context-filter.sh
# expect: {"decision":"block","reason":"context-guardian: ..."}

# Aggregate actual token spend for a session
jq -s 'map(.approx_tokens) | add' .claude/metrics.jsonl

# Reset runtime artifacts between benchmark runs
bash efficiency-pack/efficiency-pack/clean.sh --yes        # keeps checkpoint
bash efficiency-pack/efficiency-pack/clean.sh --yes --all  # drops checkpoint too
```
