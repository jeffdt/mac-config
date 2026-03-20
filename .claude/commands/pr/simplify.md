---
description: Quality pass on all branch changes before marking PR as ready
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git rev-parse:*), Read, Grep, Glob, Edit, Agent
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Base branch: !`git rev-parse --verify main 2>/dev/null && echo main || echo master`
- Branch commits: !`git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null || echo "NO_BRANCH_COMMITS"`

## Instructions

### Validate Branch State

- If the current branch is `main` or `master`: inform the user "You're on the main branch — switch to a feature branch first." and stop.
- If branch commits shows `NO_BRANCH_COMMITS`: inform the user "No changes found on this branch relative to main." and stop.

### Run Simplify

Apply the `simplify` skill. For Phase 1 (identifying changes), use `git diff <base-branch>...HEAD` instead of `git diff` — the scope is everything on this branch relative to main/master, not just uncommitted changes.
