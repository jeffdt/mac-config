---
description: Triage and address PR review feedback from humans and bots
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git add:*), Bash(git commit:*), Bash(git checkout:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh repo view:*), Bash(gh api:*), Bash(~/.claude/scripts/get-pr-feedback.sh:*), mcp__plugin_linear_linear__*, AskUserQuestion, Task
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,url,title,body,state,author 2>&1 || echo "NO_PR_FOUND"`
- Ticket link: !`gh pr view --json body -q '.body' 2>/dev/null | grep -oE 'https://linear\.app/klaviyo/issue/[A-Z]+-[0-9]+' | head -1 | grep . || echo "NO_TICKET_FOUND"`
- Working tree state: !`git status --porcelain 2>/dev/null | head -20 | grep . || echo "CLEAN"`

## Instructions

### Preflight: Working tree check

Check the `Working tree state` value above.

- If it equals `CLEAN`, proceed to Step 1.
- If it shows uncommitted changes: pause before doing anything else. The triage and fix-implementation steps below read `git status` and `git diff`, so unrelated dirty state will pollute their reasoning. Use AskUserQuestion to ask how to proceed. Options:
  - **Continue** — work against the current dirty state (you accept that fixes may interleave with in-progress edits).
  - **Stash and continue** — run `git stash push -u -m "pre-feedback"`, proceed, and tell the user to `git stash pop` afterward.
  - **Abort** — stop here so the user can commit, stash, or clean up manually.

### Step 1: Resolve the PR

Check the pre-computed PR info above.

- If it contains `NO_PR_FOUND` or the current branch is `main`/`master`: use AskUserQuestion to ask for a PR number or URL. Then fetch its info with `gh pr view <number> --json number,url,title,body,state`.
- **If PR info is present: use it and move directly to Step 2. Do NOT ask the user to confirm or select a PR — the pre-computed context already resolved it.**

### Step 2: Fetch Feedback

Get repo owner/name with `gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"'`, then fetch unified feedback as JSON:

```bash
~/.claude/scripts/get-pr-feedback.sh <owner> <repo> <pr_number>
```

The script returns:
- `pr_author` — the PR author's login (for self-pending detection)
- `self_pending_reviews` — `[{ review_id, comment_count }]` aggregated from self-pending comments; used by the cleanup step
- `review_threads` — inline comments with `path`, `line`, full `body`, `review_state`, and per-comment `is_self_pending` flag
- `reviews` — review submissions with non-empty body (top-level review messages)
- `comments` — general PR issue comments (often where bots leave their top-level summary)

Resolved and outdated threads are already filtered out — anything that comes through is live.

Also run `git diff <base>...HEAD` (try `main`, fall back to `master`) so you can correlate comments with the diff during triage.

### Step 3: Triage Inline

Default path: read the JSON directly and categorize each item yourself. You can see the verbatim comment bodies and reason about them with full context.

**Escape hatch:** if total comment count is high (>15) and the feedback is dominated by bot noise that would burn parent context, launch the `pr-feedback-triage` agent as a Task subagent (Opus model) and pass it the PR metadata. The agent uses the same fetch script and returns a structured report. Most PRs should NOT need this.

For inline triage, apply this logic:

**Self-pending shortcut.** Any review-thread comment with `is_self_pending == true` is a direct user instruction. Route to:
- `auto-fix` if obviously simple (typo, rename, single-line edit, missing import)
- `fix` (tagged `simple` or `complex`) otherwise

Never `defer` or `dismiss` a self-pending comment. Track its `review_id` so the cleanup step can find the parent pending review (the `self_pending_reviews` summary already aggregates this).

**Third-party feedback (everyone else).** Evaluate each comment along:
- Technically valid? (false positive vs real issue)
- Cost of fixing now vs later
- Risk of NOT fixing (correctness, security, perf vs cosmetic)
- Scope fit with this PR
- Complexity: `simple` or `complex`

Then categorize:

| Category | Criteria | Complexity |
|----------|----------|------------|
| `auto-fix` | Valid, clear-cut, low-risk: typos, missing imports, obvious bugs, simple renames, formatting | Always `simple` |
| `fix` | Valid concern where cost-of-fixing-now is low relative to risk-of-deferring | `simple` or `complex` |
| `defer` | Valid but cost outweighs urgency: large refactors, tangential scope, low-risk improvements | N/A |
| `dismiss` | Pedantic, incorrect, false positive, stylistic nitpick contradicting project conventions | N/A |

Calibrate by the PR title, description, diff scope, and linked ticket. A tightly-scoped fix doesn't need to absorb unrelated hardening; a large feature PR has more room for adjacent improvements.

### Step 4: Present Triage Results (read-only)

