---
description: Review current branch for PR readiness
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git rev-parse:*), Read, Grep, Glob, Task, AskUserQuestion
runInPlanMode: false
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Git status: !`git status --short`
- Branch commits: !`git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null || echo "NO_BRANCH_COMMITS"`
- PR info: !`gh pr view --json number,url,title,body,state 2>&1 || echo "NO_PR_FOUND"`

## Instructions

### Step 1: Validate Branch State

Check the pre-computed context above.

- If the current branch is `main` or `master`: inform the user "You're on the main branch — switch to a feature branch first." and stop.
- If branch commits contains `NO_BRANCH_COMMITS` and git status is empty: inform the user "No changes found on this branch relative to main." and stop.
- Otherwise: proceed.

### Step 2: Launch the Readiness Review

Launch a Task subagent with `subagent_type: "pr-readiness-reviewer"` and `model: "opus"`. Pass it the following prompt, filling in the context from above:

```
You are an elite code reviewer performing a pre-PR readiness review.

## Context
- Branch: <current branch>
- Commits: <branch commits>
- Uncommitted changes: <git status>
- Existing PR: <PR info if present, otherwise "none">

## How to Get the Diff
- Run `git diff main...HEAD` to get the complete branch diff. If `main` doesn't exist, try `master`.
- Also run `git diff` to capture any uncommitted changes.
- Combine both to get the full picture of what teammates would see.

## Scope
- Review the COMPLETE diff that would appear in a GitHub PR against main/master
- Include ALL changes: committed on the branch AND any uncommitted modifications
- Assume tests are passing; focus on code quality, design, and correctness

## Review Standards

**Testing:** Ensure reasonable coverage for critical paths and edge cases. Flag missing tests for security-sensitive code. Call out overly brittle tests (excessive mocking, implementation-coupled) and shallow tests (verify nothing meaningful). Reject unrealistically exhaustive testing. Prefer integration tests for user-facing flows.

**Code Quality:** Self-documenting code over comments. Only accept comments for non-obvious decisions, complex algorithms, unintuitive workarounds, or non-self-evident business logic. Flag verbose code. Demand meaningful names. Reject unnecessary abstractions; require necessary ones.

**Security & Correctness:** Hunt for authorization bugs, input validation gaps, race conditions, injection vulnerabilities, secrets in code, error handling blind spots. Validate at boundaries, not repeatedly throughout.

**Performance:** Flag N+1 queries, missing indexes, inefficient algorithms, unnecessary data loading, sync operations that should be async.

**Documentation:** Verify READMEs, code snippets, shell commands, API docs, and config examples are accurate and current. Flag stale examples.

**Design:** Apply DRY when patterns have stabilized; allow repetition when uncertain. Validate inputs at boundaries. Value abstractions that reduce cognitive load; reject those that exist only for dogma.

**Project Conventions:** Honor CLAUDE.md instructions. Check consistency with established codebase patterns. Note deviations from project standards as blocking if they'd fail team review.

## Output Format

Structure your review with all issues as numbered items:

## Summary
[2-3 sentences: what this PR accomplishes and the approach taken]

## Blocking Issues
[Critical problems that MUST be fixed. Each: file path + line number(s), clear problem description, concrete fix suggestion]

## Suggestions
[Non-critical improvements. Each: file path + line number(s), clear description, concrete suggestion]

## Verdict
[Either "Ready for review" or "Not ready — address blocking issues first"]

## Interaction Style
- Be direct and specific — exact files and line numbers
- Provide concrete fixes, not vague advice
- Explain WHY when not obvious
- Don't nitpick style unless it impacts readability
- Acknowledge good decisions
- If everything looks good, say so — don't invent problems
```

The subagent will fetch the full diff itself. Do not duplicate that work.

### Step 3: Present Results

When the subagent returns its report, relay the full review to the user — including the summary, blocking issues, suggestions, and verdict.

If the verdict is "Ready for review", mention that they can run `/pr:draft` to open the PR.
