---
description: Start a refinery review so the user can leave inline feedback on something you just drafted, instead of typing reactions in chat
argument-hint: [hint]
allowed-tools: Bash(refinery:*), Write, Read
---

# Start a refinery draft review

`refinery` is a local CLI + browser tool: it renders a markdown draft in the
browser and lets the user leave inline anchored comments, general comments,
suggested rewrites, and discussion points, saved to a `comments.jsonl` file. You are the one
revising based on that feedback, this is not a multi-person review tool,
it's an alternative to the user typing reactions into chat.

If the user just wants to leave standalone comments or questions that don't
pertain to any one document, use `/refinery` (no subcommand) instead, that
opens a notes inbox with no draft to render. If the content to review
already exists as a file on disk rather than being drafted in this
conversation, use `/refinery:review <path>` instead, it points at that
file directly and writes revisions back to it.

## 1. Identify the content to review

Find the most recent piece of content you proposed in this conversation
(a Slack message, a plan excerpt, an email draft, peer feedback, anything).

If `$ARGUMENTS` is given, use it to disambiguate which piece of content is
meant (e.g. "the slack message about the outage"). If nothing recent is
obviously the target and no hint disambiguates it, ask the user which draft
they mean rather than guessing.

## 2. Write it to a scratch file

Write the content **verbatim as markdown** to a new file in the current
session's scratchpad directory (see your system prompt for the path; if
none is provided, use a suitable temp location). This file is only an
intermediate rendering surface for the review, it is not necessarily the
final deliverable format. Name it descriptively, e.g. `<topic-slug>-round-1.md`.

## 3. Start the review

Derive a short title from `$ARGUMENTS` if given, otherwise from the
content's topic. Run:

```
refinery review <scratch-file> --title "<title>"
```

If `refinery` is not found on `PATH`, tell the user to run `npm link` in
the refinery repo and stop, don't try to work around it another way.

## 4. Report back

Parse the command's output (`Review:`, `Round:`, `URL:`, `Comments file:`).
Reply with the URL and a one-line reminder: leave inline or general
comments in the browser, then run `/refinery:next` when ready for the next
round.

Remember the review id and comments file path, you'll need them for
`/refinery:next` later in this conversation.
