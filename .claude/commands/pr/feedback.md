---
description: Triage and address PR review feedback from humans and bots
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git add:*), Bash(git commit:*), Bash(git checkout:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh api:*), mcp__plugin_linear_linear__*, AskUserQuestion, Task
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,url,title,body,state 2>&1 || echo "NO_PR_FOUND"`
- Ticket link: !`gh pr view --json body -q '.body' 2>/dev/null | grep -oE 'https://linear\.app/klaviyo/issue/[A-Z]+-[0-9]+' | head -1 | grep . || echo "NO_TICKET_FOUND"`

## Instructions

### Step 1: Resolve the PR

Check the pre-computed PR info above.

- If it contains `NO_PR_FOUND` or the current branch is `main`/`master`: use AskUserQuestion to ask for a PR number or URL. Then fetch its info with `gh pr view <number> --json number,url,title,body,state`.
- If PR info is present: proceed with it.

### Step 2: Infer and Confirm PR Intent

Based on the PR title, description, branch name, and linked ticket, infer the PR's intent:
- **poc/prototype**: Experimental, exploratory, or proof-of-concept work
- **feature**: New functionality for production use
- **bugfix**: Fixing a specific issue or regression
- **refactor**: Restructuring without behavior change

Use AskUserQuestion to confirm: present your inference and ask if it's correct. Example: "This looks like a **feature** PR based on the description. Sound right?" with options for each intent type.

### Step 3: Dispatch Triage Agent

Launch the `pr-feedback-triage` agent as a Task subagent (Opus model). Pass it:
- The PR number, URL, title, body, and state from pre-computed context
- The ticket link (if found)
- The confirmed PR intent

Wait for the triage report to come back.

### Step 4: Present Triage Results

Present the triage report to the user in a clean summary. For each category:

**Auto-fix items:** List them briefly. Say "I'll fix these automatically — no action needed from you."

**Fix (needs approval) items:** Present each one with the recommended approach. Use AskUserQuestion to let the user approve, modify, or skip each item (or approve/skip all at once if there are many).

**Deferred items:** Present the list. Use AskUserQuestion to ask which ones should become Linear tickets. Options: select specific items, all of them, or none.

**Dismissed items:** Show briefly with reasoning. No action needed unless the user objects.

### Step 5: Implement Fixes

For auto-fix items and approved fix items, dispatch implementation subagents:

- **Simple items (including all auto-fixes):** Launch Task subagents with `model: sonnet`. Each subagent gets the specific feedback item, the file path, and the recommended approach.
- **Complex items:** Launch Task subagents with `model: opus`. Same context but for items requiring deeper reasoning.
- **Parallelize** where fixes are in different files or independent code areas. Group fixes in the same file into one subagent to avoid conflicts.

Each implementation subagent should:
1. Read the relevant file(s)
2. Make the fix as described
3. Verify the fix compiles/parses (run relevant linter or test if obvious)
4. Report what was changed

### Step 6: Create Linear Tickets for Deferrals

For each deferred item the user chose to ticket:
- Use `mcp__plugin_linear_linear__save_issue` to create a ticket
- Title: brief description of the feedback
- Description: include the original reviewer comment, file path, and a link to the PR
- Ask for the team name if not obvious from context (or infer from the ticket already linked to the PR)

### Step 7: Conditional QA Verification

Run the QA agent if EITHER condition is true:
- Any `complex` items were implemented
- 5 or more total fixes were made

If triggered: launch the `pr-feedback-qa` agent as a Task subagent (Sonnet model). Pass it the list of implemented items and the PR number. Present its verdict to the user.

If the QA agent reports PARTIAL or FAIL, present the gaps and ask the user how to proceed.

### Step 8: Final Summary

Present a concise summary:
- **Fixed:** List of items addressed (with file references)
- **Deferred:** Items ticketed (with Linear ticket links) and items skipped
- **Dismissed:** Brief count with note that details were shown earlier
- **QA:** Verdict if QA ran, or note that QA was skipped and why
