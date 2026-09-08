---
name: next-steps
description: "Use when the user asks to distill a preceding long or narrative assistant response into what they actually need to do next: phrases like \"/next-steps\", \"TMI, give me concise next steps\", \"what do I need to do\", \"cut to the chase\", \"bottom line it\", \"do I need to do anything\", \"give me the important bit\", or \"give me the tl;dr on what's needed from me\". Trigger on the intent even when the user doesn't use these exact words, as long as they're clearly asking to compress something ALREADY SAID in this conversation down to the actionable part. Never use for a forward-looking planning question like \"what should we do next\" or \"what's next on the roadmap\" that isn't asking to compress prior output; those get answered directly, without this skill."
---

# Next Steps

Strip a preceding summary down to the one thing that matters: what does the user need to do, if anything. Runs entirely on the conversation already in context; do not dispatch a subagent or re-read files, the only input is what was already said.

If there is no preceding substantive assistant turn to compress (this is the first message, or prior turns were already just chat), say so directly instead of forcing an output.

## Step 1: Find the pending ask

Look at the most recent substantive assistant turn(s) before this request. Ignore anything already resolved earlier in the conversation. Identify every open item and classify each one:

- **Blocking on the user**: a decision, review, or action only they can take (approve a plan, answer a question, run a manual check, merge a PR).
- **Waiting on something external**: CI, a teammate's review, a deploy, an async job. Nothing for the user to do but wait; note what to watch for.
- **FYI / flagged, not blocking**: follow-up work called out but explicitly deferred, known pre-existing issues left untouched, things mentioned only for awareness.
- **Nothing pending**: the work is done and nothing else is needed.

## Step 2: Output

Lead with the artifact link if one exists (PR, ticket, doc), bare, with no surrounding sentence. Then the action list, most urgent first. Split into separate short lists only if both blocking and FYI items exist; don't force the split if there's only one kind. If Step 1 found nothing pending, say that in one line instead of manufacturing a list.

No restated context, no "what I built," no verification narrative: that already happened in the turn being compressed. If an item's meaning is unclear without one word of context, keep that word; don't cut so hard that the item becomes cryptic.

Cap each list at 5 items. Past that, keep only what's actually actionable and fold the rest into a single "also flagged:" line.

### Example

Preceding turn (condensed): a long summary describing a finished PR, what was built, how it was verified, what couldn't be verified locally, and two unrelated follow-ups flagged for later.

Output:

```
PR: https://github.com/org/repo/pull/24

Next steps:
1. Run the onboarding install to pick up the new config.
2. Confirm the status page shows live with non-zero counts.
3. Click through the three integration buttons manually.
4. Merge, then separately: migrate the real config and update the launcher skill.
```
