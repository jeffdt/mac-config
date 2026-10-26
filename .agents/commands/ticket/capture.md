---
description: Capture ideas from conversation context as Linear tickets
allowed-tools: Task, AskUserQuestion, Read
argument-hint: "[hint — numbered refs like '1 2 4', plain text like 'rate limiting', or empty]"
---

# Ticket Capture

Create Linear tickets from the current conversation context, following the `creating-tickets` skill standards.

**Arguments**: $ARGUMENTS

---

## Step 1: Parse the Hint

Determine what the user wants captured:

- **Empty arguments**: Scan the conversation for capturable items (findings, action items, deferred work, suggestions). If multiple candidates exist, list them numbered and ask via `AskUserQuestion` which to capture (multiSelect: true).
- **Numbered references** (matches `/^[\d\s,]+$/`, e.g., "1 2 4"): Match against the most recent numbered or bulleted list in the conversation. Extract those specific items.
- **Plain text** (e.g., "rate limiting"): Use as a topic hint to narrow extraction from the conversation.
- **Mixed** (e.g., "1 2 4 rate limiting"): Leading digits are item references; trailing text is a topic filter.

For each item identified, extract:
- The core idea (what needs to happen)
- Any rationale discussed in conversation
- Any constraints, concerns, or open questions mentioned
- Relevant specifics: file paths, service names, PR numbers, error messages

## Step 2: Draft Tickets

Read the `creating-tickets` skill and follow its standards. **The reader is a teammate opening the ticket cold months from now, not someone who sat in your session** — drop session-internal details (orchestration step IDs, "temper cycle", "item S5", bot names as actors, the discovery journey). Prefer short prose plus a tight AC list over a Goal / Scope / Non-goals template; see the skill's Bad → Good example.

For each captured item, draft:

1. **Title** — concise, PM-readable
2. **Description** — link reference (when there is one) + short prose stating the situation and action + a 2-3 bullet AC. See the skill for the Don't-include list and the Bad → Good example.
3. **Spec doc decision** — flag whether this item has enough conversational context to warrant a linked spec document. Default to skipping unless there's substantial context (constraints, architectural concerns, open questions, implementation breadcrumbs).

## Step 3: Discover Project, Milestone, and Labels

Launch a **single Task subagent** to infer the right project, milestone, and labels for these tickets:

```
You are identifying the correct Linear project, milestone, and labels for new tickets. Use the mcp__plugin_linear_linear__list_projects, mcp__plugin_linear_linear__list_milestones, and mcp__plugin_linear_linear__list_issues tools.

Team: AMPSS

Drafted tickets:
<include titles and brief descriptions>

Conversation context clues:
<include any project/feature/initiative names mentioned in conversation, plus the current git branch name if available>

Instructions:
1. Call list_projects with team: "AMPSS" to get all projects
2. Match drafted ticket topics against project names/descriptions. Consider conversation context and branch name as signals.
3. If a project is confidently matched, call list_milestones filtered to that project to find any active milestone
4. Call list_issues with project and team filters, limit: 15, to find recent tickets in the matched project. Collect their labels with frequency counts.
5. Based on ticket complexity, suggest a point estimate (1, 2, 3, 5, 8) for each drafted ticket

Return for each drafted ticket:
- Suggested project (name + ID), or "unclear" with top 2-3 candidates if ambiguous
- Suggested milestone (name + ID), or "none" if no active milestone
- Suggested labels (names) from project peers, with frequency context
- Suggested estimate (points) with brief rationale
- Confidence level (high/medium/low) for the project match
```

If any project match comes back as "unclear", present the candidates to the user via `AskUserQuestion` before proceeding.

## Step 4: Find Parent Tickets (only if requested)

**Skip this step unless** the user explicitly asked to attach to a parent ticket, named a specific parent issue, or the hint/arguments mention a parent. Most tickets are standalone.

If parent discovery is requested, launch a **single Task subagent** to search:

```
You are searching Linear for potential parent tickets. Use the mcp__plugin_linear_linear__list_issues tool.

Team: AMPSS

For each drafted ticket below, infer 1-2 broad keyword chunks from its domain/area and search for potential parent issues.

Drafted tickets:
<include titles and brief descriptions>

Instructions:
1. For each keyword chunk, call list_issues with team: "AMPSS", query: "<keyword>", limit: 10
2. Look for epic-style or parent-level issues that the drafted tickets could logically nest under
3. For each candidate parent, note: identifier, title, state, and any existing child count if visible
4. Return candidates grouped by which drafted ticket(s) they could parent
5. If no plausible parents found, say so explicitly
```

## Step 5: Confirm with User

Print a **full preview** for each drafted ticket using the YAML + markdown format from the `creating-tickets` skill's "Preview Before Save" section. One block per ticket, in order. The description body must be the exact string that will be sent to `save_issue` — do not abbreviate.

If a spec doc was flagged for a ticket, follow its preview block with a second block titled `Spec Document` containing the doc title and full markdown content.

If parent discovery was performed in Step 4, include `parent_candidates:` under each ticket's YAML frontmatter listing the candidates (this is informational; the actual parent selection happens below).

Use `AskUserQuestion` to confirm. Options:

1. **"Create all"** — creates tickets with project, milestone, and labels as shown, **without** estimate
2. **"Create all with estimates"** — creates tickets with everything including the suggested point estimates
3. **"Let me tweak first"** — returns to conversation for edits
4. **"Cancel"**

If parent discovery was performed in Step 4:
- Before the approve question, ask about **parent ticket selection** — present parent candidates plus "None / standalone". If all tickets share the same logical parent, allow a single selection for the batch.

If a parent is selected, launch a **Task subagent** to check sibling labels:

```
You are checking for label patterns on sibling tickets. Use mcp__plugin_linear_linear__list_issues.

Parent ticket: <identifier>

Instructions:
1. Call list_issues with parentId: "<identifier>", team: "AMPSS", limit: 20
2. Collect all labels used across sibling issues
3. Return label names with frequency counts, sorted by most common
```

If common labels are found, ask via `AskUserQuestion` whether to apply them.

## Step 6: Create Tickets

Call `mcp__plugin_linear_linear__save_issue` **directly in the main conversation** — do not use a Task subagent. The preview block printed in Step 5 sits in scrollback right above the permission prompt and acts as the user's read-friendly view of what's about to be sent.

For each approved ticket, in order:

1. Call `mcp__plugin_linear_linear__save_issue` with:
   - `title`, `team: "AMPSS"`, `description` (markdown), `priority: 3`
   - `state: "Triage"` and `assignee: null` — both required, do not omit or rely on defaults
   - `parent`, `labels`, `project`, `milestone`, `estimate` per the approved preview (omit fields that are null/none)

2. If a spec doc was flagged, call `mcp__plugin_linear_linear__create_document` with:
   - `title: "Spec: <ticket title>"`
   - `content` (markdown)
   - `issue: <identifier returned from save_issue>`

Capture the returned identifier, title, and URL for Step 7.

## Step 7: Report

For each created ticket, display the identifier as a markdown hyperlink so the user can cmd+click to open it:
- **[AMPSS-123](https://linear.app/...)**: Title (Ready, Normal)
  - Project: Project Name / Milestone Name
  - Parent: AMPSS-100 (if applicable)
  - Labels: label1, label2 (if applicable)
  - Estimate: 3 pts (if included)
  - Spec doc: linked (if created)

If multiple tickets were created, also show the count: "Created 3 tickets."
