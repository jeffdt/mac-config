---
description: Distill conversation context into a session prompt and copy to clipboard
allowed-tools: Bash(echo:*), Bash(pbcopy:*)
argument-hint: [hint]
---

Distill the current conversation into a prompt that can kickstart a new Claude Code session, then copy it to the clipboard.

**Hint**: $ARGUMENTS

## What to capture

Review the full conversation and synthesize a prompt with these sections. Include each section only if there's relevant content for it. Scale each section to the amount of useful context available.

1. **Origin** — what kicked off this work (Slack thread URL, Linear ticket, Sentry issue, user report, etc.). Include ONLY if identifiable from the conversation AND relevant to the new session. An ongoing investigation where the source provides important context: include it. A simple targeted question where the source doesn't matter: skip it.
2. **Situation** — what you were working on and why (1-2 sentences of framing)
3. **Findings** — what's been established, ruled out, or discovered so far
4. **Open questions** — what remains unresolved, hypotheses worth pursuing, or the specific thing the new session should focus on
5. **Key identifiers** — company IDs, user emails, endpoint paths, error messages, ticket numbers, or other concrete values the new session will need

## What NOT to include

- Workflow instructions ("use this skill", "create a worktree", "start by grepping for X")
- Opinions about what tools or approaches the new session should use
- Context the new session can derive from the codebase itself (file structures, existing patterns)
- Excessive detail from dead-end investigations (mention they were ruled out, not the full reasoning)
- Remaining work that belongs to other repos. The new session will be repo-bound; cross-repo task lists confuse it. If other repos need changes, mention that fact in one sentence at most, not the specifics.

The prompt should set up context and let the new session decide how to approach the work.

## Using the hint

If `$ARGUMENTS` is provided, use it to guide focus. The hint might specify:
- A target repo or area (e.g., "fender", "frontend", "k-repo auth service")
- A specific angle to emphasize (e.g., "CSRF token handling", "form serialization")
- Both (e.g., "fender form serialization for support tickets")

If the hint names a target, frame the prompt from that target's perspective. If no hint is provided, infer the target and focus from the conversation.

## Output

Write the prompt as plain text (no markdown code fences wrapping the whole thing) and pipe it to `pbcopy`. Then confirm to the user with a brief message: what the prompt covers and where it's targeted.
