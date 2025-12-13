---
description: Review an existing GitHub PR by number (optional - defaults to current branch)
runInPlanMode: false
---

Review a GitHub PR using the pr-review agent.

If a PR number is provided as an argument: review PR #$ARGUMENTS

If no argument is provided:
1. Run `gh pr list --head $(git branch --show-current)` to find PRs for the current branch
2. If exactly one PR is found, review that PR
3. If multiple PRs are found, use AskUserQuestionTool to ask which one to review
4. If no PRs are found, inform the user that no PRs exist for the current branch

Fetch the PR metadata, diff, and any linked Jira ticket, then provide a comprehensive structured review following the agent's review format.
