---
description: Explain recent changes interactively with comprehension checkpoints
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git show:*), Read, Grep, Glob, AskUserQuestion
---

## Pre-computed Context

- Recent commits: !`git log -10 --oneline`
- Change summary: !`git diff --stat HEAD~5..HEAD 2>/dev/null || echo "Not enough commits"`

## Instructions

You are about to explain the changes you recently made to this codebase. This is an interactive teaching session with a lead software engineer who needs to deeply understand not just WHAT changed, but WHY and HOW it fits into the larger system.

## Before Starting

1. Review the recent changes you made (use `git diff`, `git log`, or recall from conversation context)
2. Organize the changes into logical steps that build understanding progressively
3. Determine the total number of explanation steps (typically 3-7 depending on complexity)

## Explanation Format

For each step:

1. **Announce progress**: "**Step X/Y: [Topic]**"
2. **Explain the change**: Cover what was done, why it was necessary, and how it connects to the broader architecture
3. **Highlight key decisions**: Call out any non-obvious choices, tradeoffs, or patterns used
4. **Show relevant code**: Include brief, focused code snippets when they aid understanding

## Clarification Pause

After explaining each step (or group of 1-2 steps), pause and ask: **"Any questions about what I just covered before we move on to a quick comprehension check?"**

- Wait for the user's response
- If they have questions, answer them fully before proceeding
- Only once they confirm understanding (e.g., "nope, good to go", "makes sense", etc.), transition to the comprehension checkpoint below

## Comprehension Checkpoints

Once the user confirms no clarifying questions, quiz them. These questions should:

- **Test architectural understanding**, not rote recall
- **Probe the "why"** behind decisions, not just the "what"
- **Connect concepts** across different parts of the system
- **Challenge assumptions** about how components interact
- **Be meaningful and few** - 1-2 thoughtful questions per checkpoint, not a barrage of trivia

**Quiz questions serve two purposes:** They test the user's comprehension, but they also validate the changes themselves. If the user cannot articulate a good reason for a decision, it may be because the decision was wrong — not because they don't understand it. Treat moments where the user struggles to justify a choice as potential signals that the change needs revisiting, not just that the explanation needs improving.

**Question types to favor:**
- "If we had done X instead, what would break and why?"
- "How does this change affect [related component]?"
- "What would happen if [edge case]?"
- "Why didn't we just [simpler alternative]?"
- "What principle or pattern is this following?"

**After asking a question:**
- Wait for the user's response
- Provide feedback: confirm correct understanding or gently correct misconceptions
- If the user is struggling, dig deeper before moving on
- If the user wants to explore a tangent, go with it - but explicitly ask "Should we continue to Step X, or explore this further?" before moving on

## Handling Tangents

If the conversation drifts into deeper exploration of a topic:
1. Engage fully with the tangent - this is valuable learning
2. When the tangent feels complete, explicitly check in: "We've gone deep on [topic]. Ready to continue to Step X/Y, or is there more to unpack here?"
3. Only proceed when the user confirms

## Session Flow

1. Start with a brief overview: "I made N changes across [areas]. I'll walk you through them in Y steps."
2. Progress through steps with checkpoints
3. End with a synthesis: "To recap the key architectural decisions..." and one final integration question that ties multiple concepts together

## Begin Now

Review the recent changes and start the interactive explanation. Remember: you're teaching a lead engineer who should be held accountable to understand the system deeply.
