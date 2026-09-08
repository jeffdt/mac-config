---
description: Capture a sanitized Granola note into a repo's meetings log
argument-hint: [search hint]
allowed-tools: Skill, mcp__granola__list_meetings, mcp__granola__get_meetings, AskUserQuestion, Read, Write, Bash(git rev-parse:*), Bash(git branch:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git checkout:*), Bash(git add:*), Bash(git commit:*), Bash(ls:*), Bash(mkdir:*)
---

# Granola → Repo Capture

Turn a Granola meeting note into a sanitized markdown file inside a project repo's
`meetings/` folder.

**Search hint:** $ARGUMENTS

## Step 1: Resolve the target repo

Not every project under `/Users/jeff.diteodoro/p/` is a git repository, so resolve by
path first and only fall back to git for repos nested deeper than one level:

- If the current working directory is `/Users/jeff.diteodoro/p/<project>` or a
  subdirectory of it, use `/Users/jeff.diteodoro/p/<project>` (the first path segment
  after `p/`) as the target repo.
- Otherwise, run: `git rev-parse --show-toplevel 2>&1`. If that succeeds and the
  resulting path is under `/Users/jeff.diteodoro/p/`, use it as the target repo.
- Otherwise, run `ls /Users/jeff.diteodoro/p` and ask via `AskUserQuestion` which project
  this note belongs to (list each subdirectory as an option). Use
  `/Users/jeff.diteodoro/p/<selected>` as the target repo.

## Step 2: Sanitize

Apply the `granola-sanitize` skill using **$ARGUMENTS** as the search hint. Returns a
cleaned markdown note (title, date, attendees, Key Points, Action Items).

## Step 3: Build the filename

- Slug: kebab-case the meeting title (lowercase; spaces and punctuation → single hyphens;
  strip leading/trailing hyphens).
- Filename: `<repo>/meetings/<meeting-date:YYYY-MM-DD>-<slug>.md` — use the meeting's own
  date from the cleaned note, not today's date.
- Run `mkdir -p <repo>/meetings`.

## Step 4: Handle collisions

Check: `ls <repo>/meetings/<filename> 2>/dev/null`

If it already exists, ask via `AskUserQuestion`: "A note called `<filename>` already
exists." Options:
- "Append to existing note" — append the new content under a `---` divider
- "Create `<slug> (2)`" — use that as the new filename
- "Pick a different title" — ask for a replacement slug

## Step 5: Write the file

Write to the resolved path:

```markdown
---
date: <meeting-date>
attendees:
  - <name>
  - <name>
---

<the cleaned note's body from Step 2, starting at "# <Meeting Title>">
```

## Step 6: Offer to commit

Ask via `AskUserQuestion`: "Commit this note now?" Options: "Yes, commit" / "No, leave it
staged". If yes, apply the `git-commit` skill (operating inside `<repo>`, not `~/.claude`).

## Step 7: Confirm

Tell the user the file path written, and whether it was committed.
