---
description: Scaffold a new project directory in the projects vault
allowed-tools: Bash(ls:*), Bash(mkdir:*), AskUserQuestion, Write, Read
---

# Project Init

Scaffold a new project working context in `~/Klaviyo/projects/`.

**Arguments**: $ARGUMENTS

---

## Step 1: Project Identity

If `$ARGUMENTS` contains a name, use it as the project name (kebab-case). Otherwise, ask via `AskUserQuestion`:

> What's the project name? (kebab-case, e.g. `billing-refactor`)
> A one-line description of what this project is about.
> And in a sentence or two: what's the purpose? Who is it for and what problem does it solve?

Set `PROJECT_NAME`, `PROJECT_DESC`, and `PROJECT_PURPOSE` from the response.

Check if `~/Klaviyo/projects/<PROJECT_NAME>/` already exists. If so, warn and ask whether to proceed or pick a different name.

---

## Step 2: Select Repositories

Present this fixed shortlist as plain text, not `AskUserQuestion`: the list can grow past its 4-option cap, and this list is meant to stay short and stable rather than mirror everything under `~/Klaviyo/Repos`.

> Which repos should this project have access to? Reply with comma-separated numbers, plus any additional repo names by hand.
>
> 1. eng-handbook
> 2. fender
> 3. app
> 4. k-repo
> 5. infrastructure-deployment

Collect the selected repos plus any freeform additions into `REPO_LIST`. Freeform entries should name a primary checkout (e.g. `k-ops-jarvis`), not a worktree sibling like `app.pr-review`: worktrees share their parent repo's working tree, so the primary checkout already covers them.

