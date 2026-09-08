---
name: pr-draft
version: 1.0.0
description: "Use when the user invokes $pr-draft or /pr-draft, or asks to create a draft pull request for the current branch"
---

> Generated from ~/.agents/workflows/pr-draft.md. Do not edit this copy directly.
> Edit the workflow source under ~/.agents, then run agents-publish.

# pr-draft

Apply the `create-pr` skill for the underlying workflow.

## Instructions

Apply the `create-pr` skill. Treat a user-supplied argument as the ticket identifier when one is supplied; otherwise let the underlying workflow detect the ticket.
