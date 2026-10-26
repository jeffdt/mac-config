---
description: Dump a piece of career/perf evidence into the triage inbox for later synthesis
allowed-tools: Bash(ls:*), Bash(date:*), Bash(pwd:*), Bash(git:*), Read, Write, AskUserQuestion, Task
argument-hint: "[optional: Slack URL, topic hint, or empty to synthesize from conversation]"
---

# Career Capture Feedback (Inbox)

Drop a piece of career/perf evidence (kudos, customer feedback, peer adoption, manager validation, milestone, metric) into Jeff's triage inbox from the **current session**. This is a *low-friction capture* — pointer + verbatim source content + a small source-session context snippet. **No synthesis, no framing, no filtering against the Amplify-Amplify mandate.** That work happens later, via `/career:triage-feedback`, when Jeff is in the career project with the perf lens loaded.

**Arguments**: $ARGUMENTS

**Inbox path**: `/Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/` — fixed path. Do NOT search for it.

---

## Why this is split capture-then-triage

The capture command runs from **any** session (CSA, app, k-repo, infra, etc.) and is optimized for speed: under 30 seconds elapsed, no editorializing. The triage command runs from the **career project** with the perf README, the mandate memory, and sibling perf entries all loaded — that's the better lens for framing and filtering. Keep capture cheap so the inbox actually fills.

The one thing capture *must* preserve is **source-session context**: a brief snapshot of what session / project / topic the capture came from. Without it, triage is context-blind and the framing-fidelity argument falls apart.

---

## Process

### Step 1: Identify the candidate

Parse `$ARGUMENTS`:

- **Slack URL** (matches `slack.com/archives/...`): The user wants to capture from that specific message + its thread. Extract channel ID and message timestamp from the URL.
- **Topic hint plain text**: Narrow the conversation scan to that topic.
- **Empty**: Scan the current conversation for capturable items (recent kudos, peer adoption signals, customer quotes, manager validation, etc.). If multiple plausible candidates exist, list them numbered and ask via `AskUserQuestion` (multiSelect: true) which to capture; include "Skip all" as an option. If zero plausible candidates exist, say so plainly and stop — do not invent a capture.

Do NOT apply the perf filter rule. The bar at capture time is just "is there something here worth pointing at" — a single thumbs-up reaction in isolation is a skip; almost everything else is a capture. Filtering happens at triage.

### Step 2: Pull source content

- **Slack URL** or any Slack-referenced thread: Launch a single `Task` subagent. The subagent's job: read the message + its thread + any obvious related context (e.g., parent channel post if this is a thread reply), and return verbatim quotes with author + timestamp attribution, channel name, and any notable reactions. Cap subagent response under 600 words. Do NOT pull Slack tools from the main session.
- **Linear ticket / PR / email / 1:1 doc**: Use the appropriate tool (gh, Linear MCP, Read) from the main session.
- **Conversation-only**: Synthesize from conversation history. Preserve specific quotes verbatim where present; mark them as such.

### Step 3: Capture source-session context

This is the single most important step at capture time. Generate a **1 to 3 sentence** snapshot of what the *current session* was doing when the capture happened, so triage isn't blind.

Pull context from:

