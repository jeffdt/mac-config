---
description: Fix all PR issues — CI failures and review feedback — in a single pass
allowed-tools: SlashCommand:/pr:doctor:*, SlashCommand:/pr:feedback:*, Bash(git rev-parse:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*), Bash(git push:*), Bash(git diff:*), Bash(gh pr view:*), Bash(gh pr edit:*), AskUserQuestion
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,url,title,body,state,author 2>&1 || echo "NO_PR_FOUND"`
- HEAD before treatment: !`git rev-parse HEAD`

## Instructions

### Step 1: Intake — Resolve the PR

Check the pre-computed PR info above.

- If it contains `NO_PR_FOUND` or the current branch is `main`/`master`: use AskUserQuestion to ask for a PR number or URL. Then fetch its info with `gh pr view <number> --json number,url,title,body,state,author`.
- If PR info is present: proceed with it.

Note the pre-computed HEAD hash — you will compare against it in the discharge step.

### Step 2: Doctor — Fix CI Failures

Use the SlashCommand tool to invoke `/pr:doctor`.

Doctor will run its full workflow: check CI → fetch logs → categorize → present diagnosis → implement fixes. If CI is already green, doctor reports "nothing to fix" and returns quickly.

If doctor fails or stops early (e.g., Docker won't start, Buildkite MCP unreachable, VPN down), note the failure reason and proceed to Step 3.

### Step 3: Feedback — Address Review Comments

Use the SlashCommand tool to invoke `/pr:feedback`.

Feedback will run its full workflow: triage → present results → approval gate → implement → QA → tickets. If there are no review comments, triage reports nothing actionable and returns quickly.

### Step 4: Discharge — Push and Summarize

Compare current HEAD (`git rev-parse HEAD`) against the pre-computed HEAD hash from intake.

**If HEAD moved** (changes were made): Apply the `git-push` skill using the pre-computed context above.

**If HEAD unchanged:** Skip push.

Then print the discharge summary, synthesized from doctor's and feedback's summaries in the conversation above:

```
## Discharge Summary

**PR:** #<number> — <title>

### Doctor (CI)
- <what was fixed, ephemeral jobs to restart, items skipped>
- or: "CI was already green — skipped"
- or: "Doctor failed: <reason>. Run /pr:doctor separately to retry."

### Feedback (Review Comments)
- <what was fixed, deferred (with ticket links), dismissed>
- or: "No actionable review comments — skipped"

### Next Steps
- <Changes pushed to <branch> / No changes needed>
- <Manual actions if any: restart ephemeral jobs, etc.>
```
