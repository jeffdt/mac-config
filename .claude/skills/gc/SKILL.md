---
name: gc
version: 1.0.0
description: "Use when the user invokes $gc or /gc, or asks to commit the current feature's changes"
---

> Generated from ~/.agents/workflows/gc.md. Do not edit this copy directly.
> Edit the source under ~/.agents, then run agents-publish.

# gc

Apply the `git-commit` skill for the underlying workflow.

## Instructions

Apply the commit workflow. Treat any user-supplied text as a constraint or suggestion for the commit message, not as permission to skip its branch-safety or staging checks.