Present your triage as a plain markdown reply. **Do NOT call AskUserQuestion in this step.** This is a read-only checkpoint so the user can absorb the findings, ask follow-up questions, or push back on a categorization before any decisions get made.

For each category include:

**Auto-fix items:** List them briefly. Note that these will be fixed automatically once the user signals to proceed. Self-pending items appearing here should be flagged as "from your pending review" so it's clear what's being addressed.

**Fix (needs approval) items:** Present each with the recommended approach. Self-pending items here came directly from the user — flag them so the user knows those will be implemented without further approval. Third-party items will be presented for per-item approval in the next step.

**Deferred items:** List with reasoning. The user will choose which to ticket in the next step.

**Dismissed items:** Show briefly with reasoning. No action will be taken unless the user objects.

End the reply with this exact line (plain text, no question UI):

> Any questions about the findings before we decide which ones to address?

Then stop and wait for the user's reply. If the user asks questions, answer them in plain text and re-prompt with the same line. Only move to Step 5 once the user signals to proceed (e.g., "looks good", "go ahead", "proceed").

**Capturing dismissals during Q&A.** If the user uses this checkpoint to back out of a self-pending item — e.g., "actually skip item N", "leave that one alone", or picking a "don't change" option you offered them — record that item as **dismissed**. This is an explicit user decision and is meaningfully different from an item that silently fails later. Step 9 depends on this distinction.

### Step 5: Collect Decisions

Now collect approvals via AskUserQuestion:

- **Third-party fix items:** Ask per-item (or batched if many) — approve, modify, or skip.
- **Self-pending fix items:** Skip approval — the user already wrote the comment as an instruction.
- **Deferred items:** Ask which should become Linear tickets — select specific items, all, or none.
- **Dismissed items:** Skip unless the user objected in Step 3.

If there are zero items requiring decisions (everything is auto-fix or self-pending, no deferrals to ticket), skip AskUserQuestion entirely and proceed straight to Step 6.

### Step 6: Implement Fixes

For auto-fix items and approved fix items, dispatch implementation subagents:

- **Simple items (including all auto-fixes):** Launch Task subagents with `model: sonnet`. Each subagent gets the specific feedback item, the file path, and the recommended approach.
- **Complex items:** Launch Task subagents with `model: opus`. Same context but for items requiring deeper reasoning.
- **Parallelize** where fixes are in different files or independent code areas. Group fixes in the same file into one subagent to avoid conflicts.

Each implementation subagent should:
1. Read the relevant file(s)
2. Make the fix as described
3. Verify the fix compiles/parses (run relevant linter or test if obvious)
4. Report what was changed

### Step 7: Create Linear Tickets for Deferrals

For each deferred item the user chose to ticket:
- Use `mcp__plugin_linear_linear__save_issue` to create a ticket
- Title: brief description of the feedback
- Description: include the original reviewer comment, file path, and a link to the PR
- Ask for the team name if not obvious from context (or infer from the ticket already linked to the PR)

### Step 8: Conditional QA Verification

Run the QA agent if EITHER condition is true:
- Any `complex` items were implemented
- 5 or more total fixes were made

If triggered: launch the `pr-feedback-qa` agent as a Task subagent (Sonnet model). Pass it the list of implemented items and the PR number. Present its verdict to the user.

If the QA agent reports PARTIAL or FAIL, present the gaps and ask the user how to proceed.

### Step 9: Pending-Review Cleanup

For each self-pending item, you should have tracked one of three outcomes:

- `addressed` — fix was successfully implemented in Step 6
- `dismissed` — user explicitly decided not to address it (in Step 4 Q&A or Step 5)
- `pending` — neither addressed nor dismissed (e.g., implementation failed and the user hasn't decided what to do)

Skip this step entirely if `self_pending_reviews` from the fetch script was empty.

**All items resolved (every item is `addressed` or `dismissed`):** Delete the pending review(s) automatically — no AskUserQuestion needed. The user has made an explicit decision on every comment, so there's no reason to keep the pending review open. For each `review_id` in `self_pending_reviews` run:

```bash
gh api graphql -f query='mutation($id: ID!) { deletePullRequestReview(input: {pullRequestReviewId: $id}) { clientMutationId } }' -F id="<review-id>"
```

This deletes the pending review and all its comments in one call. Report what was deleted in Step 10.

**Any item still `pending`:** Do NOT auto-delete. The user may still want those comments visible for the next pass. Tell them the review ID(s) and quote the gh api command above so they can delete it manually if they choose.

### Step 10: Final Summary

Present a concise summary:
- **Fixed:** List of items addressed (with file references)
- **Deferred:** Items ticketed (with Linear ticket links) and items skipped
- **Dismissed:** Brief count with note that details were shown earlier
- **QA:** Verdict if QA ran, or note that QA was skipped and why
