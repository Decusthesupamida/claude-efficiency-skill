---
name: task-decomposer
description: Force a plan-and-confirm step before any multi-file or multi-step change. Invoke whenever the user requests a task that touches more than one file, takes more than a few minutes, or has multiple phases. Skip only if the user says "skip planning".
when_to_use: Multi-step coding tasks, refactors, feature additions, migrations, anything non-trivial.
---

# Task Decomposer Skill

## When to activate
Activate this skill when the user provides any non-trivial task — anything that requires
changing more than one file, involves multiple steps, or could take more than a few minutes.

## What to do BEFORE writing any code

1. **Restate the goal** in one sentence to confirm understanding.
2. **List all affected files** you expect to touch. If unsure, say so explicitly.
3. **Break the task into atomic steps** — each step must:
   - Change no more than 1-3 files
   - Be independently verifiable (has a clear "done" condition)
   - Take no more than ~5 minutes of execution
4. **Present the plan** in this format and WAIT for user confirmation:

```
Goal: <one sentence>

Steps:
1. [file.ext] — what changes and why → verify: <how to check it's done>
2. [file.ext] — what changes and why → verify: <how to check it's done>
...

Estimated steps: N
Start? (yes / adjust step X / cancel)
```

5. **Do not write a single line of code** until the user confirms.

## During execution

- Execute ONE step at a time.
- After each step, print a compact summary:
  ```
  ✓ Step 1/N done — <what was done> — next: <step 2 description>
  ```
- If you encounter something unexpected mid-step, STOP and report it before continuing.
- Never silently skip or merge steps.

## Why this matters
Large tasks in a single session consume 3-5x more tokens due to context bloat and rework
from wrong assumptions. Atomic steps keep each session small, focused, and recoverable.