Use `~/Klaviyo/Repos/<repo>` as the canonical path in all generated files. (`~/r` is a legacy symlink to the same directory; don't write it into scaffolded output.)

---

## Step 3: Relevant Slack Channels

Ask via `AskUserQuestion` which Slack channels this project should treat as its defaults. At Klaviyo nearly every project has a dedicated `#proj-*` channel, so expect a project channel; still allow any field to be left blank.

Capture a handle and a short purpose for each of:

- **Team:** the squad/team discussion channel (e.g. `#ampss-eng`)
- **Project:** this project's dedicated channel, usually `#proj-<name>`
- **Other:** any additional relevant channel (incidents, stakeholders, etc.)

None of these have a default value: if the user leaves a field blank, omit it. Don't infer or suggest a specific channel unless the user names one.

Do **not** resolve channel IDs now: that would require a Slack lookup at scaffold time and a Slack MCP dependency. IDs are backfilled lazily, the first time a Slack command needs one (resolve the handle, then write the ID back into `AGENTS.md`).

Set `PROJECT_CHANNELS` from the response.

---

## Step 4: Project MCP Servers (optional)

Most MCP servers the user needs are already configured globally. This step is only for servers specific to *this project's* domain that should be shared with anyone who opens it, so keep it skippable and default to none.

Ask via `AskUserQuestion` (or plain text if the candidate list grows past 4):

> Does this project need any project-specific MCP servers in a shared `.mcp.json`? Common candidates based on typical stacks: Braintrust (evals), Chronosphere (observability), Buildkite (CI), Linear (issue tracking). Reply with any of these, other server names, or none.

Collect the response into `MCP_SERVERS` (may be empty).

---

## Step 5: Scaffold

Create the following structure under `~/Klaviyo/projects/<PROJECT_NAME>/`:

### 5a: Directories

```bash
mkdir -p ~/Klaviyo/projects/<PROJECT_NAME>/specs
mkdir -p ~/Klaviyo/projects/<PROJECT_NAME>/prompts
mkdir -p ~/Klaviyo/projects/<PROJECT_NAME>/research
mkdir -p ~/Klaviyo/projects/<PROJECT_NAME>/map
```

### 5b: `.claude/settings.json`

Write `~/Klaviyo/projects/<PROJECT_NAME>/.claude/settings.json` (the shared, committed starter config; anyone who clones the project inherits these repo directories, and personal overrides go in `.claude/settings.local.json` later, which stays gitignored):

```json
{
  "permissions": {
    "additionalDirectories": [
      "<~/Klaviyo/Repos/REPO for each selected repo>"
    ]
  }
}
```

### 5c: `AGENTS.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/AGENTS.md`. This is the vendor-neutral home for all agent-facing instructions; `CLAUDE.md` just imports it (5d) so other tools that read `AGENTS.md` natively see the same content without duplication. The personal, gitignored counterpart is `AGENTS.local.md` / `CLAUDE.local.md` (5e/5f).

```markdown
# <PROJECT_NAME>

<PROJECT_DESC>

## Purpose

<PROJECT_PURPOSE>

## Repositories

<bulleted list of selected repos with `~/Klaviyo/Repos/<repo>` paths>

## Slack channels

Default channels for this project; prefer these in Slack, research, and digest commands instead of guessing. Channel IDs are backfilled lazily: the first time you resolve a handle to its ID, add it here in backticks.

<for each channel captured in PROJECT_CHANNELS, one bullet; omit roles left blank:>
- **Team:** #<handle> (<purpose>)
- **Project:** #<handle> (this project's channel)
- **Other:** #<handle> (<purpose>)

<if no channels were captured, write instead:>
- _None recorded yet; add channels here as they come up._

## Important: This is a coordination repo, not a code repo

When asked to find or modify code, consult `project-map.md` first to identify which repo in `additionalDirectories` contains the relevant code. Do not search this directory for source code.

## Repo structure

- `specs/`: design specs with contracts (brainstorming output)
- `prompts/`: per-repo session prompts for repo-local agents
- `research/`: investigations, findings, point-in-time reference docs
- `map/`: codebase navigation maps (meta, consumed by Claude for project context)
- `artifacts/`: personal scratch docs (gitignored)
- `drafts/`: WIPs not ready for others (gitignored)

## Orientation

Read `project-map.md` to orient yourself. Do NOT read individual map files unless the task requires that area. Use the index to decide what's relevant, then drill in only as needed.

## Planning

Use `/project:plan` for all feature planning. It handles brainstorming, design specs with contracts, and per-repo session prompt generation. Implementation plans are created by agents in each repo, not here.
```

### 5d: `CLAUDE.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/CLAUDE.md` as a single-line import, no duplicated content:

```markdown
@AGENTS.md
```

### 5e: `AGENTS.local.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/AGENTS.local.md` (gitignored; personal, project-specific notes that shouldn't be shared with the team, e.g. sandbox URLs, local credentials, scratch preferences):

```markdown
# <PROJECT_NAME> (personal notes)

Personal notes for this project. Not committed to git.
```

### 5f: `CLAUDE.local.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/CLAUDE.local.md` as a single-line import (gitignored). Claude Code auto-loads `CLAUDE.local.md` alongside `CLAUDE.md` at session start, so no explicit import is needed elsewhere, this file just points at where the real content lives:

```markdown
@AGENTS.local.md
```

### 5g: `.gitignore`

```bash
cp ~/.claude/templates/project/.gitignore ~/Klaviyo/projects/<PROJECT_NAME>/.gitignore
```

### 5h: `project-map.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/project-map.md`:

```markdown
# <PROJECT_NAME>: Project Map

<PROJECT_DESC>

> Run `/project:map` to generate the index, then `/project:map overview` for the system overview.
```

### 5i: `README.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/README.md` as the human front door (engineers open this first; `AGENTS.md` is the agent-facing twin). Seed the **Slack channels** section from `PROJECT_CHANNELS`, identical to the block written into `AGENTS.md`.

```markdown
# <PROJECT_NAME>

<PROJECT_DESC>

## Purpose

<PROJECT_PURPOSE>

## Repositories

<bulleted list of selected repos with `~/Klaviyo/Repos/<repo>` paths>

## Slack channels

<same bullets as AGENTS.md, seeded from PROJECT_CHANNELS; omit roles left blank>
- **Team:** #<handle> (<purpose>)
- **Project:** #<handle> (this project's channel)
- **Other:** #<handle> (<purpose>)

## Key links

Fill in as the project gets going:
- Tickets:
- Dashboards:
- Docs / specs:

## Using this command center

This directory is the coordination hub; the code lives in the repos above. Drive it with:

- `/project:plan`: plan a feature across the repos (brainstorm, design spec with contracts, per-repo session prompts)
- `/project:map`: build or refresh the repo navigation map
- `/project:capture`: capture a thought or note into the project

See `AGENTS.md` for the agent-facing orientation and `project-map.md` for codebase navigation.
```

### 5j: `.mcp.json` (only if `MCP_SERVERS` is non-empty)

Write `~/Klaviyo/projects/<PROJECT_NAME>/.mcp.json` with one entry per selected server. Check `~/.claude.json` or the user's existing global MCP config first in case a matching server definition already exists to copy; otherwise consult the `plugin-dev:mcp-integration` skill for the correct shape (stdio/http/sse) and leave connection details (URL, command, auth) as clearly-marked placeholders for the user to fill in. Don't invent credentials or endpoints.

### 5k: Git init

```bash
cd ~/Klaviyo/projects/<PROJECT_NAME>
git init
git add -A
git commit -m "Initial project scaffold"
```

---

## Step 6: Confirm

Display a summary of what was created:

- Project path
- Repos configured as additional directories
- Slack channels recorded
- MCP servers configured (if any)
- Files and directories created

Suggest next steps:
1. `cd ~/Klaviyo/projects/<PROJECT_NAME>` and start a Claude session there
2. Run `/project:map` to generate repository navigation maps
