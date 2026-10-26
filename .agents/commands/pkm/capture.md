---
description: Capture a thought or note to the PKM system
---

# PKM Capture

Capture the findings from this conversation into my Obsidian vault as a structured research note.

**Arguments**: $ARGUMENTS

**Vault path**: `/Users/jeff.diteodoro/o` — this is a known, fixed path. Do NOT search for it, glob for it, or ask the user where it is. Proceed directly.

---

## Process

Follow these steps in order. Do NOT explore the filesystem, search for the vault, or gather context beyond what is specified. The conversation history IS the input.

### Step 1: Synthesize from Conversation

Read back through the current conversation and extract:

- **Title**: Concise noun-phrase (e.g., "Staff MCP Server Access Control", "Django 4.2 Migration Options")
- **One-line summary**: What was researched and what was concluded
- **Context**: The triggering question or problem, any external links mentioned (Slack URLs, ticket IDs, file paths, PR links)
- **Findings**: The substantive research content — code references, architecture details, comparisons, trade-offs
- **Decision/Recommendation**: What was decided and why, or open questions if no decision was reached

If `$ARGUMENTS` were provided, use them as a hint for the title and topic focus.

If the conversation lacks clear research content, warn via `AskUserQuestion`: "This conversation doesn't seem to have a clear research outcome. Capture anyway?"

### Step 2: Identify Matching Project Hubs

Run: `ls "/Users/jeff.diteodoro/o/Project Hubs/"`

Check whether any hub filenames match the conversation topic by keyword. Hub files follow the pattern `Project - <Name>.md`.

### Step 3: Confirm Metadata via AskUserQuestion

Ask all confirmable metadata using `AskUserQuestion`. Batch into as few questions as practical.

1. **Title** — Present the synthesized title as the recommended option, plus 1-2 alternatives. "Other" is always available for free-text.

2. **Folder** — Options:
   - `AI Research/` — default for Claude Code research output
   - `Docs/` — how-to guides and reference material
   - `Investigations/` — debugging and troubleshooting trails
   - `Encyclopedia/` — concept definitions, "what is X" notes

3. **Project link** (only if Step 2 found matches) — Present matched Project Hub names plus "None". If no hubs matched, skip this question and omit `projects:` from frontmatter.

### Step 4: Handle Title Collisions

Check: `ls "/Users/jeff.diteodoro/o/<folder>/<Title>.md" 2>/dev/null`

If the file exists, ask via `AskUserQuestion`: "A note called `<title>` already exists." Options:
- "Append to existing note"
- "Create `<title> (2)`"
- "Pick a different title"

### Step 5: Write the Note

Get today's date: `date +%Y-%m-%d`

Write to `/Users/jeff.diteodoro/o/<folder>/<Title>.md` using this template:

```markdown
---
tags:
  - ai-research
source: claude-code
created: <YYYY-MM-DD>
projects:
  - "[[Project - <Name>]]"
---

<One-line summary of what was researched and the conclusion reached>

## Context

<Why this research was done — the triggering question or problem. Include links to Slack threads, tickets, file paths, etc. from the conversation.>

## Findings

<The substantive research — organized with headers, tables, code references as appropriate. Scale depth to match the conversation.>

## Decision / Recommendation

<What was decided or recommended and why. If no decision was reached, frame as open questions.>

## Next Steps

<Concrete action items identified during the conversation — tickets to file, code to write, people to talk to, follow-up research needed. Omit if none.>
```

**Frontmatter rules**:
- Always include `tags: ai-research` and `source: claude-code`
- Always include `created:` with today's date
- Include `projects:` only if a Project Hub was linked in Step 3. Use Obsidian wiki-link format: `"[[Project - <Name>]]"`
- If no project was linked, omit the `projects:` field entirely

**Content rules**:
- Scale depth to conversation depth — do not pad thin conversations with filler
- Preserve specific file paths, URLs, ticket IDs, and code references from the conversation
- Use headers, tables, and code blocks where they aid readability
- Omit sections that have no content (e.g., skip "Decision" if purely exploratory)

### Step 6: Confirm to User

Display:
- The file path that was written
- A brief preview showing the frontmatter and first section
- If a project was linked, note that it will appear in the Project Hub's Dataview query

## Quality Checklist

Before writing, verify:
- Title follows vault naming conventions (noun-phrase, no date prefix)
- Frontmatter is valid YAML
- Project link uses exact `[[Project - <Name>]]` format matching the hub filename
- External links from conversation are preserved
- Content is substantive (not just restating the question)
