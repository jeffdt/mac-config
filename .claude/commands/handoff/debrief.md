---
description: Summarize session outcomes for the orchestrating session
allowed-tools: Bash(echo:*), Bash(pbcopy:*)
argument-hint: [hint]
---

Summarize what happened in this session as a debrief for the orchestrating/planning session that dispatched this work. The output is pasted into a still-open planning session that already has full prior context, so this is a delta report, not a standalone prompt.

**Hint**: $ARGUMENTS

## Pre-computed context

- Repo (derive name from last path segment): !`git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"`
- Current branch: !`git branch --show-current 2>/dev/null || echo "not a git repo"`
- PR for this branch: !`gh pr view --json number,title,url,state 2>&1 || echo "No PR exists"`
- Recent commits on this branch: !`git log --oneline main..HEAD 2>/dev/null || echo "no branch history"`

## What to capture

Review the full conversation and the pre-computed context above. Synthesize a debrief with these sections. Include each section only if there's relevant content for it.

Open the debrief with a fixed framing line so an orchestrating session that wasn't expecting this paste knows what it's receiving, then a blank line before the sections:

```
The following is a status report from another Claude Code session, summarizing work accomplished, artifacts produced, notable findings, and deviations from the original plan.
```

1. **Session** — one line identifying which dispatched task this debrief answers. Format: `<repo>: <one-line task summary>`. Pull the repo from the pre-computed context; derive the task summary from the original dispatch prompt or earliest session context, not the final outcome. This exists so the orchestrating session can match the debrief to the dispatch it sent. Always include.
2. **Status** — one line: done, partially done, or blocked. If blocked, say on what.
3. **Artifacts** — branch name, PR URL, tickets created or closed, files produced, or any other concrete outputs. Merge what you find in the pre-computed context with anything referenced in the conversation.
4. **Decisions** — anything that diverged from the original plan, spec, or session prompt, and why. Include discoveries that changed the approach. Skip this section entirely if everything went as expected.
5. **Unresolved** — open questions, loose ends, or follow-up work the orchestrating session should know about. Skip if nothing is unresolved.

## Audience and voice

The reader is the orchestrating session, not the user. It has the original dispatch context but has not seen this session's conversation. Write accordingly:

- State facts directly rather than describing user state. "ArgoCD rollout must complete before k-repo AMPSS-207 can merge" beats "User is aware that ArgoCD needs to roll out."
- If something genuinely depends on the user's knowledge or decision, attribute it explicitly: "User confirmed they're tracking the rollout" or "User decided to defer X to a follow-up PR."
- Do not use "you" — the orchestrating session is not the user.

## What NOT to include

- Implementation details (the PR/branch/diff has those)
- Context the planning session already knows (it dispatched this work)
- Workflow instructions or opinions about what the planning session should do next
- Rehashing the original task description

The debrief should be terse. The planning session will ask follow-up questions if it needs more detail.

## Using the hint

If `$ARGUMENTS` is provided, use it to guide focus. The hint might emphasize a specific aspect of the work (e.g., "focus on the contract changes", "what happened with the migration"). If no hint is provided, cover whatever is most important.

## Output

Do not use the Write tool or save to a file. Pipe the debrief as plain text (no markdown code fences wrapping the whole thing) to `pbcopy` via a Bash heredoc. The piped text must lead with the fixed framing line above, a blank line, then the sections. Confirm to the user with a brief message: what the debrief covers and its status.
