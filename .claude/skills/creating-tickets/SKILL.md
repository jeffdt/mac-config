---
name: creating-tickets
version: 1.0.0
description: "This skill should be used when creating Linear tickets — whether from /ticket:capture, manually, or any workflow that needs to file a new issue. Encodes standards for title, description, acceptance criteria, and optional spec documents."
---

# Creating Tickets

Standards for creating well-formed Linear tickets. Any command or workflow that creates tickets should follow these conventions.

## Ticket Anatomy

### Title

- Concise noun-phrase or imperative verb-phrase
- Understood at a glance by a PM scanning a crowded backlog
- No ticket prefixes, no trailing punctuation
- Good: "Add rate limiting to inference API", "SSE reconnection drops events", "Upgrade PydanticAI to v2"
- Bad: "Rate limiting", "Fix the thing", "AMPSS: We need to add rate limiting to the inference API endpoint"

### Description

The description is the **human-readable view**. The reader is a teammate opening the ticket cold months from now, not someone who sat in your Claude session.

**Writing principles:**
- Be concise. Capture the conclusion, not the journey.
- For short tickets (follow-ups, small fixes), two paragraphs of running prose usually beat a Goal / Scope / AC / Non-goals template.
- Include rationale only when the "why" isn't obvious from the title. "Add rate limiting" is self-explanatory. "Upgrade PydanticAI" needs a sentence on why.
- Preserve specifics: file paths, service names, ticket IDs, URLs, error messages.
- Trust the reader. They're a competent engineer; don't spell out implications.

**Don't include:**
- Session orchestration artifacts: "temper cycle", "item S5", "cycle 3", step IDs from a Claude loop
- The discovery narrative: "Cursor Bugbot flagged X", "we tried Y then reverted Z", "before the PR the counter was uniform"
- Bot or tool names as actors without context — state the issue directly, not the story of how it surfaced
- Heavy section scaffolding (Goal / Scope / Non-goals / Acceptance Criteria headings) on a small follow-up
- Anything that reads as "what happened in my Claude session"

**Acceptance criteria:**
- Always include explicit AC as a short bulleted checklist — concrete, testable, captures intent not implementation
- Scale to the ticket: a follow-up gets 2-3 bullets, a feature gets more. Don't pad to look thorough; don't skip them either
- The AC pins down "done". Even when the action paragraph implicitly says it, a short list helps the reader scan and the implementer self-verify

**Source context:**
- For follow-ups to existing work, lead with a one-line link reference at the top: `Follow-up from AMPSS-230 / PR #29064.`
- Otherwise, a one-line reference at the bottom works: "Captured from PR review of #456", "From #eng-platform thread"
- Omit entirely when there's no shareable link — local conversation summaries don't help readers

### Description: Bad → Good

A real before/after for the same captured item, illustrating the rules above.

**Bad** (heavy scaffolding, session narrative, bot actor, journey instead of conclusion):

```
Follow-up from AMPSS-230 / PR #29064.
In that PR's temper cycle, item S5 added an error_type tag to chat_tool_execution_error
on the MCP proxy paths in insights_service/server/agent.py:
  timeout branch → {"tool": name, "error_type": "timeout"}
  generic Exception branch → {"tool": name, "error_type": "other"}

Cursor Bugbot flagged that this introduced a dimensional mismatch with the local tool
error paths (generate_file, retrieve_file, design_html_report), which still emit
{"tool": name} only. PromQL queries grouping by error_type would have silently dropped
local-tool errors. Before the PR the counter was uniform; S5 created the inconsistency.

To keep PR #29064 tightly scoped to the timeout-handling fix, we reverted S5 in cycle 3
— the counter is back to {"tool": name} everywhere...

Goal
Add a coherent error_type dimension across all chat_tool_execution_error emissions...

Scope
  [long bulleted list]

Acceptance Criteria
  [long bulleted list]

Non-goals
  [bullets]
```

**Good** (link-led, two paragraphs of prose, then a tight AC list):

```
Follow-up from AMPSS-230 / PR #29064.

chat_tool_execution_error in insights_service/server/agent.py is emitted from the MCP
proxy and from 3 local tool paths (generate_file, retrieve_file, design_html_report).
All call sites currently tag with {tool} only, so PromQL can't group failures by
category.

Add an error_type dimension to every call site with a small shared taxonomy
(e.g. timeout, mcp_other, local_tool or per-tool labels). Update tests in
tests/test_metrics.py.

Acceptance criteria:
- Every chat_tool_execution_error.add() call passes both `tool` and `error_type`
- tests/test_metrics.py covers each error_type value
- Existing pants tests in the affected module pass
```

