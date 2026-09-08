---
description: "Commit, push, and create a draft pull request"
allowed-tools: Skill
---

<!-- Generated from ~/.agents/workflows/gcpr.md. Do not edit this copy directly. -->

Apply the `create-pr` skill for the underlying workflow.

## Instructions

First apply the `git-commit` skill, then the `git-push` skill, and finally the `create-pr` skill. Preserve any ticket identifier supplied by the user and pass it to the pull-request step. Do not ask for the same ticket twice.
