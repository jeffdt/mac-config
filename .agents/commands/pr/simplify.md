---
description: Quality pass on all branch changes before marking PR as ready
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git rev-parse:*), Read, Grep, Glob, Edit, Agent
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Base branch: !`git rev-parse --verify main 2>/dev/null && echo main || echo master`
- Branch commits: !`git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null || echo "NO_BRANCH_COMMITS"`
- Branch diff: !`git diff main...HEAD 2>/dev/null || git diff master...HEAD 2>/dev/null || echo "NO_DIFF"`
- Review context: !`cat .claude/code-review-context.md 2>/dev/null || echo "NO_REPO_CONTEXT"`

## Instructions

### Validate Branch State

- If the current branch is `main` or `master`: inform the user "You're on the main branch — switch to a feature branch first." and stop.
- If branch commits shows `NO_BRANCH_COMMITS`: inform the user "No changes found on this branch relative to main." and stop.

### Run Simplify

Apply the `simplify` skill. For Phase 1 (identifying changes), use `git diff <base-branch>...HEAD` instead of `git diff` — the scope is everything on this branch relative to main/master, not just uncommitted changes.

The full branch diff and any repo-specific review context (from `.claude/code-review-context.md`) are provided in the pre-computed context above. Prefer working from these over re-fetching. When searching for reuse opportunities, grep for specific identifiers from the diff rather than broadly exploring directories.
