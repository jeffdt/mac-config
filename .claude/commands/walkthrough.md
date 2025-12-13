---
description: Explain recent changes interactively with comprehension checkpoints
---

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

## Comprehension Checkpoints

After every 1-2 steps (use judgment based on complexity), pause to quiz the user. These questions should:

- **Test architectural understanding**, not rote recall
- **Probe the "why"** behind decisions, not just the "what"
- **Connect concepts** across different parts of the system
- **Challenge assumptions** about how components interact
- **Be meaningful and few** - 1-2 thoughtful questions per checkpoint, not a barrage of trivia

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
