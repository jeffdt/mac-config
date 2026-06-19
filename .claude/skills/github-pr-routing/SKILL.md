---
name: github-pr-routing
description: This skill should be used when performing any GitHub PR operation in the main conversation — creating, reading, updating, reviewing, or commenting on pull requests. Routes operations to gh CLI (when a native subcommand exists) or GitHub MCP (when it doesn't). Also use when tempted to reach for gh api, which is hard-denied in permissions.
---

# GitHub PR Tool Routing

**Rule: Use `gh` CLI when a native subcommand exists. Use GitHub MCP when it doesn't. Never use `gh api`.**

`gh api` is hard-denied in `settings.json` — it will be blocked even if you try.

## gh CLI — use when native subcommand exists

| Operation | Command |
|-----------|---------|
| Create PR | `gh pr create --draft` |
| Edit PR title/body | `gh pr edit <number>` |
| View PR details | `gh pr view <number>` |
| List PRs | `gh pr list` |
| PR diff | `gh pr diff <number>` |
| CI checks | `gh pr checks <number>` |
| Checkout PR branch | `gh pr checkout <number>` |
| Merge PR | `gh pr merge <number>` |
| Mark ready for review | `gh pr ready <number>` |
| Post a comment | `gh pr comment <number>` |
| Submit a review | `gh pr review <number>` |
| Check PR status | `gh pr status` |

`gh pr view --json` can access some review data, but for threaded comments with resolution/outdated status, use MCP.

## GitHub MCP — use when gh has no native subcommand

| Operation | MCP Tool | Method/Notes |
|-----------|----------|-------------|
| Threaded review comments with resolution status | `pull_request_read` | `method: "get_review_comments"` |
| Review submissions list | `pull_request_read` | `method: "get_reviews"` |
| Reply to a review comment | `add_reply_to_pull_request_comment` | No gh subcommand for threaded replies |
| Pending review management | `pull_request_review_write` | Create/submit/delete pending reviews |
| Add inline comment to pending review | `add_comment_to_pending_review` | Line-level review comments |

MCP tool names are shorthand — full prefix is `mcp__plugin_github_github__`.

MCP tools require `owner` and `repo` parameters. Derive once from `gh repo view --json owner,name` and reuse from conversation context.

## Scope

Main conversation only. Subagents (pr-review, pr-feedback-triage, pr-feedback-qa) have their own routing and should not be changed.
