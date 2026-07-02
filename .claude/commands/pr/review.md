---
description: Review an existing GitHub PR by number (optional - defaults to current branch)
allowed-tools: Bash, mcp__plugin_linear_linear__*, Read, Grep, Glob, Task, AskUserQuestion
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

When the orchestrator returns, present its synthesized report to the user verbatim, then proceed to the smoke test offer below.

## Smoke Test Offer

After the review report has been presented, offer the user the chance to smoke test the changes.

Use AskUserQuestion:
- Question: "Want to smoke test the changes?"
- Header: "Smoke test"
- Options:
  - **Yes, smoke test** (description: "Evaluate the PR's test plan and run a smoke test against the changes")
  - **Skip** (description: "Skip smoke testing; the review is complete")

If the user picks **Skip**, the review is complete. Stop here.

If the user picks **Yes**, run the smoke test flow below.

### Step 1 - Evaluate the PR's stated test plan

Re-read the PR description for any test plan section. Output a brief assessment:
- **Coverage:** Which behaviors the stated plan exercises.
- **Gaps:** Use cases, edge cases, or regressions the plan misses.
- **Misleading or stale steps:** Anything stale or would pass despite a broken change.

If the PR has no test plan, say so and proceed to build one from scratch.

### Step 2 - Build a smoke test plan

Synthesize a focused plan covering the golden path plus gaps from Step 1. For each step, state:
- What to do
- What to expect
- Why it matters

Present the plan, then use AskUserQuestion:
- Question: "Run this smoke test plan?"
- Header: "Run plan"
- Options:
  - **Run it** (description: "Execute the smoke test plan as written")
  - **Adjust the plan** (description: "Edit steps before running")
  - **Cancel** (description: "Skip smoke testing; the review is complete")
- Free-text hint: "Describe edits to the plan"

If **Adjust**, incorporate edits and re-confirm before running. If **Cancel**, stop.

### Step 3 - Execute the plan

Walk through the steps with the user. Run automatable steps directly. For manual steps, prompt the user and capture their reported result. After each step, record pass/fail and unexpected output.

### Step 4 - Summarize smoke test results

Output:
- Steps run, passed, failed
- Any failures with observed vs. expected behavior
- New issues tied back to review findings where relevant

If failures surfaced new issues, note whether they change the review verdict. The user decides.
