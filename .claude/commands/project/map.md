---
description: Build or update the project navigation map
allowed-tools: Bash, AskUserQuestion, Write, Read, Glob, Grep, Agent
---

# Project Map

Build a progressive-disclosure navigation map for this project. The map is a routing system: agents read the short index at session start and drill into detail files only when needed.

**Arguments**: $ARGUMENTS

---

## Design Principles

- **The code is the source of truth.** Maps point agents toward it, not replicate it.
- **Cost scales with the task, not the project.** A bug fix in one area shouldn't load context about every area.
- **Freshness over completeness.** Directory paths and product-level concepts change far less often than individual files. Maps should reference what's stable.
- **High bar for inclusion.** Every line in a map should earn its place. The test: would an agent make a materially wrong plan without this?
- **No broken links.** Every link in a map file must point to something that exists. Generate targets before the files that reference them.

---

## Step 1: Detect Project

Run `pwd` to check if the cwd is under `~/Klaviyo/projects/<project>/`.

- **If yes**: Extract the project name from the path. Proceed.
- **If no**: Error — "Run this command from within a project directory (`~/Klaviyo/projects/<name>/`)."

---

## Step 2: Read Project Context

Read these files from the project root:

1. `CLAUDE.md` — project description and repo list
2. `.claude/settings.json` (and `.claude/settings.local.json` if it exists): parse `permissions.additionalDirectories` from both for the full list of repo paths
3. `project-map.md` — current index (if it exists)
4. All existing files in `map/` (if any exist)

---

## Step 3: Determine Mode

Parse `$ARGUMENTS` to decide the mode.

### No arguments → Full Map Generation

Generate the complete navigation system: detail maps, overview, and index. This is the primary mode — it produces a fully usable, self-consistent map in one pass.

#### Phase 1: Discover

Filter out repos that should always be skipped: `eng-handbook`. Then scan each remaining repo at a high level:
- Top-level directory structure (`ls`)
- READMEs and key config files (package.json, pyproject.toml, Makefile, Dockerfile, etc.)
- Service entry points

For each major area discovered, classify it as **repo-local** (lives primarily in one repo) or **cross-repo** (spans multiple repos).

**Cross-repo pattern discovery** — explicitly scan for these patterns across repos:

- **Shared auth protocols**: HMAC signing/verification, OAuth flows, token exchange, or shared secrets referenced in multiple repos
- **Client SDK dependencies**: one repo publishes a client library that another consumes as a pinned dependency (look for published packages, requirements files, version pins)
- **Proxy/gateway layers**: one service forwarding requests to another (look for HTTP proxying, SSE passthrough, request forwarding)
- **Shared data contracts**: DTOs, schemas, or API models imported or mirrored across repo boundaries
- **Shared infrastructure**: database connections, message queues, or caches accessed by multiple services

Cross-repo areas are often the most valuable entries in a project map because they can't be discovered from any single repo.

**Existing map awareness** — if `map/` contains files from a previous generation, compare the discovered areas against what already exists on disk. Flag areas that exist on disk but weren't rediscovered — they may have been removed, renamed, or the scan missed them.

#### Phase 2: Present for Approval

Show the user the full discovery results via `AskUserQuestion` before generating anything:

```
I found these areas:

Repo-local:
  ✓ <Area Name> (~/r/<repo>) — <one-line summary>
  ✓ ...

Cross-repo:
  ✓ <Area Name> (cross-repo) — <one-line summary>
  ✓ ...

[If applicable:]
Previously mapped but not rediscovered:
  ? <Area Name> — existed in map/<file>.md but wasn't found in scan

Add, remove, or rename any? I'll generate detail maps, overview, and index for all approved areas.
```

Wait for user confirmation. The user can add, remove, rename, or reclassify areas.

#### Phase 3: Generate

After approval, generate in this order to ensure no broken links:

**1. Detail maps** — one per approved area. Use subagents (`Agent` tool) to generate multiple detail maps in parallel where possible. Each detail map follows the format in "Detail Map Format" below. Present each map via `AskUserQuestion` for approval before writing.

**2. Overview** — read the detail maps just generated to synthesize the architecture diagram, key capabilities, and key gotchas. Present via `AskUserQuestion` before writing. Follow the format in "Overview Format" below.

**3. Index** — written last from the approved area list. All `map/` links are guaranteed to resolve because the files already exist. Follow the format in "Index Format" below. Include the overview link only if `map/_overview.md` was generated. No additional user approval needed — the index is mechanical.

---

### Hint is `overview` or `_overview` → Overview Mode

`_overview` is a reserved area name. This mode generates or updates the system-level mental model.

1. Read the index and all existing area maps in `map/` to understand the project's components.
2. Scan across repos for cross-cutting patterns (shared auth, common protocols, data flows between services).
3. Synthesize the architecture diagram, key capabilities, and key gotchas.

Follow the "Overview Format" below.

Present via `AskUserQuestion` before writing — the overview is highly subjective, so user validation is especially important here.

After writing, update `project-map.md` to include the overview link if it's not already there.

---

### Any other hint → Detail Mode

Generate or update a single area map. This mode is for incremental updates after the initial full generation.

