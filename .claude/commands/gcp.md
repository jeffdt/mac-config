---
description: Git commit and push changes for current feature
allowed-tools: SlashCommand:/gc:*, Bash(git push:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(gh pr view:*), Bash(gh pr edit:*)
---

## Pre-computed Context

- Existing PR for this branch: !`gh pr view --json number,title,body,state,author 2>&1 || echo "No PR exists"`

## Step 1: Commit changes

Use the SlashCommand tool to invoke /gc to commit changes.

## Step 2: Push and manage PR

Apply the `git-push` skill using the pre-computed context above.
