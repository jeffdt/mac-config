---
description: Create a draft pull request for the current branch
allowed-tools: Bash, Read, Edit, Grep, Glob, Agent, AskUserQuestion, SlashCommand:/ticket:find:*, SlashCommand:/pr:simplify:*
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Git status: !`git status`
- PR template: !`cat .github/pull_request_template.md 2>/dev/null || echo "No PR template found"`

## Instructions

Apply the `create-pr` skill using the pre-computed context above.