Filter out always-skipped repos (`eng-handbook`) from the search scope. Then use the project context and the hint to search across remaining repos:
- Use Grep and Glob to find directories and files matching the hint (filenames, directory names, imports, references)
- Use Agent with `subagent_type: Explore` for deeper investigation of complex areas
- Focus on understanding the area **conceptually** — do not run broad directory scans or enumerate files

Follow the "Detail Map Format" below.

**Migration of existing maps**: when the skill encounters an existing area map in the old format (file inventories, "Key Files" / "Entry Points" / "Start Here" sections with directory listings), rewrite it in the new format. The old content informs the rewrite (e.g., file paths help identify the right search terms — what would you grep to find those files?) but is not preserved. Show the proposed rewrite via `AskUserQuestion` so the user can verify nothing important is lost.

If `map/<hint>.md` already exists in the new format, read it first and update rather than replace.

After writing the detail map, update `project-map.md` to add or refresh the area's row in the table.

Present the proposed changes to the user via `AskUserQuestion` before writing.

---

## Output Formats

### Index Format

```
# <Project Name> — Project Map

<1-2 sentence project description>

For system architecture and cross-cutting concerns, see [map/_overview.md](map/_overview.md).

| Area | Repo | Summary | Detail |
|------|------|---------|--------|
| <Area Name> | `~/r/<repo>` | <one-line summary> | [map/<area>.md](map/<area>.md) |
```

Rules:
- Include the overview link only if `map/_overview.md` exists.
- One line per area in the table. No multi-sentence summaries below the table.
- No architecture diagrams in the index (those live in the overview).
- For cross-repo areas, use `cross-repo` as the repo value, or list the primary repo if one dominates.

### Overview Format

```
---
area: overview
last-updated: YYYY-MM-DD
---

## Architecture

<ASCII diagram showing how components connect>

## Key Capabilities

Product-level features that span multiple areas. Each entry: what it is,
one sentence on how it works, which area maps it touches.

- **<Capability>** — <how it works>. Touches [area1](area1.md), [area2](area2.md).

## Key Gotchas

Things that would cause an agent to plan incorrectly if unknown.

- **<Gotcha>** — <why it matters and what to do about it>.
```

Inclusion bars:
- **Key Capabilities**: is this a product-level feature that spans multiple areas?
- **Key Gotchas**: would an agent make a materially wrong plan without knowing this? High bar — 2-4 items for a typical project.

### Detail Map Format

```
---
area: <area-name>
last-updated: YYYY-MM-DD
---

## What This Is

2-3 sentence conceptual description. What does this component do?
How does it relate to other components?

## Search Terms

- `<term>` in `<repo>` — <what this term leads to and why it's the right entry point>
- `<term>` — <what this term leads to> (no repo qualifier = search all project repos)

## Frameworks & Libraries

- <framework/library> — <why it matters or how it's used, if not obvious>

## Key Gotchas

- <gotcha> — <why it matters and what to do about it>
```

Rules:
- **What This Is**: conceptual, not exhaustive. What the component does and how it relates to the system.
- **Search Terms**: grep-able keywords that lead an agent to the right code. These are feature flags, config keys, unique identifiers, domain-specific names, or class names — not file paths. 3-6 terms per area. The test: "would grepping this term across the repo(s) land me in the right code within 1-2 hops?" Good terms are **stable** (costly to rename — e.g., feature flags, cookie names, API route prefixes) and **precise** (unique enough to avoid noise). Bad terms are generic (`handleSubmit`, `BaseController`) or fragile (method names that could be refactored without cross-system impact).
- **Frameworks & Libraries**: meaningful technology choices unlikely to change. Omit this section if everything is standard/obvious.
- **Key Gotchas**: area-specific constraints that violate reasonable assumptions. Same high bar as the overview: would an agent make a materially wrong plan without this? Omit this section if there are none.
- **Not included**: file paths, directory listings, function signatures, env var tables. The code has all of this and it's always current. Search terms find the code; paths go stale.

Gotcha deduplication: gotchas live at the lowest layer where they are relevant. Only promote to the overview if they would cause cross-area planning mistakes.

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
- Total number of areas mapped
- Any areas that were previously mapped but removed

---

## Anti-Patterns

These are guardrails. If you find yourself doing any of these, stop and reconsider.

- **File paths in area maps**: the code documents itself. Search terms find the code; directory listings and file paths go stale. If you catch yourself writing `path/to/file.py`, convert it to a grep-able search term instead.
- **Decision logs as history**: "we chose X over Y because Z" is commit history. Only surface decisions that change how you work.
- **Gotcha creep**: if an area has more than 3-4 gotchas, either the bar is too low or the area needs to be split.
- **Implementation details in the index**: "Redis-backed rate limiting" belongs in the code, not the index. The right level of abstraction: "MCP server for AI tool access."
- **Architecture diagrams in the index**: those belong in `map/_overview.md`, not `project-map.md`.
- **Broken links**: never reference a `map/` file that doesn't exist. Generate targets before the files that link to them.
- **Generating only the index**: if running in full map generation mode (no arguments), always generate the complete set — detail maps, overview, and index. A routing table with dead links is worse than no map at all.
