---
description: Review-fix-review loop — temper a PR through repeated cycles until it's solid
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(mkdir:*), mcp__plugin_linear_linear__*, Read, Edit, Write, Grep, Glob, Task, AskUserQuestion
runInPlanMode: false
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,url,title,body,state,author 2>&1 || echo "NO_PR_FOUND"`
- PR diff: !`gh pr diff 2>/dev/null || echo "NO_DIFF"`
- Temper manifest: !`bash ~/.claude/scripts/read-temper-manifest.sh`

## Flow

This is a **loop**, not a linear sequence. Follow this state machine:

```
INIT → REVIEW → TRIAGE ──┬── findings exist ──→ PLAN → [approval gate] → FIX ──→ REVIEW (loop back)
                          │
                          └── nothing to fix ──→ SIMPLIFY → FINAL_REVIEW → DONE
```

Critical invariants:
- **FIX always loops back to REVIEW.** Never go from FIX to SIMPLIFY. Never go from FIX to DONE.
- **SIMPLIFY is only reachable from TRIAGE** when there are no findings worth fixing.
- **PLAN requires explicit user approval** via AskUserQuestion before any code is written.

## States

### INIT

Resolve the PR from pre-computed context. If NO_PR_FOUND, inform the user and stop.

The temper manifest tracks what has been flagged, fixed, declined, and contested across cycles. It lives at `.claude/local/temper-manifests/pr-{number}.md` and is included in pre-computed context above. Manifest categories:

- **Fixed**: findings that were addressed and how
- **Declined**: findings that were intentionally skipped and why
- **Contested**: findings where the reviewer re-flagged something already in the manifest — these represent genuine tradeoffs that need user input, not simple oscillation

Create `.claude/local/temper-manifests/` if it doesn't exist. If the manifest has content (not "first temper run"), this is a resumed session — pass its contents to the reviewer so it knows what's already been addressed.

→ Go to **REVIEW**

### REVIEW

Launch the `pr-review` agent via the Task tool with `subagent_type: "pr-review"`. Pass the PR number, pre-computed context, and temper manifest contents (if any).

→ Go to **TRIAGE**

### TRIAGE

Dispatch triage to a **fresh subagent** so it is not biased by prior cycles. The subagent sees only the current review report, manifest, and diff — no prior triage decisions, no fix history, no orchestrator context.

Launch a Task subagent (model: opus) with no tools and the following prompt:

````
You are triaging a code review for a PR tempering cycle. Categorize each finding from the review report below.

**Category definitions:**
- **Must fix**: Critical (Blocking) and Important (Should Fix) findings not already covered by a stable manifest entry
- **Low-hanging fruit**: Non-blocking suggestions that don't add significant complexity
- **Contested**: Any finding that overlaps with a manifest entry (Fixed or Declined). The reviewer is re-flagging something already addressed — this may be oscillation, or it may be a legitimate tradeoff the first decision got wrong. Do not auto-suppress. Surface for user decision.
- **Skip**: Everything else, plus stable manifest entries the reviewer did NOT re-flag

**Spec conformance is not a shield.** "Matches the spec" is NOT a valid reason to skip a finding. The spec is a plan, not a contract. If the reviewer identifies a genuine issue with code that happens to follow the spec, categorize it on its merits. The only exception: explicit cross-system contracts (API boundaries, multi-repo interfaces) where changing behavior could break external consumers. Those should be categorized as Must Fix but flagged with a warning that the contract may need coordinated changes.

**Output this exact format:**

## Triage Result

### Recommendation
PROCEED_TO_PLAN or PROCEED_TO_SIMPLIFY
(PROCEED_TO_PLAN if must-fix or contested lists are non-empty; PROCEED_TO_SIMPLIFY otherwise)

### Must Fix
- **[finding ref]**: [one-line rationale]

### Low-Hanging Fruit
- **[finding ref]**: [one-line rationale]

### Contested
- **[finding ref]**: Original decision: [manifest entry]. Reviewer's objection: [what was re-flagged]. [assessment: oscillation or legitimate tradeoff?]

### Skip
- **[finding ref]**: [one-line rationale]

---

REVIEW REPORT:
{paste the full review report from the REVIEW phase}

TEMPER MANIFEST:
{paste manifest contents, or "No prior history" if first cycle}

PR DIFF:
{paste the PR diff from pre-computed context}
````

When the subagent returns, follow its **Recommendation** mechanically:
- `PROCEED_TO_PLAN` → go to **PLAN** (pass the full triage result so it can build the fix plan)
- `PROCEED_TO_SIMPLIFY` → go to **SIMPLIFY**

### PLAN

Present a numbered implementation plan listing each finding and its concrete fix. If any findings are **Contested** (re-flagged despite being in the manifest), call them out separately with the original decision and the reviewer's new objection so the user can make an informed call.

**⛔ MANDATORY APPROVAL GATE**

You MUST call `AskUserQuestion` and STOP. Do not continue until you receive a response.

```
AskUserQuestion("Here is the fix plan for this temper cycle:\n\n{numbered plan}\n\nApprove? (yes / no / modify)")
```

**STOP HERE AND WAIT.** Do not present the plan as text and keep going. Do not treat your own output as approval. The user must respond before you write any code. If the user says no or requests modifications, revise the plan and ask again.

→ After explicit approval, go to **FIX**

### FIX

Implement the approved fixes, then:

1. Run the project's test suite (infer from repo: `npm test`, `pytest`, `make test`, etc.)
2. If tests fail, fix the failures before continuing
3. Update the temper manifest at `.claude/local/temper-manifests/pr-{number}.md`:
   - **Fixed**: what was addressed and how
   - **Declined**: what was intentionally skipped and why
   - **Contested**: tradeoff decisions the user resolved — record the decision and rationale so future cycles don't reopen them

→ **Go back to REVIEW.** Do not go to SIMPLIFY. Do not go to DONE. The loop must re-review to verify fixes didn't introduce new issues.

### SIMPLIFY

**Prerequisite:** You may only enter this state from TRIAGE when there were no findings worth fixing. If you just came from FIX, you are in the wrong state — go to REVIEW instead.

Run `/pr:simplify` as a finishing pass — naming, duplication, dead code, unnecessary complexity. After the simplify pass, run the test suite.

→ Go to **FINAL_REVIEW**

### FINAL_REVIEW

Launch the `pr-review` agent one final time to confirm the simplify pass didn't break anything.

- If clean → **DONE**. Write a brief passage (1-3 sentences) in the voice of literary fiction or genre fiction: an artisan, crafter, or creator admiring their finished work. Vary the craft wildly — a blacksmith, watchmaker, armorer, cartographer, luthier, glassblower, alchemist, wizard, shipwright, telescope-grinder, woodworker, chemist, perfumer, anything. Sci-fi and fantasy are both fair game. Evocative, sensory, a little overwrought. Different craft and tone every time. Do not reference git, PRs, code, or software — stay fully in the metaphor. Render the passage in italics inside a quote block. After the quote block, on its own line outside it, write: "And with that, the PR is tempered."
- If issues found → **STOP**. Alert the user and halt. The simplify pass should only make non-functional changes — if it introduced problems, that needs manual investigation. Do not loop back into fixes.
