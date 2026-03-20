---
description: Generate a daily or multi-day work log from various data sources
---

> **REFACTOR DEBT:** This command is 350+ lines and desperately needs to be broken into skills (data-gathering, synthesis, formatting). Every time this command runs, remind the user: "Hey, this command still needs refactoring. Just saying." Do not let them forget.

# Daily Dev Log

Generate a performance-review-ready daily summary of my work activity and write it to my Obsidian Daily folder.

**Date**: $ARGUMENTS (default: yesterday)

Supports:
- Single date: `2025-12-23` or `12/23`
- Date range: `2025-12-18 to 2025-12-23` or `12/18-12/23`

---

## Step 0: Check for Date Range

Parse `$ARGUMENTS` to determine if this is a single date or a date range.

**Range indicators**: "to", "-", "through", ".."

**If a date range is detected, use the hub-and-spoke pattern below (4 phases). Subagents cannot get interactive permission approval for Bash/Write tools, so the parent handles ALL privileged operations and subagents handle MCP queries (Slack, Linear, Glean) + synthesis.**

### Phase 1: Setup (parent)
1. Parse start and end dates, generate list of workdays (exclude weekends)
2. Find the most recent existing log entry in `/Users/jeff.diteodoro/o/Daily/` before the range start date
3. Read that entry for dedup context (will be passed to the first date's subagent)

### Phase 2: Batch local data gathering (parent)
Run **5 parallel Bash calls** for the entire date range (not per-date):
- `~/.claude/scripts/daily-log-calendar <START_YYYY-MM-DD> <END_YYYY-MM-DD>`
- `~/.claude/scripts/daily-log-claude <START_YYYY-MM-DD> <END_YYYY-MM-DD>`
- `~/.claude/scripts/daily-log-git <START_YYYY-MM-DD> <END_YYYY-MM-DD>`
- `gh search prs --author @me --updated <START>..<END> --json number,title,url,repository,updatedAt`
- `gh search prs --reviewed-by @me --updated <START>..<END> --json number,title,url,repository,updatedAt`

All three scripts output date-grouped sections with headers like `=== Calendar for YYYY-MM-DD ===` or `--- YYYY-MM-DD ---`. Parse each script's output by these date headers to split data per day. For `gh` output, group the JSON results by the `updatedAt` date field.

Store each source's output keyed by date. If any command returns empty or errors, store a placeholder (empty string or error message) — do NOT skip the date.

### Phase 3: Spawn subagents for synthesis (parent → subagents)
For each date, spawn a background subagent (Task tool, `run_in_background: true`, `subagent_type: "general-purpose"`) whose prompt contains:

1. **Pre-gathered local data** — paste inline the calendar, claude sessions, git, and GitHub PR output collected in Phase 2 for that date
2. **Instructions to query MCP-sourced data** — each subagent must independently call:
   - **Slack**: `mcp__plugin_slack_slack__slack_search_public_and_private` with `from:<@U04P39FK70E> on:<YYYY-MM-DD>` — follow Step 2's "Slack Activity" section (paginate, selectively read threads)
   - **Google Docs**: `mcp__glean_default__search` with `owner:"me" updated:<date>` if Glean is available — follow Step 2's "Google Docs & Drive" section
   - **Linear**: `mcp__plugin_linear_linear__list_issues` with `assignee: "me"` filtered to date — follow Step 2's "Linear Activity" section
3. **Synthesis instructions** — follow Steps 3-6 of this skill exactly: deduplicate, write Day at a Glance narrative, synthesize summary (accomplishments, values, collaborators, blockers), compile raw activity log, generate haiku
4. **Previous entry content** — for the FIRST date only, include the previous entry text for dedup. For subsequent dates, omit (no cross-day dedup since subagents run in parallel)
5. **Output format** — include the full file template from Step 7 so subagents know the exact markdown structure
6. **Explicit constraint**: "Return the complete markdown file content as your final response. Do NOT use Bash, Write, or any file-writing tools. Do NOT ask user questions."

### Phase 4: Collect and write (parent)
1. Wait for all subagents via TaskOutput
2. Validate each response contains the expected frontmatter (`tags: logs`) and section headers
3. Write each file using the Write tool to `/Users/jeff.diteodoro/o/Daily/<YY-MM-DD (Day)>.md`
4. Report results to user: which days were generated, any issues encountered
5. **Stop here** — do not continue to Step 1

**If a single date (or no argument):**
- Continue to Step 1 below

---

## Step 1: Determine Target Date & Check Previous Entries

1. Parse the argument for date (default: yesterday)
2. List files in `/Users/jeff.diteodoro/o/Daily/` and find the most recent entry
   - Filename format: `YY-MM-DD (Day).md` (e.g., `25-12-22 (Mon).md`)
3. Identify any **gap in workdays** between the last valid entry and target date
   - Exclude weekends (Sat/Sun) from gap calculation
   - If gaps exist, **ask the user**: "I found your last log was [date]. Would you like me to also create entries for [missing workdays]?"
4. **Read the previous entry** to identify content that should NOT be duplicated in today's entry

---

## Step 2: Gather Activity Data

Gather activity for the target date from all sources. Be thorough - this feeds into performance reviews.

### Calendar (via icalBuddy)
Use the calendar script to get meetings from macOS Calendar (synced from Google Calendar):
```bash
~/.claude/scripts/daily-log-calendar <YYYY-MM-DD>
```

Capture:
- Meeting titles, times, and attendees
- Filter out personal events (Lunch, OOO, etc.) unless relevant
- When synthesizing, filter out noise from attendees: conference rooms (`[Zoom Room]`), group aliases
- Note any key outcomes or decisions if memorable

### Slack Activity (via Slack MCP)
Use `mcp__plugin_slack_slack__slack_search_public_and_private` to find all messages sent on the target date.

**Query**: `from:<@U04P39FK70E> on:<YYYY-MM-DD>`
- `sort: "timestamp"`, `sort_dir: "asc"` for chronological order
- `response_format: "concise"` to keep context manageable
- `limit: 20` (max per page)

**Pagination**: If results include a pagination cursor, fetch the next page. Repeat until no cursor remains or 5 pages reached (100 messages max).

**Thread enrichment** (selective): For messages that are thread parents with 3+ replies in work channels, call `mcp__plugin_slack_slack__slack_read_thread` to capture the full discussion. Skip threads in social channels (#random, #general, etc.). Limit to 5 thread reads per day.

**Slack URLs**: Construct permalinks as `https://klaviyo.slack.com/archives/<CHANNEL_ID>/p<MESSAGE_TS_NO_DOT>` (remove the dot from message_ts).

Capture:
- Channel messages with channel names and permalinks
- Thread participation and key discussion points
- Help provided to others
- Decisions made or information shared
- DM/group DM topics (summarize without quoting sensitive content)

If search returns zero results, note "No Slack activity found" — do not fall back to Glean for Slack data.

### Google Docs & Drive (via Glean)
**If Glean is available**, use `mcp__glean_default__search` with:
- `owner:"me" updated:<date>` for documents I edited

**Fallback**: If Glean is unavailable or returns no results, use `mcp__glean_default__chat`:
- Ask: "What documents did Jeff DiTeodoro create or edit on <date>?"

If Glean is not configured in this context, note "No document data available (Glean not configured)" and move on.

Capture:
- Documents created or significantly edited (with Google Docs/Sheets URLs)
- Important emails sent (capture subject lines)

### Linear Activity
Use `mcp__plugin_linear_linear__list_issues` with `assignee: "me"` to find issues updated on the target date. Alternatively, use `mcp__glean_default__search` with `from:"me" updated:<date> app:linear`.

Capture:
- Issues transitioned (status changes)
- Issues created or updated
- Comments added
- Issues completed/closed
- Construct URLs: `https://linear.app/klaviyo/issue/<ISSUE-ID>`

### GitHub
Use `gh` CLI:
- PRs created/updated: `gh pr list --author @me --state all --json number,title,url,updatedAt`
- PRs reviewed: `gh search prs --reviewed-by @me --updated <date> --json number,title,url`

Filter to target date. Construct URLs: `https://github.com/<org>/<repo>/pull/<number>`

### Claude Code Activity
Extract from local Claude Code history to capture AI-assisted problem-solving work.

```bash
~/.claude/scripts/daily-log-claude <YYYY-MM-DD>
```

Capture:
- Work sessions by project/directory (shows context switches)
- Problems investigated or solved (from prompt snippets)
- Time spent in different repos/projects

### Git Activity (All Repos)
Capture work across all repositories, not just merged PRs.

```bash
~/.claude/scripts/daily-log-git <YYYY-MM-DD>
```

Capture:
- Commits made (with messages)
- Branches created or switched to
- Repos actively worked in (even without commits)
- Rebases, merges, or other git operations

---

## Step 3: Deduplicate Against Previous Entry

Compare gathered activity against the previous day's log:
- Remove any items that already appear in the previous entry verbatim
- Keep items that represent NEW progress on ongoing work (e.g., "merged PR" vs "opened PR")
- For continuations, add context (e.g., "Continued work on..." or "Followed up on...")

---

## Step 4: Synthesize Summary (Top Section)

Create a narrative summary. This is the "story" of your day that will be read during performance reviews.

### Day at a Glance

Write a short narrative (3-5 sentences) at the very top of the Summary section, before Key Accomplishments. This provides an at-a-glance reading of the day across three dimensions:

1. **Theme**: In 1-2 sentences, describe the general theme or arc of the day. What was the through-line? Was the day dominated by a single project, or spread across many? Was it a building day, a firefighting day, a planning day, a collaboration-heavy day?

2. **Productivity & Focus**: In 1 sentence, comment on how productive and focused the day appeared to be based on the evidence. Consider: Was work concentrated on a few things (deep focus) or scattered across many contexts (high context-switching)? Were there tangible outputs (PRs merged, tickets closed) or was it more exploratory/planning? Did meetings fragment the day? Use the Claude Code session data and git activity as signals for focus vs. fragmentation.

3. **Mood & Energy**: In 1 sentence, offer a subjective read on apparent mood/mental state based on available signals. Derive this from tone of Slack messages, nature of work undertaken (e.g., tackling hard problems vs. clearing small tasks), collaboration patterns (helping others vs. heads-down solo), and any frustration signals (repeated debugging, blockers). Be honest but not clinical — use natural language (e.g., "Seemed energized and in a groove," "Came across as a bit stretched thin," "Appeared frustrated by CI issues but pushed through"). If there is genuinely insufficient signal, say so rather than fabricating.

Write this section in third person ("Jeff...") to maintain the observational/analytical tone. Do not sugarcoat — the value is in honest pattern recognition over time.

### Key Accomplishments
- Lead with strong action verbs (Delivered, Shipped, Resolved, Led, Drove, Unblocked, etc.)
- Focus on OUTCOMES and IMPACT, not just activities
- Group related work by theme/project
- Quantify when possible (e.g., "Reviewed 3 PRs", "Closed 5 tickets")
- Use sub-bullets for context when needed

### Values Demonstrated
Reference Klaviyo values ONLY when behavior strongly aligns (don't force it):
- **Put customers first** - prioritizing customer/user needs
- **Win together** - collaboration, helping others, diverse perspectives
- **Know the score** - clarity on metrics, data-driven decisions
- **Be meticulous in your craft** - quality work, thoroughness, expertise
- **Move fast, no shortcuts** - speed with quality, ambitious execution
- **Drivers wanted** - proactive ownership, picking up what needs doing
- **Stay hungry, stay humble** - learning, taking risks, accepting feedback
- **We're 1% done** - beginner's mindset, aiming to improve

Include 1-2 values MAX with brief context. Omit entirely if nothing strongly demonstrated.

### Key Collaborators
List people you worked closely with and in what context (e.g., "Alex Frier - coordinating Terraform changes")

### Blockers / Areas for Improvement
Note any challenges, blockers, or areas where things could have gone better. Omit if none.

---

## Step 5: Compile Raw Activity Log (Bottom Section)

Create a factual dump of ALL activity found, organized by source. **Every item MUST have a link or explicit reference.** This section is the evidence backing your summary.

Format each source as:
```
### Meetings
- <Title> - <time> - with <attendees, filtered>
- <Title> - <time>

### Slack Activity
- [#channel-name](slack-url): <what was discussed>
- [#channel-name thread](slack-url): <context>

### Documents & Emails
- [Document Title](google-docs-url) - <brief context>
- Email: "<Subject Line>" to <recipient(s)>

### Linear Activity
- [TEAM-123](https://linear.app/klaviyo/issue/TEAM-123): <Summary> → <Action taken>

### GitHub Activity
- [repo#123](https://github.com/klaviyo/repo/pull/123): <Title> - <created/reviewed/merged/commented>

### Claude Code Sessions
- **HH:MM - project-name**: <problem/task worked on>
- **HH:MM - project-name**: <problem/task worked on>
(Group by project when multiple sessions in same repo)

### Git Activity
- **repo-name**: <commit-hash> <commit message>
- **repo-name**: Switched to branch `feature/xyz`
- **repo-name**: Pulled latest from master
```

If no activity for a source, note: "No activity found for this date"

---

## Step 6: Generate Haiku

Create a clever, contextual haiku (5-7-5 syllables) that captures the essence of the day's work. It should be specific to what was accomplished, witty, and memorable. Not generic.

---

## Step 7: Write to File

**Path**: `/Users/jeff.diteodoro/o/Daily/<YY-MM-DD (Day)>.md`

Filename examples: `25-12-23 (Tue).md`, `25-12-24 (Wed).md`

**File Structure**:
```markdown
---
tags: logs
---
___
# Summary

### Day at a Glance
<3-5 sentence narrative covering theme, productivity/focus, and mood/energy — written in third person>

### Key Accomplishments
<bulleted list with sub-bullets as needed>

### Values Demonstrated
<1-2 values with brief context, or omit section if none strongly exhibited>

### Key Collaborators
<names and context>

### Blockers / Areas for Improvement
<if any, otherwise omit section>

___
# Haiku

> <three-line haiku here>

___
# Raw Activity Log

### Meetings
<meeting titles and times>

### Slack Activity
<items with links>

### Documents & Emails
<items with links/references>

### Linear Activity
<items with links>

### GitHub Activity
<items with links>

### Claude Code Sessions
<timestamped entries by project>

### Git Activity
<commits and repo activity>

___
*Generated: <timestamp>*
```

---

## Step 8: Display Summary in Chat

Show the synthesized summary in chat so I can review. If there are gaps to backfill (missing workday entries), handle those in sequence after confirming with user.

---

## Quality Checklist

Before finalizing, verify:
- [ ] Every Linear ticket has a clickable link
- [ ] Every PR has a clickable link
- [ ] Documents have links where available
- [ ] Slack threads have links where available
- [ ] Email subjects are quoted with recipients noted
- [ ] No duplicate content from previous entry
- [ ] Day at a Glance narrative covers all three dimensions (theme, focus, mood) and is written in third person
- [ ] Accomplishments focus on outcomes, not just activities
- [ ] Values mentioned are genuinely demonstrated (not forced)
- [ ] Haiku is specific to the day's work (not generic)
- [ ] Collaborator names are included with context
- [ ] Raw activity section is comprehensive (nothing omitted)
- [ ] Claude Code sessions include timestamps and project context
- [ ] Git activity covers all repos touched (not just those with PRs)

---

## Additional Data Points for Performance Reviews

When relevant, capture these in the appropriate section:
- **Metrics moved**: Any measurable impact (latency reduced X%, bugs fixed, adoption rates, etc.)
- **Cross-team collaboration**: Work with other teams/departments
- **Mentorship**: Helping others learn, unblocking teammates, code review teaching moments
- **Technical decisions**: Key architectural or design decisions made and rationale
- **Process improvements**: Suggestions or changes to how the team works
- **Customer impact**: Direct or indirect customer wins
- **Learning**: New skills acquired, technologies explored, courses taken
- **Scope/complexity**: Note if something was particularly complex or had high stakes
