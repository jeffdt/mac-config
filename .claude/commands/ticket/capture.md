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

Read the `creating-tickets` skill and follow its standards. For each captured item, draft:

1. **Title** — concise, PM-readable
2. **Description** — rationale (if non-obvious) + acceptance criteria + source context line
3. **Spec doc decision** — flag whether this item has enough conversational context to warrant a linked spec document. Default to skipping unless there's substantial context (constraints, architectural concerns, open questions, implementation breadcrumbs).

## Step 3: Find Parent Tickets (only if requested)

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

## Step 4: Confirm with User

Present all drafted tickets in a **batch table**:

| # | Title | Rationale | AC (count) | Spec Doc? |
|---|-------|-----------|------------|-----------|

If parent discovery was performed in Step 3, add a "Suggested Parent" column and list the candidates below the table.

Use `AskUserQuestion` to confirm:

1. **Parent ticket selection** (only if Step 3 was performed) — For each drafted ticket, present parent candidates plus "None / standalone". If all tickets share the same logical parent, allow a single selection for the batch.

2. **Approve the batch** — Options: "Create all", "Let me tweak first" (returns to conversation for edits), "Cancel"

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

## Step 5: Create Tickets

For each approved ticket, launch a **Task subagent**:

```
You are creating a Linear ticket. Use mcp__plugin_linear_linear__save_issue and optionally mcp__plugin_linear_linear__create_document.

Create this ticket:
- Title: <title>
- Team: AMPSS
- Description (markdown): <description>
- Priority: 3
- State: Backlog
- Parent: <identifier or "none">
- Labels: <labels or "none">

<If spec doc flagged>
After creating the issue, create a linked document:
- Use mcp__plugin_linear_linear__create_document
- Title: "Spec: <ticket title>"
- Content (markdown): <spec doc content>
- Issue: <the identifier returned from save_issue>
</If>

Return: the issue identifier (e.g., AMPSS-123), title, URL, and whether a spec doc was created.
```

## Step 6: Report

For each created ticket, display the identifier as a markdown hyperlink so the user can cmd+click to open it:
- **[AMPSS-123](https://linear.app/...)**: Title (Backlog, Normal)
  - Parent: AMPSS-100 (if applicable)
  - Labels: label1, label2 (if applicable)
  - Spec doc: linked (if created)

If multiple tickets were created, also show the count: "Created 3 tickets."
