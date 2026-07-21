---
description: Summarize session outcomes for the orchestrating session
allowed-tools: Bash(echo:*), Bash(pbcopy:*), Bash(mux:*)
argument-hint: [--target <window>|<session:window>] [hint]
---

Summarize what happened in this session as a debrief for the orchestrating/planning session that dispatched this work. The output is pasted into a still-open planning session that already has full prior context, so this is a delta report, not a standalone prompt.

**Arguments**: $ARGUMENTS

If `$ARGUMENTS` begins with `--target <spec>`, extract `<spec>` and treat everything after it as the hint. `<spec>` is `[SESSION:]WINDOW`:
- Bare `WINDOW` — a window in the caller's own tmux session (`mux`'s `caller` workspace).
- `SESSION:WINDOW` — a window in another session.

If no `--target` is present, treat all of `$ARGUMENTS` as the hint (today's behavior, unchanged).

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

If a hint is present (the text after `--target <spec>`, or all of `$ARGUMENTS` if there's no `--target`), use it to guide focus. The hint might emphasize a specific aspect of the work (e.g., "focus on the contract changes", "what happened with the migration"). If no hint is provided, cover whatever is most important.

## Output

The debrief is plain text (no markdown code fences wrapping the whole thing), leading with the fixed framing line above, a blank line, then the sections. Do not use the Write tool or save it to a file.

**No `--target`:** pipe the debrief to `pbcopy` via a Bash heredoc, exactly as before. Confirm to the user with a brief message: what the debrief covers and its status.

**With `--target <spec>`:** before delivering, resolve the target and judge whether it's safe to auto-submit into:

1. Split `<spec>` on `:`. No colon → `--workspace caller --tab <spec>`. Colon present → `--workspace <session> --tab <window>`.
2. Run `mux read --workspace <ws> --tab <tab> --lines 60` to capture the target pane's current screen. If this fails (exit 3, window/session not found), fall back to `pbcopy` and tell the user: `Target '<spec>' not found — copied to clipboard instead.`
3. Look at the captured screen and judge: does this look like an active Claude Code or pi session sitting at its input composer, ready for a new freeform prompt? This is a judgment call you make by reading the content — not a fixed pattern to match. A bare shell prompt, an editor, a permission dialog, or an `AskUserQuestion`-style picker are all "not ready." A composer that's mid-turn but not blocked on a dialog is "ready" — the message will queue.
4. If it looks ready, pipe the debrief text into `mux paste --workspace <ws> --tab <tab> --enter` (same heredoc pattern used for `pbcopy`, piped to `mux` instead). If this command fails, fall back to `pbcopy` and tell the user: `Target '<spec>' paste failed — copied to clipboard instead.` Otherwise, confirm to the user with a brief message: what the debrief covers, its status, and that it was delivered to `<spec>`.
5. If it does NOT look ready, fall back to `pbcopy` and tell the user: `Target '<spec>' doesn't look like an idle Claude/pi composer (looks like <brief description>) — copied to clipboard instead.`
