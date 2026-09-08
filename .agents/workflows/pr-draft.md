---
name: pr-draft
description: "Create a draft pull request for the current branch"
skill: create-pr
claude_command: pr/draft
claude_allowed_tools: "Skill"
---

## Instructions

Apply the `create-pr` skill. Treat a user-supplied argument as the ticket identifier when one is supplied; otherwise let the underlying workflow detect the ticket.
