---
description: Build or update the project navigation map
allowed-tools: Bash, AskUserQuestion, Write, Read, Glob, Grep, Agent
---

# Project Map

Build a progressive-disclosure navigation map for this project. The map is a sieve: agents read the short index at session start and drill into detail files only when needed.

**Arguments**: $ARGUMENTS

---

## Guidelines

These govern how maps are written. Follow them strictly.

- **Progressive disclosure**: The index (`project-map.md`) must be useful on its own. Agents read ONLY the index at session start.
- **Concise index entries**: 1-2 sentences per area. Enough to decide "I need this" or "I don't."
- **Thorough detail maps**: File-by-file breakdowns with purpose, key functions/classes, and connections to other files.
- **Flat structure**: Each area gets one file in `map/`. No nesting.
- **Merge, don't overwrite**: Always read existing content before writing. Preserve what's there, update what's changed, add what's new.

---

## Step 1: Detect Project

Run `pwd` to check if the cwd is under `~/Klaviyo/projects/<project>/`.

- **If yes**: Extract the project name from the path. Proceed.
- **If no**: Error — "Run this command from within a project directory (`~/Klaviyo/projects/<name>/`)."

---

## Step 2: Read Project Context

Read these files from the project root:

1. `CLAUDE.md` — project description and repo list
2. `.claude/settings.local.json` — parse `permissions.additionalDirectories` for the full list of repo paths
3. `project-map.md` — current index (if it exists)

---

## Step 3: Determine Mode

Parse `$ARGUMENTS` to decide the mode.

### No arguments → Index mode

Filter out repos that should always be skipped: `eng-handbook`. Then scan each remaining repo at a high level:
- Top-level directory structure (`ls`)
- READMEs and key config files (package.json, pyproject.toml, Makefile, Dockerfile, etc.)
- Service entry points

For each major area discovered, write a 1-2 sentence summary and a link to `map/<area>.md`.

The index must be useful standalone — an agent reading ONLY this file should know which detail map to drill into for any given task.

If `project-map.md` already exists, merge new sections into it. Do not overwrite existing content that is still accurate.

Present the proposed changes to the user via `AskUserQuestion` before writing.

### With hint (e.g., `auth`, `notary`, `tools`) → Detail mode

Filter out always-skipped repos (`eng-handbook`) from the search scope. Then use the project context and the hint to search across remaining repos for relevant files:
- Use Grep and Glob to find files matching the hint (filenames, directory names, imports, references)
- Use Agent with `subagent_type: Explore` for deeper investigation of complex areas

Write `map/<hint>.md` with:

```
---
area: <hint>
last-updated: YYYY-MM-DD
---

## Overview

2-3 sentence summary of this area.

## Key Files

For each relevant file:
- **`<path>`** — Purpose. Key functions/classes. How it connects to other files.

## Entry Points

Where an agent should start reading to understand this area. Ordered by importance.
```

If `map/<hint>.md` already exists, read it first and update rather than replace.

After writing the detail map, update `project-map.md` to add or refresh the section linking to this area.

Present the proposed changes to the user via `AskUserQuestion` before writing.

---

## Step 4: Write

Ensure the map directory exists:
```bash
mkdir -p ~/Klaviyo/projects/<project>/map
```

Write the file(s) after user confirmation.

---

## Step 5: Confirm

Display:
- Which files were created or updated
- If detail mode updated the index, show a brief preview of the new index entry
