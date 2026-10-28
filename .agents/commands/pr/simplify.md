---
description: Size gut check and simplicity trim on all branch changes before opening or readying a PR
allowed-tools: Bash, Read, Grep, Glob, Edit, Agent, AskUserQuestion, Skill
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Base branch: !`git rev-parse --verify main >/dev/null 2>&1 && echo main || echo master`
- Branch commits: !`git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null || echo "NO_BRANCH_COMMITS"`
- Diff stat: !`git diff --stat main...HEAD 2>/dev/null || git diff --stat master...HEAD 2>/dev/null || echo "NO_DIFF"`
- Open PR: !`gh pr view --json number,title,body,url 2>/dev/null || echo "NO_PR"`
- Review context: !`cat .claude/code-review-context.md 2>/dev/null || echo "NO_REPO_CONTEXT"`

## Instructions

### Validate Branch State

- If the current branch is `main` or `master`: say "You're on the main branch, switch to a feature branch first." and stop.
- If branch commits shows `NO_BRANCH_COMMITS`: say "No changes found on this branch relative to main." and stop.

### 1. Gut check the size

Find what the change is supposed to be, in this order: the open PR's title and body, the implementation plan for this work (look in `./plans/` of the project directory from conversation context, and use its "Size" estimate if it has one), the ticket, then the commit messages.

Split the diff stat into production lines and test lines. Then answer in two or three sentences:

- Would an engineer reading the title expect a diff this big? Would a reviewer be surprised?
- If a plan estimate exists, how far over it is, and which files account for the overage.

Do not propose splitting the PR here; that decision belongs at plan time. If the diff is still surprising after the trim below, say so at the end and suggest one sentence for the PR description explaining why it is that big.

### 2. Independent simplicity reviews

Dispatch two read-only reviewers in parallel, in a single message:

- An `Agent` with `subagent_type: general-purpose` that invokes the `ponytail:ponytail-review` skill.
- An `Agent` with `subagent_type: codex:codex-rescue`.

Give both the same self-contained brief:

- Worktree path, branch, and the exact diff command (`git -C <worktree> diff <base>...HEAD`).
- Two or three sentences on what the change does, and the production and test line counts from step 1.
- The properties that must survive: security checks, data-loss handling, validation at trust boundaries, and anything the plan or PR calls a requirement. Simpler implementations of them are welcome; removal is not.
- What to hunt: methods or queries that collapse into one; error or refusal branches whose distinct messages don't change what the caller can do; helpers that duplicate something already in the codebase (grep for it); the same behavior tested at more than one layer; test files that could fold into existing ones; test helpers that duplicate existing fixtures; tests that could be parametrized.
- Read-only: no edits, commits, or pushes.
- Return a ranked list, biggest savings first: `file:line`, the change, estimated lines saved (production and tests separately), risk.

### 3. Merge and apply

Merge the two lists into one:

- **Both found it:** apply it.
- **Only one found it:** apply it if it is low risk and removes code rather than rewriting it. Otherwise hold it.
- Keep one regression test close to the code for any security or atomicity property, even when a higher-layer test also covers it.

Show the user the held items in one short list (what, lines saved, why it was held) and ask with AskUserQuestion which to apply. Skip the question if nothing was held.

Apply the cuts, run the repo's test suite and linter, fix anything that breaks, and commit once with the `git-commit` skill. Report the before and after line counts, production and tests separately, and the step 1 note on whether the remaining size will surprise a reviewer.

If the user invoked this on an already-open PR, push with the `git-push` skill after committing.
