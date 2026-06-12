---
description: Find a Linear ticket by keyword hint or conversation context
allowed-tools: Task
argument-hint: [hint]
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Recent commits: !`git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline 2>/dev/null`

## Input

User's hint: **$ARGUMENTS**

## Strategy

Linear's `query` parameter searches title and description but is **not fuzzy** — long multi-word phrases often return nothing. Use short, broad keywords instead.

### Mode selection

- **If $ARGUMENTS is non-empty:** use keyword search mode (below)
- **If $ARGUMENTS is empty:** use auto-find mode (below)

---

### Keyword search mode (with arguments)

The team defaults to **AMPSS** unless context suggests otherwise.

#### Deriving search terms

1. Break the hint into **1-2 word keyword chunks**. For example:
   - "tool call streaming insights service" → search for `"tool call"`, then `"streaming"`, then `"insights service"`
   - "SSE agent events" → `"SSE"`, then `"agent events"`

#### Searching

Launch a **single Task subagent** (`subagent_type: "general-purpose"`) with this prompt:

~~~
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
~~~

#### Output

Present results as a concise list:

- **AMPSS-123**: Title here (Status, Priority)
  Brief description summary

If multiple candidates match, present the top 3-5 and ask which one the user meant. If exactly one strong match, highlight it.

---

### Auto-find mode (no arguments)

Derive the relevant ticket from the pre-computed git context and conversation.

#### Signal extraction

Process signals in priority order:

1. **Ticket ID in branch name** (highest signal): If the branch name contains a Linear ticket pattern (e.g., `AMPSS-123`, `DATA-456`), extract it directly. Skip keyword search — go straight to a direct lookup via the subagent.

2. **Branch name keywords**: Strip the `jeffdt/` prefix. Handle both `jeffdt/domain/brief-id` and `jeffdt/domain-brief-id` formats. Split on `/`, `-`, `_`. Drop common filler words (add, fix, update, remove, refactor, service, system, module). Example: `jeffdt/insights/cache-ttl` → `insights`, `cache`, `ttl`.

3. **Commit messages**: Extract meaningful terms from the pre-computed commit log. Ignore conventional commit prefixes, file paths, and boilerplate.

4. **Conversation context**: Any ticket IDs, domain terms, or feature names visible in the current conversation. Note: when machine-invoked by `/gcpr`, this may be minimal — that's fine.

#### Edge cases

- **On `main` or branch name is empty**: No branch signal. Use commits + conversation only. If those are also empty, skip to manual input.
- **No commits on branch yet**: Use branch name + conversation only.
- **Branch name is just `jeffdt/domain`** (no description): Use the domain as the sole branch keyword.

#### Searching

Deduplicate keywords. Prioritize branch name terms. Form 1-2 word query chunks.

Launch a **single Task subagent** (`subagent_type: "general-purpose"`) with this prompt:

For **direct ticket ID** lookups:
~~~
You are looking up a specific Linear ticket. Use the mcp__plugin_linear_linear__list_issues tool.

Ticket identifier to find: <TICKET-ID>

Instructions:
1. Call mcp__plugin_linear_linear__list_issues with:
   - query: "<TICKET-ID>"
   - limit: 5
2. Find the exact match by identifier.
3. Return: identifier, title, state, priority, assignee.
4. If not found, say so.
~~~

For **keyword** searches:
~~~
You are searching Linear for a ticket related to the current branch's work. Use the mcp__plugin_linear_linear__list_issues tool.

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
   - Scan titles for relevance to the keywords.

3. Filter out tickets in Done or Cancelled states.

4. For each candidate issue, note:
   - Identifier (e.g., AMPSS-123)
   - Title
   - State (status)
   - Priority
   - Assignee (if any)
   - A one-line summary of the description if available

5. Return ALL candidate matches ranked by relevance. If no match found, say so.
~~~

#### Confidence heuristic and presentation

Based on the subagent's results:

- **Direct match** (ticket ID from branch name or commits, confirmed in Linear): Use it silently — just state "Linking `AMPSS-123: Title`" and proceed. No confirmation needed.
- **High confidence** (single strong keyword match — title overlaps with branch keywords, active state): If invoked by another command (e.g., `/gcpr`, `/pr:draft`), use silently. If invoked standalone, confirm with "Found `AMPSS-123: Title`. Is this the right ticket? (Y/n)".
- **Medium confidence** (2-3 plausible matches): Present as a numbered list. Ask the user to pick one, or type a ticket ID manually, or "none".
- **No matches**: Ask the user to enter a ticket identifier manually. "none" is accepted.

#### Output

The confirmed ticket identifier (e.g., `AMPSS-123`) or `none`.
