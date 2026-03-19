---
description: Git commit changes for current feature
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git add:*), Bash(git commit:*), Bash(git reset:*), Bash(git checkout:*), AskUserQuestion
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Git status: !`git status`
- Unstaged changes: !`git diff --stat`
- Staged changes: !`git diff --staged`
- Recent commits: !`git log -5 --oneline`
- Commit-to-main allowed: !`test -f .claude/local/commit-to-main && echo "YES" || echo "NO"`
- CODEOWNERS file: !`cat .github/CODEOWNERS 2>/dev/null || echo "NONE"`

## Instructions

Apply the `git-commit` skill using the pre-computed context above.
