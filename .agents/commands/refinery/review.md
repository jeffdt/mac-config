---
description: Start a refinery review against a markdown file that already exists on disk, so revisions are written back to that same file
argument-hint: <path-to-markdown-file>
allowed-tools: Bash(refinery:*), Bash(realpath:*)
---

# Review an existing doc in place

`refinery` is a local CLI + browser tool: it renders a markdown draft in the
browser and lets the user leave inline anchored comments, general comments,
suggested rewrites, and discussion points, saved to a `comments.jsonl` file.
This command points it at a **real file that already exists on disk**
(a spec, a plan, notes in Obsidian, anything), instead of content drafted in
this conversation. Revisions you make while handling `/refinery:next` for
this review are written directly back to that file, every round, there is
no separate scratch file as the deliverable (refinery still snapshots a
copy into each round's directory for its own diffing, but that copy is
never what you edit or read from).

If the content to review was drafted in this conversation rather than
already living in a file, use `/refinery:draft` instead. If the user just
wants to leave standalone comments or questions, use `/refinery` (no
subcommand).

## 1. Resolve the path

`$ARGUMENTS` is the path to review. If it's empty, ask the user for the
path, don't guess.

Resolve it to an absolute path:

```
realpath "$ARGUMENTS"
```

If `realpath` reports the file doesn't exist, tell the user and stop.

## 2. Start the review

Derive a short title from the file's basename (strip the extension,
replace `-`/`_` with spaces) unless the user gave you one explicitly. Run:

```
refinery review "<absolute-path>" --title "<title>" --in-place
```

If `refinery` is not found on `PATH`, tell the user to run `npm link` in
the refinery repo and stop, don't try to work around it another way.

## 3. Report back

Parse the command's output (`Review:`, `Round:`, `URL:`, `Comments file:`,
`Source:`). Reply with the URL and a one-line reminder: leave inline or
general comments in the browser, then run `/refinery:next` when ready for
the next round. Also tell the user plainly that revisions will be written
directly to `<path>` itself, not to a separate copy.

Remember the review id, comments file path, and source path (the
`Source:` line), you'll need all three for `/refinery:next` later in this
conversation.
