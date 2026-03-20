---
description: Capture a thought or note to the current project
allowed-tools: Bash(ls:*), Bash(pwd:*), Bash(date:*), AskUserQuestion, Write, Read
---

# Project Capture

Synthesize the current conversation into a concise project note.

**Arguments**: $ARGUMENTS

---

## Step 1: Detect Project

Run `pwd` to check if the cwd is under `~/Klaviyo/projects/<project>/`.

- **If yes**: Extract the project name from the path. Announce it and proceed.
- **If no**: Run `ls ~/Klaviyo/projects/` to list available projects. Infer which project best matches the conversation context (topics, repos, terminology). Present via `AskUserQuestion` with your best guess as recommended, plus other plausible options and "Other".

## Step 2: Synthesize

Read back through the conversation and distill the **essence** — not a transcript.

**Writing principles** (these are critical):

- **Be concise.** Capture the conclusion and reasoning, not the journey. A 3-line decision record is perfectly fine.
- **Infer structure from content.** No fixed template. A quick decision gets a sentence or two. A deep investigation gets a few sections. Let the content dictate the shape.
- **Omit empty sections.** If there's nothing to say about next steps, don't include a header for it.
- **Preserve specifics.** File paths, ticket IDs, URLs, commands, code references — these must survive.
- **No filler.** Short conversation = short note. Do not pad.

Extract:
- What was the question or problem?
- What did we conclude, and why?
- What specifics matter? (file paths, ticket IDs, URLs, code references, commands)

Infer a `type` from the content: `finding`, `decision`, `investigation`, `plan`, or `followup`.

## Step 3: Confirm Title

Infer a concise noun-phrase title (e.g., "Webhook Retry Backoff Strategy", "Auth Token Scope Reduction"). If `$ARGUMENTS` were provided, use as a hint.

Ask via `AskUserQuestion` with the recommended title, 1-2 alternatives, and "Other".

## Step 4: Check for Collisions

Check if `~/Klaviyo/projects/<project>/<title>.md` already exists.

If so, ask via `AskUserQuestion`:
- "Append to existing note"
- "Create with (2) suffix"
- "Pick a different title"

## Step 5: Write the Note

Get today's date: `date +%Y-%m-%d`

Write to `~/Klaviyo/projects/<project>/<title>.md`:

```markdown
---
type: <inferred type>
created: YYYY-MM-DD
---

<synthesized content>
```

The content below the frontmatter is free-form. Use headers, bullets, code blocks as the content warrants. Do not force a template — let the synthesis dictate the structure.

## Step 6: Confirm

Display:
- The file path written
- A brief preview: frontmatter + first paragraph
