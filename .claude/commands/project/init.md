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

List available repos, deduping git worktrees:
```bash
find -L ~/r -maxdepth 2 -name .git -type d -exec dirname {} \; | xargs -n1 basename | sort
```

This lists only primary checkouts. Worktrees (sibling `<repo>.<suffix>` dirs created by `wt` or the pr-review agent, e.g. `app.pr-review`, `k-repo.jeffdt-csa-search-prompt-fixes`) share their parent repo's working tree, so a plain `ls ~/r/` would list each one as a separate repo. A worktree's `.git` is a *file* (it points back to the main repo's `.git/worktrees/...`), while a primary checkout's `.git` is a *directory*, so `-type d` selects only the canonical checkouts. The `-L` is required because `~/r` is a symlink. If two selectable entries would still collide, prefer the bare repo name.

Present the list as a numbered multi-select via `AskUserQuestion`. Pre-check `eng-handbook`. Format like:

> Which repos should this project have access to? (comma-separated numbers)
>
> 1. [x] eng-handbook
> 2. [ ] repo-a
> 3. [ ] repo-b
> ...

Collect the selected repo names.

---

## Step 3: Select Permissions

Ask via `AskUserQuestion` with a checklist of common permissions. Pre-check `Bash(mdfind:*)` and `Bash(pbcopy:*)`:

> Which additional permissions? (comma-separated numbers)
>
> 1. [x] Bash(mdfind:*)
> 2. [x] Bash(pbcopy:*)
> 3. [ ] WebFetch(domain:*)
> 4. [ ] Bash(cat:*)

Collect the selected permissions.

---

## Step 4: Relevant Slack Channels

Ask via `AskUserQuestion` which Slack channels this project should treat as its defaults. At Klaviyo nearly every project has a dedicated `#proj-*` channel, so expect a project channel; still allow any field to be left blank.

Capture a handle and a short purpose for each of:

- **Team:** the squad/team discussion channel (e.g. `#ampss-eng`)
- **Project:** this project's dedicated channel, usually `#proj-<name>`
- **Other:** any additional relevant channels (incidents, stakeholders, or headless-run output, which defaults to `#jeffdt-automations` per global convention)

Do **not** resolve channel IDs now: that would require a Slack lookup at scaffold time and a Slack MCP dependency. IDs are backfilled lazily, the first time a Slack command needs one (resolve the handle, then write the ID back into `CLAUDE.md`).

Set `PROJECT_CHANNELS` from the response.

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

Write `~/Klaviyo/projects/<PROJECT_NAME>/.claude/settings.json` (the shared, committed starter config; anyone who clones the project inherits these permissions and repo directories, and personal overrides go in `.claude/settings.local.json` later, which stays gitignored):

```json
{
  "permissions": {
    "allow": [
      "<each selected permission>"
    ],
    "additionalDirectories": [
      "<~/r/REPO for each selected repo>"
    ]
  }
}
```

Use `~/r/<repo>` format for `additionalDirectories` (matching existing project conventions).

### 5c: `CLAUDE.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/CLAUDE.md`:

```markdown
# <PROJECT_NAME>

<PROJECT_DESC>

## Purpose

<PROJECT_PURPOSE>

## Repositories

<bulleted list of selected repos with paths>

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

### 5d: `.gitignore`

```bash
cp ~/.claude/templates/project/.gitignore ~/Klaviyo/projects/<PROJECT_NAME>/.gitignore
```

### 5e: `project-map.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/project-map.md`:

```markdown
# <PROJECT_NAME>: Project Map

<PROJECT_DESC>

> Run `/project:map` to generate the index, then `/project:map overview` for the system overview.
```

### 5f: `README.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/README.md` as the human front door (engineers open this first; `CLAUDE.md` is the agent-facing twin). Seed the **Slack channels** section from `PROJECT_CHANNELS`, identical to the block written into `CLAUDE.md`.

```markdown
# <PROJECT_NAME>

<PROJECT_DESC>

## Purpose

<PROJECT_PURPOSE>

## Repositories

<bulleted list of selected repos with `~/r/<repo>` paths>

## Slack channels

<same bullets as CLAUDE.md, seeded from PROJECT_CHANNELS; omit roles left blank>
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

See `CLAUDE.md` for the agent-facing orientation and `project-map.md` for codebase navigation.
```

### 5g: Git init

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
- Permissions granted
- Files and directories created

Suggest next steps:
1. `cd ~/Klaviyo/projects/<PROJECT_NAME>` and start a Claude session there
2. Run `/project:map` to generate repository navigation maps
