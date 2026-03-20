---
description: Review-fix-review loop — temper a PR through repeated cycles until it's solid
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(mkdir:*), mcp__plugin_linear_linear__*, Read, Edit, Write, Grep, Glob, Task, AskUserQuestion
runInPlanMode: false
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,url,title,body,state,author 2>&1 || echo "NO_PR_FOUND"`
- Temper manifest: !`gh pr view --json number -q .number 2>/dev/null | xargs -I{} cat .claude/local/temper-manifests/pr-{}.md 2>/dev/null || echo "No manifest — first temper run"`

## Instructions

Temper a PR through repeated review-fix-review cycles until nothing worth fixing remains. Like tempering steel — each cycle strengthens the result.

**Step 0 — Manifest**

The temper manifest tracks what has been flagged, fixed, and declined across cycles to prevent oscillation (reviewer flags X, you fix it, next cycle flags the fix as a problem). The manifest lives at `.claude/local/temper-manifests/pr-{number}.md` and is included in pre-computed context above.

If the manifest has content (not "first temper run"), this is a resumed session — pass its contents to the pr-review agent so it knows what's already been addressed.

Create `.claude/local/temper-manifests/` if it doesn't exist. Update the manifest at the end of each cycle with:
- **Fixed**: findings that were addressed and how
- **Declined**: findings that were intentionally skipped and why

**Step 1 — Resolve PR**

Use the PR from pre-computed context. If NO_PR_FOUND, inform the user and stop.

**Step 2 — Review**

Launch the `pr-review` agent via the Task tool with `subagent_type: "pr-review"`. Pass the PR number, pre-computed context, and the temper manifest contents (if any) so the reviewer knows what has already been flagged and addressed in prior cycles.

**Step 3 — Triage Findings**

Analyze the review report. Select items to fix:

- All **Critical (Blocking)** items — must fix
- All **Important (Should Fix)** items — should fix
- **Suggestions (Non-blocking)** only if they are low-hanging fruit that don't add significant complexity or scope

If no items are worth fixing, proceed to Step 5 (simplify pass).

**Step 4 — Plan Fixes**

Present a numbered implementation plan listing each finding to address and the concrete fix. The plan MUST include a final step: "Run `/pr:temper` to verify fixes and continue the cycle."

This final step is critical — if the user clears context during plan execution, this ensures the re-review loop survives as an explicit plan step rather than being lost as an ambient instruction.

Use AskUserQuestion to present the plan and get approval before proceeding. Do not execute without approval.

After implementing fixes, run the project's test suite to verify nothing is broken before proceeding. Infer the test command from the project (e.g., `npm test`, `pytest`, `make test`, or whatever the repo uses). If tests fail, fix the failures before continuing to the next review cycle.

**Step 5 — Simplify Pass**

Once the review loop is clean (no findings worth fixing), run `/pr:simplify` as a finishing pass to clean up code quality — naming, duplication, dead code, unnecessary complexity. This catches non-functional improvements and cleans up any rough edges introduced by the fix cycles.

After the simplify pass, run the test suite again.

**Step 6 — Final Verification**

After the simplify pass, launch the `pr-review` agent one final time to confirm nothing was broken.

If this review is clean, the PR is tempered — done.

If this review finds issues, **STOP**. Do not loop back into fixes. The simplify pass should only make non-functional changes — if it introduced functional problems, that's unexpected and needs manual investigation. Alert the user and halt.
