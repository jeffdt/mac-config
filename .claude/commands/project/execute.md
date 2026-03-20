---
description: Launch an agent team to execute per-repo implementation plans in parallel
allowed-tools: Read, Glob, Bash(ls:*), AskUserQuestion, TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, Agent
---

# Project Execute

Launch an agent team to implement a feature across multiple repos in parallel, with contract-change coordination through the user.

**Arguments**: $ARGUMENTS

---

## Step 1: Find Plan Files and Map Repos

### Discover plan files

Use `$ARGUMENTS` as a keyword to find plan files. Search both `superpowers/plans/` and `superpowers/`:

```
Glob("superpowers/plans/*{keyword}*.md")
Glob("superpowers/*{keyword}*.md")
```

If `$ARGUMENTS` is empty, glob `superpowers/plans/*.md` to find all plan files. Group files by shared prefix (strip the repo suffix — the last hyphen-delimited segment). Pick the most recently modified group and present it as a confirmation:

> Found plans for `{prefix}` targeting repos ({repo1}, {repo2}, …), last modified {date}. Execute these?

If the user says no, list all groups and ask which to execute.

### Identify per-repo plan files

Per-repo plan files share a common prefix and end with a repo-like suffix. Examples:
- `2026-03-19-system-prompt-experimentation-krepo.md` → suffix `krepo`
- `2026-03-19-system-prompt-experimentation-app.md` → suffix `app`

Extract the common prefix (the feature slug) and each repo suffix.

### Identify optional files

- **Contracts file**: look for `{prefix}-contracts.md` or `*{keyword}*contracts*.md`. If found, note its path. If missing, note "contracts inlined per-repo" and proceed.
- **Overview file**: look for `{prefix}-overview.md` or `*{keyword}*overview*.md`. If found, note its path. If missing, proceed without it.
- **Spec file**: look in `superpowers/specs/` for a file matching the keyword (e.g., `*{keyword}*design*.md` or `*{keyword}*.md`). If found, note its path — it may contain sequencing info and canonical contract definitions.

### Map repo suffixes to directories

For each repo suffix extracted from plan filenames:

1. List actual repo directories by running `ls ~/r/`
2. Try exact match first: suffix `app` → `~/r/app/`
3. If no exact match, fuzzy match by stripping hyphens: suffix `krepo` → compare `krepo` against `krepo` (from `k-repo` with hyphen stripped) → `~/r/k-repo/`
4. If still ambiguous or no match, ask the user via `AskUserQuestion`:

> Can't auto-map repo suffix `{suffix}` to a directory in `~/r/`. Which directory should I use?

Collect the final mapping: `{suffix}` → `{absolute directory path}`.

### Team name

Derive the team name by slugifying the feature keyword from `$ARGUMENTS` (lowercase, hyphens for spaces). For example, `system-prompt` becomes `system-prompt`. If no arguments were given, use the extracted common prefix (e.g., `system-prompt-experimentation`).

---

## Step 2: Read and Summarize

Read all plan files. Also read the spec file if one was found.

Present a summary to the user:

> **Feature:** {feature slug}
> **Team name:** {team-name}
> **Spec:** {spec file path, or "none found"}
> **Contracts:** {contracts file path, or "inlined per-repo"}
> **Repos:**
> - `{suffix}` → `{directory}` — `{plan file path}`
> - …
>
> All repos will implement in parallel. Ready to launch the team?

Wait for user confirmation before proceeding.

---

## Step 3: Create Team and Tasks

Create a team:

```
TeamCreate(team_name="{team-name}", description="Implementing {feature} across repos")
```

Create one task per repo (no dependency relationships — all parallel):

```
TaskCreate(subject="Implement {feature} in {repo}", description="Execute {plan file path}")
```

---

## Step 4: Spawn Teammates

For each repo, spawn a teammate using the Agent tool:

- **name**: `{repo-directory-name}` (e.g., `k-repo`, `app`, `fender`)
- **team_name**: `{team-name}`
- **subagent_type**: `general-purpose`
- **mode**: `plan` (require plan approval before implementation — the lead reviews and approves)

**Spawn prompt for each teammate:**

Build the prompt dynamically based on what files exist:

> You are implementing the `{feature}` feature in the `{repo}` repository.
>
> **Your working directory:** `{absolute repo directory path}`
>
> **Your implementation plan:** Read `{absolute path to plan file}`
>
> {IF contracts file exists: "**Shared contracts:** Read `{absolute path to contracts file}`"}
> {IF spec file exists: "**Design spec (for reference):** `{absolute path to spec file}`"}
>
> Your plan already contains the contract definitions for your repo's boundary. If you discover the contract needs to change, message the team lead immediately.
>
> You are a teammate on the `{team-name}` team. Read the team config at `~/.claude/teams/{team-name}/config.json` to discover your teammates.
>
> ## Instructions
>
> 1. Read your implementation plan {IF contracts file exists: "and the contracts file"}
> 2. Check TaskList for your assigned task and claim it
> 3. Follow the plan step by step — it has exact file paths, code, and test commands
> 4. **CRITICAL: Contract changes.** If you discover that a contract (API schema, event payload, error format) needs to change from what's defined in your plan, STOP and message the team lead immediately. Do NOT implement against a modified contract without lead approval. Explain what needs to change and why.
> 5. When your task is complete, mark it done via TaskUpdate and message the team lead with a summary
>
> ## Quality expectations
>
> - Follow TDD as specified in the plan
> - Commit after each logical unit of work
> - Run tests and verify they pass before marking complete

Spawn all teammates in parallel (no sequencing dependencies).

---

## Step 5: Coordinate

You (the lead) now enter coordination mode. Your responsibilities:

### Contract Change Requests
When a teammate reports a contract issue:
1. Surface it to the user with full context: what the teammate wants to change, why, and which other repos would be affected
2. Wait for the user's decision
3. If approved:
   - **If a standalone contracts file exists:** update it, then message ALL affected teammates with the specific change
   - **If contracts are inlined per-repo:** surface the exact change to the user, get approval, then message each affected teammate with the specific contract change (the exact field/schema diff). The teammates adapt their implementation based on the message.
   - **If a spec file exists:** update the spec's contracts section as a canonical record of the change
4. If rejected: message the requesting teammate with the reason and any alternative approach

### Plan Approval
Teammates run in `plan` mode. When they submit a plan for approval:
1. Review the plan against the per-repo plan file and contracts (whether standalone or inlined)
2. If it looks good, approve it
3. If it diverges from the plan or contracts, reject with specific feedback

### Progress
Periodically summarize team status to the user when asked or at natural milestones (e.g., when a repo completes).

### Completion
When all tasks are done:
1. Summarize what was implemented across all repos
2. Note any contract changes that were made during execution
3. If a spec file exists, suggest integration testing steps from it
4. Ask the user if they want to shut down the team
5. On confirmation, send shutdown requests to all teammates, then TeamDelete

---

## Error Handling

- If a teammate gets stuck or errors out, surface it to the user with context and ask how to proceed (respawn, skip, or intervene manually)
- If a teammate goes idle unexpectedly, check their task status and nudge them
- If the team needs to be stopped mid-execution, shut down all teammates gracefully before cleanup
