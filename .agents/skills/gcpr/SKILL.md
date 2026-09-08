---
name: gcpr
version: 1.0.0
description: "Use when the user invokes $gcpr or /gcpr, or asks to commit, push, and create a draft pull request"
---

> Generated from ~/.agents/workflows/gcpr.md. Do not edit this copy directly.
> Edit the workflow source under ~/.agents, then run agents-publish.

# gcpr

Apply the `create-pr` skill for the underlying workflow.

## Instructions

First apply the `git-commit` skill, then the `git-push` skill, and finally the `create-pr` skill. Preserve any ticket identifier supplied by the user and pass it to the pull-request step. Do not ask for the same ticket twice.
