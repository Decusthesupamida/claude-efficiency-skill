---
name: checkpoint
description: Persist session progress to .claude/checkpoint.md after each atomic step so interrupted sessions can be resumed in ~200 tokens. Also triggers on session start when a checkpoint exists, and on explicit commands ("resume from checkpoint", "show checkpoint", "reset checkpoint").
when_to_use: After every completed step in a task-decomposer plan; on session start if checkpoint exists; on explicit resume/show/reset commands.
---

# Checkpoint Skill

## Purpose
Sessions get interrupted — by rate limits, by the user closing the terminal, by errors.
This skill ensures that any interrupted session can be resumed in under 30 seconds
without re-explaining the entire task from scratch.

## After completing each step, write a checkpoint

Save to `.claude/checkpoint.md` (create if missing, overwrite on each step):

```markdown
# Checkpoint — <timestamp>

## Original goal
<one sentence from task-decomposer>

## Status
Step <N> of <total> complete.

## Completed steps
- [x] Step 1 — <what was done> — files: <list>
- [x] Step 2 — <what was done> — files: <list>

## Next step
Step <N+1>: <exact description from the original plan>
Files expected to change: <list>

## Known issues / decisions made
- <any non-obvious decision you made during execution>
- <any workaround or compromise>

## How to resume
Say: "resume from checkpoint" and I will continue from Step <N+1>.
```

## On session start — check for existing checkpoint

If `.claude/checkpoint.md` exists:
1. Read it immediately
2. Inform the user:
   ```
   Found checkpoint: Step <N>/<total> complete for "<goal>".
   Next step: <description>.
   Resume? (yes / show full plan / cancel)
   ```
3. Wait for confirmation before doing anything.

## Checkpoint hygiene
- Delete `.claude/checkpoint.md` when the task is fully complete
- Never accumulate multiple checkpoints — always overwrite
- Add `.claude/checkpoint.md` to `.gitignore` if not already there

## Why this matters
Without a checkpoint, a interrupted 10-step task forces the user to re-explain everything
in a new session — wasting 2-5k tokens just to restore context. With a checkpoint,
resuming costs ~200 tokens.
