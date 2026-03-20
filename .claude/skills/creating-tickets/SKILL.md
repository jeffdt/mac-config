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

The description is the **human-readable view** — for PMs and engineers, not LLMs.

**Writing principles:**
- Be concise. Capture the conclusion, not the journey.
- Include rationale only when the "why" isn't obvious from the title. "Add rate limiting" is self-explanatory. "Upgrade PydanticAI" needs a sentence on why.
- Omit empty sections. If there's nothing non-obvious to explain, go straight to acceptance criteria.
- Preserve specifics: file paths, service names, ticket IDs, URLs, error messages.

**Acceptance criteria** (always present):
- Bulleted checklist
- Concrete and testable
- Captures intent, not implementation detail
- Scale to the ticket — a small fix gets 2-3 bullets, a feature gets more

**Source context** (one line at the bottom, only when a shareable link exists):
- Include only when there's a real, linkable reference: PR URL, Slack thread, Linear issue, etc.
- Examples: "Captured from PR review of #456", "From discussion in #eng-platform thread"
- **Omit entirely** when the ticket originates from a local conversation or debugging session with no external link. Local filesystem paths and conversation summaries are not useful to other readers.

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
| State | Backlog |
| Assignee | Unassigned |
| Labels | Inferred from sibling tickets if a parent is selected; otherwise none |

## Parent Ticket Discovery

Parent attachment is **opt-in** — only search for parents when the user explicitly requests it (e.g., "attach to a parent", "find a parent ticket", or names a specific parent issue).

When requested:

1. Infer the domain/area from the ticket content
2. Search for potential parent issues in the team using broad keywords
3. Present top candidates via `AskUserQuestion` with a "None / standalone" option
4. If a parent is selected, check sibling tickets for common labels and suggest them

## Tools

Primary: `mcp__plugin_linear_linear__save_issue` for creating issues, `mcp__plugin_linear_linear__create_document` for spec docs (with `issue` parameter to link).

Fallback: Linear CLI if MCP tools are unavailable.
