---
description: Find a Linear ticket by keyword hint or conversation context
allowed-tools: Task
argument-hint: [hint]
---

Find a Linear ticket matching the user's intent. The team defaults to **AMPSS** unless context suggests otherwise.

## Input

User's hint: **$ARGUMENTS**

## Strategy

Linear's `query` parameter searches title and description but is **not fuzzy** — long multi-word phrases often return nothing. Use short, broad keywords instead.

### Deriving search terms

1. If the user provided a hint, break it into **1-2 word keyword chunks**. For example:
   - "tool call streaming insights service" → search for `"tool call"`, then `"streaming"`, then `"insights service"`
   - "SSE agent events" → `"SSE"`, then `"agent events"`
2. If no hint was provided, infer the topic from the current conversation context and derive 1-2 keyword chunks the same way.

### Searching

Launch a **single Task subagent** (`subagent_type: "general-purpose"`) with this prompt:

```
You are searching Linear for a ticket. Use the mcp__plugin_linear_linear__list_issues tool.

Team: AMPSS
Keywords to try (in order): <list the 1-2 word keyword chunks>

Instructions:
1. For each keyword chunk, call mcp__plugin_linear_linear__list_issues with:
   - team: "AMPSS"
   - query: "<keyword>"
   - limit: 10
   Stop early if you find a clear match.

2. If no results from keyword searches, try a broader search:
   - team: "AMPSS" with no query, limit: 50, orderBy: "updatedAt"
   - Scan titles for relevance to the original topic.

3. For each candidate issue, note:
   - Identifier (e.g., AMPSS-123)
   - Title
   - State (status)
   - Priority
   - Assignee (if any)
   - A one-line summary of the description if available

4. Return ALL candidate matches ranked by relevance. If no match found, say so and suggest alternative search terms the user could try.
```

## Output

Present results as a concise list:

- **AMPSS-123**: Title here (Status, Priority)
  Brief description summary

If multiple candidates match, present the top 3-5 and ask which one the user meant. If exactly one strong match, highlight it.
