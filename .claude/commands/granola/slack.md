---
description: Sanitize a Granola meeting note and draft it into Slack
argument-hint: [search hint]
allowed-tools: Skill, mcp__granola__list_meetings, mcp__granola__get_meetings, AskUserQuestion, mcp__plugin_slack_slack__slack_search_channels, mcp__plugin_slack_slack__slack_search_users, mcp__plugin_slack_slack__slack_send_message_draft
---

# Granola → Slack

Turn a Granola meeting note into a sanitized Slack draft.

**Search hint:** $ARGUMENTS

## Step 1: Sanitize

Apply the `granola-sanitize` skill using **$ARGUMENTS** as the search hint. It resolves the
meeting, fetches the note, scans for candid/political commentary (asking you how to handle
anything it flags), and returns a cleaned markdown note (title, date, attendees, Key
Points, Action Items).

## Step 2: Pick the destination

- If a channel is named in the search hint text (e.g. "#product-team"), resolve it with
  `slack_search_channels`.
- If a person is named instead (a name, not a channel), resolve their user ID with
  `slack_search_users` and use that ID as the DM channel ID.
- Otherwise ask via `AskUserQuestion`: "Which channel or DM should this go to?"

## Step 3: Format for Slack

Rewrite the cleaned note using Slack conventions:
- `*bold*` instead of markdown `**bold**` or `#` headers
- A bold line as a section label (e.g. `*Key Points*`) followed by `-` bullets
- Keep it scannable: title line, then a `Date:` / `Attendees:` line (carried over from the
  cleaned note as-is), then Key Points, then Action Items (omit Action Items entirely if
  the note has none)

## Step 4: Draft, don't send

Call `slack_send_message_draft` with the formatted text and resolved channel/DM ID. Never
call `slack_send_message` from this command.

## Step 5: Confirm

Tell the user which channel/DM the draft was staged to, and that it's awaiting manual send.
