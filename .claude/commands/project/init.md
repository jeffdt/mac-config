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

List available repos:
```bash
ls ~/r/
```

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

## Step 4: Scaffold

Create the following structure under `~/Klaviyo/projects/<PROJECT_NAME>/`:

### 4a: `docs/plans/` and `map/` directories

```bash
mkdir -p ~/Klaviyo/projects/<PROJECT_NAME>/docs/plans
mkdir -p ~/Klaviyo/projects/<PROJECT_NAME>/map
```

### 4b: `.claude/settings.local.json`

Write `~/Klaviyo/projects/<PROJECT_NAME>/.claude/settings.local.json`:

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

### 4c: `CLAUDE.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/CLAUDE.md`:

```markdown
# <PROJECT_NAME>

<PROJECT_DESC>

## Purpose

<PROJECT_PURPOSE>

## Repositories

<bulleted list of selected repos with paths>

## Orientation

Read `project-map.md` to orient yourself. Do NOT read individual map files unless the task requires that area. Use the index to decide what's relevant, then drill in only as needed.

## Multi-Repo Planning Rules

This is a multi-repo project. All design specs and implementation plans MUST be organized around repo boundaries. These rules override default brainstorming and writing-plans behavior.

### Contract-First Development

Before any implementation details, define shared contracts between repos:
- API request/response schemas (JSON shapes, HTTP methods, status codes)
- Event payload schemas
- Shared type definitions
- Error contracts (error codes, error response format)
- Authentication/authorization expectations at boundaries

### Plan Structure

Specs and plans must be cleanly divided by repo so each can be handed to an independent Claude Code session with zero additional context.

Output structure in `superpowers/`:
```
{feature}-contracts.md      <- Shared schemas, API contracts (defined first)
{feature}-plan-overview.md  <- Sequencing, dependencies, integration test plan
{feature}-plan-{repo}.md    <- One per repo: self-contained implementation plan
```

### Per-Repo Plan Requirements

Each `{feature}-plan-{repo}.md` must be **fully self-contained**:
- References contracts by name from `{feature}-contracts.md` (includes relevant schemas inline)
- Includes all context needed without reading other repo plans
- Specifies exact file paths, function signatures, and test expectations
- Can be handed to a Claude Code session in `~/r/{repo}` as the sole input

### During Brainstorming

When exploring approaches and presenting designs, organize by repo boundary. Flag cross-repo dependencies explicitly. Identify which repo owns each contract.

### During Plan Writing

The writing-plans skill must produce the per-repo plan structure above instead of a single monolithic plan. Each repo plan follows the standard writing-plans task format (bite-sized steps, TDD, exact paths, complete code).
```

### 4d: `project-map.md`

Write `~/Klaviyo/projects/<PROJECT_NAME>/project-map.md`:

```markdown
# Project Map

> This map is empty. Run `/project:map` to generate navigation maps for this project's repositories.

## Index

<!-- Area maps will be listed here after running /project:map -->
```

---

## Step 5: Confirm

Display a summary of what was created:

- Project path
- Repos configured as additional directories
- Permissions granted
- Files and directories created

Suggest next steps:
1. `cd ~/Klaviyo/projects/<PROJECT_NAME>` and start a Claude session there
2. Run `/project:map` to generate repository navigation maps
