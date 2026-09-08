---
name: gcpr
description: "Commit, push, and create a draft pull request"
skill: create-pr
claude_command: gcpr
claude_allowed_tools: "Skill"
---

## Instructions

First apply the `git-commit` skill, then the `git-push` skill, and finally the `create-pr` skill. Preserve any ticket identifier supplied by the user and pass it to the pull-request step. Do not ask for the same ticket twice.
