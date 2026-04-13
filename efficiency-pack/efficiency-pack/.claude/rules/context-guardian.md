# Context Guardian Rule

> This is a **rule**, not a skill — it applies to every file-reading decision Claude makes in this project, not only on explicit invocation. Enforced mechanically by `.claude/hooks/context-filter.sh` and measured by `.claude/hooks/token-meter.sh`.

## Core principle
Read only what is necessary for the current step. Every file loaded into context costs tokens.
Unused context is wasted tokens and increases the chance of confusion.

## Before reading any file, ask yourself:
- Does this file directly affect what I need to change right now?
- Would the task fail without reading it?

If the answer is "no" or "maybe" — do NOT read it.

## Rules

### Always ignore (never read unless explicitly asked):
- `node_modules/`, `.gradle/`, `build/`, `target/`, `dist/`, `.next/`
- `*.lock` files (package-lock.json, yarn.lock, Gemfile.lock, gradle.lock)
- `*.log`, `*.tmp`, `*.cache`
- Binary files, images, fonts
- Auto-generated files (anything with "generated" or "auto-gen" in name/header)
- Test fixtures and mock data files unless the task is about tests

### Load minimally:
- If you need to understand a class — read that class only, not the whole package
- If you need to fix a bug — read the failing file + direct dependencies only
- If you need to add a field — read the model + its migration/schema only

### Before loading a directory:
- List files first (`ls` or `find`) and select only relevant ones
- Never load an entire directory speculatively

## When context is genuinely needed
If you determine that a file outside these rules is necessary, state why before loading:
```
Loading [file] because: <specific reason related to current step>
```

## Why this matters
On a typical Spring Boot / Node.js project, naively loading context can pull in 50-100k tokens
of irrelevant code. This rule keeps per-step context under 10k tokens in most cases.

## How to disable
This rule is intentionally restrictive. If your project genuinely needs broad context loading
(e.g., whole-codebase analysis, documentation generation, architectural review):

1. **Temporary override for one task** — say "disable context-guardian for this task" and
   Claude will ignore the minimal-read rule until the task ends.
2. **Per-file override** — prefix any Read with a stated reason (`Loading X because: …`) to
   bypass the soft rule. The hook still blocks the hard-ignored patterns.
3. **Loosen the block list** — edit `.claude/hooks/context-filter.sh` and remove patterns
   from `BLOCKED_PATTERNS` / `BLOCKED_SUFFIXES`.
4. **Remove entirely** — delete `@.claude/rules/context-guardian.md` from your `CLAUDE.md`
   and remove `.claude/hooks/context-filter.sh` from `.claude/settings.json`. The pack's
   other components (task-decomposer, checkpoint) keep working without this rule.

## Known limitations
- Substring path matching only — a symlink, `../` traversal, or absolute path outside the
  project can bypass the hook. This rule is a **token-economy tool, not a security sandbox**.
- Does not intercept `Grep`, `Glob`, or `Bash(cat ...)` — only `Read`. A determined agent
  can still pull blocked content via other tools.
