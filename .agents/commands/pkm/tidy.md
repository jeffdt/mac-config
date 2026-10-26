---
description: Tidy and organize PKM notes
---

# PKM Tidy

Review and organize notes in my Obsidian vault at `/Users/jeff.diteodoro/o`.

**Arguments**: $ARGUMENTS

## Argument Parsing

- No args → recent 10 days (default for weekly cadence)
- Number only (e.g., `7`) → recent N days
- `stale` → 10 oldest-modified root notes (for deep cleaning)
- `stale N` (e.g., `stale 15`) → N oldest-modified notes

## Folder Structure

| Folder | Purpose |
|--------|---------|
| `Daily/` | Daily notes (auto-filed via template) |
| `Weekly/` | Weekly rollups |
| `Monthly/` | Monthly rollups |
| `Quarterly/` | Quarterly summaries |
| `Meetings/` | Meeting notes, pattern: `YY-MM-DD - Title.md` |
| `Tickets/` | Linear ticket notes (auto-filed via template) |
| `Project Hubs/` | Project tracking pages, pattern: `Project - Name.md` |
| `RFCs/` | RFC documentation |
| `Investigations/` | Troubleshooting/debugging notes, pattern: `Investigation - Title.md` |
| `Incidents/` | Incident postmortems |
| `Oncall Rotation/` | On-call rotation notes |
| `People/` | Person notes |
| `Docs/` | How-to guides, reference data, commands, snippets |
| `Encyclopedia/` | Concept definitions, "what is X" notes, team/tool descriptions |
| `Career/` | Performance reviews, peer feedback |

## Instructions

1. **Parse arguments** to determine mode:
   - Default: recent 10 days
   - If arg is a number: recent N days
   - If arg starts with `stale`: oldest-modified notes (default 10, or specified count)

2. **Count root-level notes**: `ls -1 /Users/jeff.diteodoro/o/*.md | wc -l`

3. **Get notes based on mode**:
   - **Recent mode**: `find /Users/jeff.diteodoro/o -maxdepth 1 -name "*.md" -mtime -<days> -type f`
   - **Stale mode**: `ls -1t /Users/jeff.diteodoro/o/*.md | tail -<count>` (oldest mtime first)

4. **Read each note** and categorize based on content:
   - **Empty/stub** (1-2 lines, no real content) → Suggest deletion
   - **Meeting notes** (dated, has attendees/agenda) → `Meetings/`
   - **Project work** (has tasks, tagged `projects`, ongoing work) → `Project Hubs/`
   - **Investigation/troubleshooting** (debugging, research, command trails) → `Investigations/`
   - **How-to/reference** (commands, snippets, procedures, reference data) → `Docs/`
   - **Concept/definition** (explains what something is, short descriptions) → `Encyclopedia/`
   - **One-off event notes** (hackathons, training) → Keep at root or ask
   - **Ongoing logs** (office hours, recurring activity) → Keep at root

5. **Present recommendations** in a table:
   ```
   | # | File | Content Summary | Recommendation |
   ```

6. **Handle ambiguity**: If a note could reasonably go to multiple places, use the `AskUserQuestion` tool to clarify. Present the options with brief explanations of why each might fit.

7. **Ask for confirmation** before making changes

8. **Execute changes**:
   - Use `mv` for file moves
   - For Project Hubs: add proper frontmatter with `project-hub` tag and Dataview query
   - For notes needing project association: add `projects:` frontmatter
   - Delete confirmed empty files with `rm`
   - **For notes kept at root**: Add or update `reviewed:` field in frontmatter with today's date. This bumps the mtime so the note won't be selected again until others are reviewed.

9. **Report progress**: Show count before/after and list of changes made

## Updating `reviewed:` Frontmatter

Get today's date with: `date +%Y-%m-%d`

When keeping a note at root, ensure it has frontmatter with a `reviewed:` date:

**If no frontmatter exists**, add at the top of the file:
```yaml
---
reviewed: <output of date +%Y-%m-%d>
---
```

**If frontmatter exists**, add or update the `reviewed:` field within the existing frontmatter block.

This ensures stale mode cycles through all root notes over time.

## Project Hub Template

When creating/updating a Project Hub, ensure it has:
```yaml
---
aliases:
tags:
  - project-hub
---

# Related Notes
\`\`\`dataview
LIST
FROM [[]] OR ""
WHERE contains(projects, this.file.link)
SORT file.name ASC
\`\`\`

# Notes
```

## Tips

- Notes at root aren't necessarily wrong - some belong there (Lost and Found, ongoing logs)
- Naming patterns matter for consistency within folders
- Check for existing Project Hubs before creating new ones
- Investigation notes are for troubleshooting trails and command experiments, not polished guides
