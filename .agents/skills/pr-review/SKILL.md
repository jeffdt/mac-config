---
name: pr-review
version: 1.0.0
description: "Use when the user invokes $pr-review or /pr-review, or asks to review an existing GitHub PR by number, URL, or current branch"
---

> Generated from ~/.agents/workflows/pr-review.md. Do not edit this copy directly.
> Edit the workflow source under ~/.agents, then run agents-publish.

# pr-review

Apply the `reviewing-prs` skill for the underlying workflow.

## Instructions

Apply the `reviewing-prs` skill in this main conversation. Treat a user-supplied argument as the PR number or URL. If no argument is supplied, resolve the PR from the current branch as directed by the skill.

Do not launch a `pr-review` agent. The main conversation must directly launch any specialized reviewer Tasks so the task hierarchy never exceeds two layers.
