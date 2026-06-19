---
description: Distill a month of daily logs into an initiative-grouped monthly narrative
---

# Monthly Rollup

Distill a month of daily work logs into a durable, initiative-grouped narrative and write it to my Career vault. This is the activity-derived layer of the perf-narrative pipeline (daily -> monthly -> quarterly). Value mapping is intentionally deferred to the quarterly step; do NOT map Klaviyo values here.

**Month**: $ARGUMENTS (default: last complete month)

Supports:
- `2026-05`, `May`, `2026-5`
- empty -> last complete calendar month
- a current-month / month-to-date request (e.g. `2026-06-mtd` or "this month") -> generate partial, note coverage in the footer

---

## Step 1: Resolve the month and gather daily notes (parent)

1. Parse `$ARGUMENTS` into a target year + month. Default to the last complete calendar month relative to today.
2. List daily notes in `/Users/jeff.diteodoro/o/Daily/`. Filenames are `YY-MM-DD (Day).md`. Select every note whose date falls in the target month.
3. Identify workday gaps (Mon-Fri dates in the month with no daily note). If notable gaps exist, tell the user and offer to backfill via `/pkm:daily-log` first, then proceed (do not block, a month with gaps is still worth rolling up, just note coverage in the footer).
4. Compute the ISO-week boundaries within the month so the days can be split into ~4 week-buckets for the subagents.

## Step 2: Spawn one read-only subagent per week (parent -> subagents)

For each week-bucket that contains at least one daily note, spawn a background subagent (`Task`, `run_in_background: true`, `subagent_type: "general-purpose"`). Each subagent prompt MUST contain:

1. The explicit list of daily-note file paths for that week.
2. Instructions: "Read each of these daily notes. The top `# Summary` section is the already-distilled narrative; the bottom `# Raw Activity Log` is a link reservoir, pull specific PR/ticket/doc links from it only for work that matters. Return a structured distillation of THIS WEEK with these fields: Initiatives touched (name + what happened + outcome), Key evidence links (PRs, tickets, docs), Collaborators (name + context), Notable blockers."
3. Constraint: "Return the distillation as your final response. Do NOT use Bash, Write, or any file-writing tool. Do NOT ask the user questions. You are read-only."

(Subagents are read-only because, per the daily-log pattern, subagents cannot get interactive permission approval for Bash/Write, the parent handles all privileged operations.)

## Step 3: Collect and synthesize the month (parent)

1. Wait for all subagents via `TaskOutput`.
2. Cluster the week distillations into **initiatives** (organize by project/initiative, NOT by day or by week).
3. Deduplicate recurring threads across weeks; describe net progress over the month (e.g. "opened, iterated, merged"), not each incremental step.
4. Write the "Month at a Glance" arc narrative: theme, where energy went, the shape of the month (2-4 sentences).
5. Compile the month's collaborators and a carry-forward list of threads continuing into next month.

## Step 4: Gather recognition pointers (parent)

List filed perf evidence in `/Users/jeff.diteodoro/Klaviyo/projects/career/perf/<year>/` whose date falls in the target month.
- Prefer the `date` frontmatter field (filed entries use `date:`; some may use `event_date:`); fall back to the `YYYY-MM-DD` filename prefix.
- Include each as a one-line pointer (short description + repo-relative path). Do NOT synthesize or frame these, synthesis is the quarterly's job. This only ensures recognition surfaces monthly instead of waiting a full quarter.
- If none, write "No filed recognition this month".

## Step 5: Write the file (parent)

**Path**: `/Users/jeff.diteodoro/o/Career/<year>/Monthly/Monthly Rollup - <YYYY> - <MM> (<Month>).md`
Example: `Monthly Rollup - 2026 - 05 (May).md`

If the file already exists, show the user the new content and confirm before overwriting (dailies are the source of truth, so regeneration is safe).

**File structure:**
```markdown
---
aliases:
tags: monthly
---
# <Month> <Year> Monthly Rollup

## Month at a Glance
<2-4 sentence arc>

## Initiatives
### <Initiative name>
- **Impact / outcome:** <what changed in the world>
- **Scope & complexity:** <size, stakes, difficulty>
- **Status:** shipped / ongoing / blocked
- **Evidence:** <PR/ticket links, [[Project Hub]] wikilinks>
- **Collaborators:** <names + context>

### <next initiative>
...

## Recognition this month
- <one-line>: `perf/<year>/<file>.md`
(or "No filed recognition this month")

## Collaborators (month)
- <Name>: <context>

## Carry-forward → <next month>
- <ongoing thread + pointer>

---
*Generated: <timestamp> from N daily notes (<first date> … <last date>)*
```

Use real newlines. Do NOT use em dashes anywhere in the output (use commas, colons, or separate sentences).

## Step 6: Display summary in chat

Show the synthesized "Month at a Glance" plus the initiative headings in chat so I can review at a glance.

## Quality Checklist
- [ ] Output is organized by initiative, not by day or week
- [ ] NO Klaviyo value mapping (deferred to quarterly)
- [ ] Every initiative has at least one evidence link
- [ ] Recurring work is deduplicated into net progress, not per-day repetition
- [ ] Recognition pointers list that month's `perf/<year>/` entries (or state none)
- [ ] Carry-forward names threads continuing into next month
- [ ] Footer notes coverage if the month had gaps or is month-to-date
- [ ] No em dashes in the output