- `pwd` — what directory / project / repo are we in?
- Git branch (`git branch --show-current 2>/dev/null` if it's a git repo) — what feature work is active?
- The recent conversation — what topic / problem / project was being worked on?
- Any CLAUDE.md available in the current cwd — what is this project?

Compose a snippet like:

> "Captured from a CSA app-repo session on branch `jeffdt/csa-phase-3-sse-reconnect`. The session was debugging an SSE reconnection bug in the chat UI when the source Slack message came in via a tab switch."

Or, if it's a more passive capture:

> "Captured from a career-project session that was already in the middle of filing a different perf entry; user pivoted to capture this Slack thread."

The goal is for future-Jeff at triage time to reconstruct *just enough* of the active project context to frame the win correctly without re-reading the source conversation.

### Step 4: Generate filename, frontmatter, body

**Filename**: `YYYY-MM-DD-HHMM-<short-kebab-slug>.md` — uses today's date and time so files sort chronologically within the inbox. Use `date +%Y-%m-%d-%H%M` to generate. Slug should be short and specific (e.g., `csa-james-wagner-cmo-win`, `risa-lunch-and-learn-shoutouts`).

**Frontmatter shape**:

```yaml
---
captured_at: <ISO 8601 timestamp, including timezone>
event_date: <YYYY-MM-DD when the event happened, if known; omit if unclear>
source_type: <slack-thread | slack-dm | linear-comment | linear-ticket | pr-review | conversation | email | video | doc | other>
source_url: <Slack URL / Linear URL / PR URL / etc., if applicable>
attribution: [<people involved>]
source_context: |
  <1 to 3 sentence snapshot of the current session: cwd / project / branch / topic / what the user was doing when this was captured>
initial_read: <one-line first impression of what this is and why it might matter; NOT full framing>
status: pending
---
```

Use `date -u +%Y-%m-%dT%H:%M:%S%z` (or `date +%Y-%m-%dT%H:%M:%S%z` for local time with offset) for `captured_at`.

**Body**: The raw source content. For Slack, paste verbatim quotes with author + timestamp. For Linear / PR / email, paste the relevant excerpts. No editorializing, no "why it matters" section — that's triage's job. If artifacts (PDFs, screenshots, file names) are referenced, list them at the bottom under an `## Artifacts` heading but do not auto-download.

### Step 5: Check for near-duplicate

Run: `ls /Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/` and `ls /Users/jeff.diteodoro/Klaviyo/projects/career/perf/<current-year>/`

Quick scan for items with similar slug or attribution overlapping the source URL. If a close match exists, flag it to the user with the existing file path and ask via `AskUserQuestion` whether to:

1. **Capture anyway** (multiple captures of the same event are fine if they add detail)
2. **Skip** (already captured)
3. **Append note to the existing inbox file** (only if the existing file is still in inbox, not filed)

### Step 6: Write the inbox file

Write to `/Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/<filename>`.

### Step 7: Confirm (with a gut read)

Reply to Jeff in the chat (NOT in the captured file) with:

1. **File path** as a clickable markdown link: `[perf/inbox/<filename>](file:///Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/<filename>)`
2. **One-line factual summary** of what landed in the inbox.
3. **Gut read** — your honest subjective take on the claim, in 1 to 3 sentences. This is the colleague-pinging-Jeff-back moment, not a press release. Call out one or more of:
   - Signal strength (strong / moderate / thin) and why
   - What's compelling or unusual about it (specific customer quote, surprising attribution, force-multiplier shape, lands against a known mandate angle)
   - What's weak (single-week metric with no trend window, vague kudos, no named attribution)
   - Duplicative or trend-completing (overlaps with an existing entry, third one this week on the same theme)
   - Any "huh, that's interesting" beat worth flagging

   Be honest, not sycophantic. If the captured item is marginal, say so plainly — that's the whole point of the gut read. Match Jeff's filter-don't-stenograph posture.
4. **Triage nudge**: "Triage when you're next in the career project with `/career:triage-feedback`."

The gut read goes ONLY in the chat reply. Do NOT add a `gut_read` field to the inbox file. Keep the file clinical (raw pointer + verbatim source). Triage forms its own opinion later without being primed by a stale at-capture take.

Keep the whole confirmation tight: 4 to 7 lines total, not a wall of text.

---

## Style rules

- No em dashes anywhere (Jeff's global rule).
- Slack reads MUST go through a `Task` subagent per Jeff's global instruction.
- Do NOT do framing, filtering, or memory updates *to the captured file*. The file is a clinical receipt; the artifact stays clean. Voice and gut-read go in the chat reply (Step 7), not in frontmatter or body.
- Preserve verbatim quotes. Paraphrasing at capture is irrecoverable later.
- If you're tempted to write "this matters because..." in the inbox entry, stop. The `initial_read` is a one-liner first-impression, not a thesis.
