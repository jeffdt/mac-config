---
name: granola-sanitize
description: This skill should be used when a slash command needs to resolve a Granola meeting from a search hint, fetch its note (private notes + AI summary), scan it for candid or political commentary, and produce a cleaned markdown note ready to share internally. Invoked explicitly by /granola:slack and /granola:capture — not intended to trigger on its own from general conversation about Granola or meetings.
---

> Generated from ~/.agents/skills/granola-sanitize/SKILL.md. Do not edit this copy directly.
> Edit the source under ~/.agents, then run agents-publish.

# Granola Sanitize

Resolves a Granola meeting from a search hint, fetches its note, and produces a cleaned version safe to share internally — flagging (not silently stripping) anything that reads as candid or political commentary.

**Input:** a search-hint string provided by the calling command (keyword, date, or attendee fragment).

**Output:** a cleaned markdown note in this exact shape, handed back to the caller:

```markdown
# <Meeting Title>
**Date:** <YYYY-MM-DD>
**Attendees:** <name>, <name>, ...

## Key Points
- ...

## Action Items
- ...
```

## Step 1: Resolve the Meeting

Call `mcp__granola__list_meetings` with `time_range: "last_30_days"`. Match the search hint against each meeting's title, date, and attendees using case-insensitive substring matching.

**If no match is found:** retry once with `time_range: "custom"`, setting `custom_start` to 365 days before today and `custom_end` to today. If still no match, tell the user no meeting matched the hint and stop — do not guess.

**If exactly one match is found:** proceed with that meeting.

**If multiple plausible matches are found:** ask the user via `AskUserQuestion`, listing each candidate's title and date, and let them pick.

## Step 2: Fetch the Note

Call `mcp__granola__get_meetings` with `meeting_ids: [<resolved meeting's ID>]` (the tool requires an array, even for one meeting). This returns the private notes, AI-generated summary, attendees, and metadata — the actual content that would be shared. Do not call `mcp__granola__get_meeting_transcript`; the raw transcript is out of scope for this skill.

## Step 3: Scan for Candid/Political Commentary

Read through the fetched note content. Flag passages that:
- State a blunt personal opinion about a specific named person or team
- Sharply criticize a decision, plan, or person in a way that reads as said-in-the-room rather than intended for broader circulation
- Otherwise read as candid/off-the-record commentary rather than a neutral summary of what was discussed or decided

If nothing matches, skip directly to Step 5 — do not add commentary about "no issues found," just proceed.

## Step 4: Flag and Resolve

For each flagged passage, quote it back to the user and ask via `AskUserQuestion` how to handle it:
- **Remove** — drop the passage entirely from the cleaned note
- **Soften** — rewrite it as a neutral paraphrase that preserves the substance without the candid framing
- **Leave as-is** — keep the original wording

Batch multiple flagged passages into as few `AskUserQuestion` calls as practical (multiple questions in one call) rather than one round-trip per passage.

## Step 5: Produce the Cleaned Note

Assemble the final markdown note in the shape given above under **Output**, using the meeting's actual date (not today's date) and the substantive discussion points and decisions after applying any Step 4 edits. Omit the Action Items section entirely if the note has none.

Hand this note back to the calling command. Do not format it for any particular destination (no Slack markdown, no frontmatter) — that's the calling command's job.