### Spec Document (conditional)

A separate Linear document linked to the issue. Created **only when substantive** — when there's enough context that an LLM would meaningfully benefit from it over just reading the ticket title and description.

**Skip the spec doc for:** straightforward tickets where the acceptance criteria basically are the spec.

**Create a spec doc when:** the conversation contains non-obvious constraints, architectural context, open questions, or implementation breadcrumbs that would help an LLM start a productive brainstorming session from cold start.

**Purpose:** This is not an implementation spec. It's a prompt to initiate exploration. It should capture all context and concerns needed for a fruitful discussion about the problem space and solutions.

**Writing principles:**
- Free-form structure dictated by content — no rigid template
- A simple problem gets a few paragraphs. A complex one gets sections.
- Preserve file paths, function names, service boundaries, error messages, relevant ticket/PR links
- Frame open questions explicitly — these are what make it a brainstorming prompt
- Include "starting points" — breadcrumbs into the codebase or system for someone with zero prior context

**Title format:** Same as the ticket title, prefixed with "Spec: " (e.g., "Spec: Add rate limiting to inference API")

## Defaults

| Field | Default |
|---|---|
| Team | AMPSS (unless context suggests otherwise) |
| Priority | 3 (Normal) |
| State | Triage |
| Assignee | Unassigned |
| Project | Inferred from context (see Project & Milestone Discovery) |
| Milestone | Inferred from active milestone on the matched project |
| Labels | Inferred from recent tickets in the matched project; falls back to sibling tickets if a parent is selected |
| Estimate | Not set by default; suggest one for user to opt in |

## Project & Milestone Discovery

Every ticket should be evaluated for project and milestone attachment. This is not opt-in; always attempt it.

**Inference strategy** (in priority order):

1. **Conversation context** — If the discussion references a specific project, feature area, or initiative, match it against known Linear projects on the team.
2. **Branch name** — Parse the current git branch for domain hints (e.g., `jeffdt/insights-add-cache-ttl` suggests the insights/CSA project area).
3. **Recent team tickets** — Search recent AMPSS tickets for similar topics and check which project they belong to.

If a project is confidently matched, use it. If multiple candidates exist or confidence is low, present the top candidates and ask the user to confirm.

**Milestone**: Once a project is identified, check for an active milestone on that project. If one exists, attach the ticket to it. If multiple active milestones exist, ask.

**Labels**: Once a project is identified, check recent tickets in that project for common labels. Suggest any that appear frequently and are relevant.

**Estimate**: Suggest a point estimate based on the ticket's apparent complexity, but do not attach it by default. Present it as an option during confirmation so the user can opt in.

## Parent Ticket Discovery

Parent attachment is **opt-in** — only search for parents when the user explicitly requests it (e.g., "attach to a parent", "find a parent ticket", or names a specific parent issue).

When requested:

1. Infer the domain/area from the ticket content
2. Search for potential parent issues in the team using broad keywords
3. Present top candidates via `AskUserQuestion` with a "None / standalone" option
4. If a parent is selected, check sibling tickets for common labels and suggest them

## Preview Before Save

Before every `mcp__plugin_linear_linear__save_issue` call, print a readable preview of the ticket in the parent conversation so the user can scan it above the permission prompt. The raw MCP params are not human-readable; the preview is what the user actually approves against.

Format: YAML frontmatter for metadata, markdown for the description body. One block per ticket. If a spec doc will be created, append a second block titled `Spec Document` with its title and content.

```
---
title: <title>
team: AMPSS
project: <name> (<id>)            # or null
milestone: <name> (<id>)          # or null
labels: [<label1>, <label2>]      # or []
priority: 3 (Normal)
state: Triage
assignee: null
estimate: <points>                # or null
parent: <identifier>              # or null
spec_doc: <true|false>
---

<description markdown, exactly as it will be sent>
```

If multiple tickets are being created in a batch, print one preview block per ticket, then make the `save_issue` calls in order. Do not collapse, summarize, or abbreviate the description — show the exact string that will be sent.

## Tools

Primary: `mcp__plugin_linear_linear__save_issue` for creating issues, `mcp__plugin_linear_linear__create_document` for spec docs (with `issue` parameter to link).

Call these directly in the main conversation, not via a Task subagent — the preview block above the call is the user's confirmation surface, and subagent-scoped calls hide the preview from the parent context.

Fallback: Linear CLI if MCP tools are unavailable.
