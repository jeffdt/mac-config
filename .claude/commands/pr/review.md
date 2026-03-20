---
description: Review an existing GitHub PR by number (optional - defaults to current branch)
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr list:*), Bash(gh pr checks:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), mcp__plugin_linear_linear__*, Read, Grep, Glob, Task, AskUserQuestion
runInPlanMode: false
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,url,title,body,state,author 2>&1 || echo "NO_PR_FOUND"`

## Instructions

Review a GitHub PR using the pr-review orchestrator agent.

**Resolve PR number:**

If a PR number is provided as an argument: use PR #$ARGUMENTS

If no argument is provided:
1. Run `gh pr list --head $(git branch --show-current)` to find PRs for the current branch
2. If exactly one PR is found, use that PR
3. If multiple PRs are found, use AskUserQuestion to ask which one to review
4. If no PRs are found, inform the user that no PRs exist for the current branch

**Launch the orchestrator:**

Once you have the PR number, launch the `pr-review` agent via the Task tool with `subagent_type: "pr-review"`. Pass the PR number and any pre-computed context in the prompt so the orchestrator has everything it needs to begin fetching data and routing the review.
