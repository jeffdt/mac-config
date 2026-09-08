---
name: gcp
version: 1.0.0
description: "Use when the user invokes $gcp or /gcp, or asks to commit and push the current feature's changes"
---

> Generated from ~/.agents/workflows/gcp.md. Do not edit this copy directly.
> Edit the workflow source under ~/.agents, then run agents-publish.

# gcp

Apply the `git-push` skill for the underlying workflow.

## Instructions

First apply the `git-commit` skill. After a successful commit, apply the `git-push` skill. Do not push when the commit workflow cannot safely complete.
