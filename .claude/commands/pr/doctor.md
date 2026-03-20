---
description: Diagnose and fix CI build/test failures on the current PR
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git add:*), Bash(git commit:*), Bash(git checkout:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh api:*), Bash(gh repo view:*), Bash(docker info:*), Bash(open -a Docker), Read, Grep, Glob, mcp__buildkite__*, AskUserQuestion, Task
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,url,title,body,state 2>&1 || echo "NO_PR_FOUND"`
- GitHub checks: !`gh pr checks 2>&1 || echo "NO_CHECKS_FOUND"`

## Instructions

### Step 1: Resolve the PR

Check the pre-computed PR info above.

- If it contains `NO_PR_FOUND` or the current branch is `main`/`master`: use AskUserQuestion to ask for a PR number or URL. Then fetch its info with `gh pr view <number> --json number,url,title,body,state` and checks with `gh pr checks <number>`.
- If PR info is present: proceed with it.

### Step 2: Check for Failures

Review the GitHub checks output.

- If all checks passed: inform the user "All CI checks are passing — nothing to fix." and stop.
- If there are failures: proceed to diagnosis.

### Step 3: Verify Buildkite MCP Access

**CRITICAL: Use `mcp__buildkite__*` tools for ALL Buildkite data. Do NOT use the `bk` CLI, `curl`, or any other method — not even discovery commands like `which bk`. If MCP tools fail, report the failure and stop. Do not fall back to alternatives.**

Verify Docker is running (`docker info`). If not, start it (`open -a Docker`) and poll every 5 seconds for up to 30 seconds. If Docker still fails, stop and tell the user: "Docker Desktop failed to start. The Buildkite MCP server requires Docker to run. Start Docker manually and retry."

If Buildkite MCP tools return organization access errors, stop and tell the user to connect to VPN before retrying. Do not attempt workarounds.

### Step 4: Identify Failed Builds

Parse the GitHub checks output to find failed Buildkite builds. Extract the build URL and slug from the check details.

If the checks output doesn't include enough detail (e.g., missing build URLs), use `gh api repos/{owner}/{repo}/commits/{sha}/check-runs` to get check run details with URLs. Extract the owner and repo by running `gh repo view --json owner,name`.

### Step 5: Fetch & Analyze Failures

For each failed build, launch a **Task subagent** to fetch logs and extract failure details. This keeps raw log output out of the main context.

Each Task subagent should:
1. Call `mcp__buildkite__get_build` with the org slug, pipeline slug, and build number
2. Call `mcp__buildkite__get_jobs` to identify which jobs failed
3. For each failed job: call `mcp__buildkite__search_logs` or `mcp__buildkite__tail_logs` to get the failure output
4. Return a **concise summary** for each failed job:
   - Job name
   - The specific error message / assertion failure / build error (exact text, not paraphrased)
   - File and line number if identifiable from logs
   - Whether the failure looks code-related or infrastructure-related

Launch subagents for independent builds in parallel. Use `model: opus` for the subagents.

### Step 6: Categorize Each Failure

Using the failure summaries from Step 5, read relevant source files and `git diff main...HEAD` to categorize each failure:

| Category | Criteria | Complexity |
|----------|----------|------------|
| `auto-fix` | CODEOWNERS issues. Test failures with clear cause: wrong assertion after intentional change, missing import, renamed function, snapshot needs updating. Build errors with obvious fix: syntax error, missing dependency. | `simple` or `complex` |
| `ephemeral` | Failure not related to code changes. Docker pull timeouts, network errors, dependency download failures, infra provisioning issues, rate limiting. Key signal: the PR's diff doesn't touch anything related to the failure. | N/A |
| `needs-investigation` | Flaky tests. Race conditions. Failures in code the PR didn't modify but might have affected indirectly. Unfamiliar error patterns. Test failures where root cause isn't clear. | N/A |

**Rules for categorization:**
- **Always read the actual source code** — don't guess from log output alone
- **For test failures**, check if the test expectation needs updating (intentional behavior change) vs. the code having a bug
- **For CODEOWNERS**, check if new files/directories were added that need ownership entries
- **Be specific in failure summaries** — "AssertionError on line 42: expected 'foo', got 'bar'" not "test failed"
- **When categorizing as ephemeral**, cite evidence (e.g., "no code changes touch networking, and the error is a DNS resolution timeout")

### Step 7: Present Diagnosis

Present results in this format:

```
## Diagnosis Report

**PR:** #<number> — <title>
**Build:** <buildkite URL>
**Failed jobs:** <N> of <total>

### Auto-Fix (<count>)
| # | Job | File | Failure Summary | Complexity |
|---|-----|------|-----------------|------------|

### Ephemeral (<count>)
| # | Job | Failure Summary | Evidence |
|---|-----|-----------------|----------|

### Needs Investigation (<count>)
| # | Job | File | Failure Summary | Possible Causes |
|---|-----|------|-----------------|-----------------|
```

Omit empty categories.

**Auto-fix items:** "I'll fix these automatically — no action needed from you."

**Ephemeral items:** "These look like infrastructure flakes. You'll need to restart these steps manually in Buildkite." List the specific job names.

**Needs investigation items:** Present each with failure details and possible causes. Use AskUserQuestion to ask how to proceed for each: attempt a fix, skip, or investigate further.

### Step 8: Implement Fixes

For auto-fix items and approved investigation fixes:

- **Simple items:** Launch Task subagents with `model: sonnet`. Each gets the specific failure, file path, and diagnosis.
- **Complex items:** Launch Task subagents with `model: opus`. Same context but for items requiring deeper reasoning.
- **Parallelize** where fixes are in different files or independent. Group fixes in the same file into one subagent to avoid conflicts.

Each implementation subagent should:
1. Read the relevant file(s)
2. Make the fix as described in the diagnosis
3. Run the specific failing test locally if possible
4. Report what was changed

### Step 9: Final Summary

Present a concise summary:
- **Fixed:** List of items addressed (with file references)
- **Ephemeral:** Jobs to restart manually (with job names)
- **Skipped:** Investigation items the user chose not to fix
- **Next step:** "Push your changes and CI will re-run. Restart the ephemeral jobs in Buildkite."
