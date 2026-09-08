---
description: Pick up feedback left in a running refinery review and start the next round
argument-hint: [hint]
allowed-tools: Bash(refinery:*), Bash(cp:*), Bash(git diff:*), Read, Write, Edit
---

# Continue a refinery review

## 1. Find the active review

Look back in this conversation for the most recent `Review:` / `Comments
file:` reported by `/refinery`, `/refinery:draft`, `/refinery:review`, or a
prior `/refinery:next`. If you can't find one, tell the user to run
`/refinery`, `/refinery:draft`, or `/refinery:review` first and stop, don't
guess at a review id.

If `$ARGUMENTS` is given and multiple reviews are active in this
conversation, use it to disambiguate which one.

## 2. Check the review's mode

Read `meta.json` at the review's root directory (two levels up from the
comments file: the comments file is `<review-dir>/round-N/comments.jsonl`,
so meta is `<review-dir>/meta.json`). Its `mode` field is `"draft"` or
`"notes"` (missing means `"draft"`, for reviews created before this field
existed). This determines which of the two flows below you follow.

If `mode` is `"draft"`, also check for a `sourcePath` field. When present,
this review was started with `/refinery:review` against a real file on
disk, revisions in step 5 and the next round in step 7 apply to that file
directly rather than a new scratch file.

## 3. Read the feedback

Read the comments file directly. If it's missing or empty, tell the user
there's no feedback there yet and stop, never invent a revision from
nothing.

Each line is a JSON object:
- `body`, the feedback text.
- `anchorText` / `contextBefore` / `contextAfter`, where in the draft the
  comment is anchored; `null` means a general (non-anchored) comment, which
  is always the case in notes mode.
- `kind`, one of:
  - `comment`: a point to weigh while revising (draft mode) or an item to
    act on (notes mode).
  - `rewrite`: treat `body` as a near-literal rewrite request, not just a
    point to weigh. In notes mode this means "here's the exact wording I
    want," not a literal span rewrite.
  - `discuss`: the user wants an answer from you, not an edit or an action.

Older comment files have no `kind`. Read those as `rewrite` when
`isSuggestion` is `true` and `comment` otherwise.

## 4. Answer any discussion points first

If **any** comment in the round has `kind: 'discuss'`, answer every one of
them in chat and then stop. Do not revise the draft (draft mode) or act on
the other items (notes mode), not even for the plain `comment` and `rewrite`
items in the same round. Wait for the user to tell you to proceed.

Someone raising a discussion point hasn't decided what they want changed
yet, so acting first would put words in their mouth they never chose. Quote
the `anchorText` you're answering about when there is one (draft mode), or
quote the note's `body` (notes mode), so it's clear which point each answer
belongs to.

If there are no `discuss` comments, skip straight to step 5.

## 5. Handle the remaining items

### The scope rule, for both draft-mode branches

**Revise only what the feedback asks you to revise.** Every sentence no
comment touched must come through the round byte-identical. Do not
re-word, re-order, tighten, or "improve" prose on your own initiative, and
do not restructure sections nobody complained about. A round is a patch,
not a rewrite.

This matters more than it sounds. The user reads the next round through a
diff, so every unrequested edit is noise they have to read past to find
the change they actually asked for. Enough of them and the diff becomes
unusable and the round is wasted.

If following a comment honestly requires a change wider than the comment's
own anchor (a renamed concept used in nine other places, a section that
contradicts the new text), make that wider change, then say so explicitly
in step 8 so the user knows why the diff is bigger than they expected.

**If `mode` is `"draft"` and `sourcePath` is absent:** do not write the
next draft from scratch. Copy the previous round's draft to the new
scratch path first, so the starting point is byte-identical:

```
cp "<review-dir>/round-<N>/drafts/<slug>.md" "<new-scratch-file>"
```

`<N>` is the round you just read feedback from and `<slug>` comes from
`draftNames` in `meta.json`. Then apply the feedback to that copy with the
Edit tool, one targeted edit per point. Keep working in markdown as the
review surface, the eventual target format (Slack message, email, plain
text, whatever it really is) only matters once the user says they're done
reviewing.

**If `mode` is `"draft"` and `sourcePath` is present:** read the file at
`sourcePath` first, its contents are not already in this conversation,
then edit it directly with the Edit tool per the feedback. This is the
user's real file, there is no separate "final format" to produce later,
the file itself is the deliverable.

**If `mode` is `"notes"`:** work through each remaining note as its own
small task in the conversation: answer it, make an edit, run something,
whatever it actually asks for. There's no single artifact being revised
here, so this is the same thing that would have happened if the note had
been typed directly into chat.

## 6. Check the diff before opening the round

Draft mode only, skip this in notes mode. Before running any `refinery`
command, diff what you're about to publish against what the user last read:

```
git diff --no-index "<review-dir>/round-<N>/drafts/<slug>.md" "<revised-file>"
```

Read the full output, not just the stat line, and check every changed hunk
against a comment that asked for it.

**If you find hunks no comment asked for, revert them** before opening the
round. Reverting is nearly always the right move: unrequested edits are
noise in the user's diff, and if one of them was genuinely worth making you
can raise it in chat instead, where it costs the user one sentence to read
rather than a hunk to decode.

Judge each hunk by whether a comment asked for it, never by how much of the
diff it accounts for. A section the user told you to move is not unrequested
churn, however wide it looks: `git diff` has no move detection, so it bills
every relocated line twice, once as a deletion and once as an insertion. A
reordering you were asked for is a clean round with a big stat line.

## 7. Start the next round

**If `mode` is `"draft"` and `sourcePath` is absent:** run, with the
revised scratch file from step 5 (same directory convention as
`/refinery:draft`, next round number):

```
refinery review <new-scratch-file> --continue <review-id>
```

**If `mode` is `"draft"` and `sourcePath` is present:** run:

```
refinery review "<sourcePath>" --continue <review-id>
```

Same path every round, refinery re-reads whatever's on disk there now, no
scratch file involved.

**If `mode` is `"notes"`:** run:

```
refinery notes --continue <review-id>
```

This opens a fresh, empty round, the previous round's notes stay on disk as
a record of what was said, but the page the user sees is a clean slate for
the next batch.

### If a refinery command fails

Print its error output verbatim, tell the user the round did not open, and
stop. Never re-run a failed `refinery` command with different arguments, an
added flag, or a quietly narrowed draft to get it through. The error is
addressed to the user as much as to you, and routing around it is how a round
they would have rejected gets published anyway.

## 8. Report back

Reply with the new URL and round number. Remember them for the next
`/refinery:next`. If you made any change wider than the comment that
prompted it, name it here in a sentence so the user isn't surprised by it
in the diff.

## Wrapping up

There's no dedicated close-out command. In draft mode without a
`sourcePath`, when the user says something like "ship it" or "that's the
one," treat the current round's content as final and produce it in its
real target form, the scratch `.md` file was never the deliverable. In
draft mode with a `sourcePath`, there's nothing further to produce, the
file has been the deliverable all along. In notes mode there's no
deliverable format to produce; the conversation itself is where the work
happened.
