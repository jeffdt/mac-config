---
name: pr-review
description: "Review an existing GitHub PR by number, URL, or current branch"
skill: reviewing-prs
claude_command: pr/review
claude_allowed_tools: "Skill, Bash, Read, Grep, Glob, Task, AskUserQuestion, mcp__plugin_linear_linear__*, mcp__plugin_github_github__pull_request_read"
---

## Instructions

Apply the `reviewing-prs` skill in this main conversation. Treat a user-supplied argument as the PR number or URL. If no argument is supplied, resolve the PR from the current branch as directed by the skill.

Do not launch a `pr-review` agent. The main conversation must directly launch any specialized reviewer Tasks so the task hierarchy never exceeds two layers.
