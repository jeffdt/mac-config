---
description: Start a refinery notes inbox so the user can jot standalone comments and questions, then hand them back to you as a batch
argument-hint: [hint]
allowed-tools: Bash(refinery:*)
---

# Start a refinery notes inbox

`refinery` is a local CLI + browser tool. This command opens its **notes
mode**: a browser page with no target document, just a composer where the
user can jot 1+ standalone comments or questions, one at a time, building a
list. You are the one who processes that list, this is not a multi-person
review tool, it's an alternative to the user typing numbered reactions into
chat.

If the user wants to review a specific document, use `/refinery:draft` for
something drafted in this conversation, or `/refinery:review` for a file
that already exists on disk; both render the document and support anchored
comments. This command is for feedback that doesn't pertain to any one
document.

## 1. Start the inbox

Derive a short title from `$ARGUMENTS` if given, otherwise use something
generic like the conversation's current topic. Run:

```
refinery notes --title "<title>"
```

If `refinery` is not found on `PATH`, tell the user to run `npm link` in
the refinery repo and stop, don't try to work around it another way.

## 2. Report back

Parse the command's output (`Review:`, `Round:`, `URL:`, `Comments file:`).
Reply with the URL and a one-line reminder: leave one or more notes in the
browser (each one is added to the list immediately), then run
`/refinery:next` when ready to hand them back.

Remember the review id and comments file path, you'll need them for
`/refinery:next` later in this conversation.
