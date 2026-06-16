---
description: Synthesize a quarter of monthly rollups plus perf evidence into a value-mapped narrative
---

# Quarterly Narrative

Synthesize a quarter into a perf-packet-ready narrative: cluster the quarter into top initiatives, attach the recognition and metrics that back each one, and map each to the Klaviyo values it genuinely demonstrates. This is the convergence point of the two evidence streams, activity (monthly rollups) and recognition (perf/<year> captures).

**Quarter**: $ARGUMENTS (default: last complete quarter)

Supports:
- `2026-Q2`, `Q2`, `2026 Q2`
- empty -> last complete quarter
- a current-quarter request -> generate partial, note coverage in the footer

Quarters: Q1 = Jan-Mar, Q2 = Apr-Jun, Q3 = Jul-Sep, Q4 = Oct-Dec.

---

## Step 1: Resolve the quarter and load monthly rollups (parent)

1. Parse `$ARGUMENTS` into a target year + quarter. Default to the last complete quarter relative to today.
2. Determine the quarter's 3 months. Load the corresponding monthly rollups from `/Users/jeff.diteodoro/o/Career/<year>/Monthly/` (filenames `Monthly Rollup - <YYYY> - <MM> (<Month>).md`).
3. If a monthly rollup is missing, warn the user and offer to generate it first via `/pkm:monthly-rollup <YYYY-MM>`. Proceed with available months if the user declines, noting reduced coverage in the footer.

## Step 2: Load perf evidence for the quarter (parent)

List filed perf evidence in `/Users/jeff.diteodoro/Klaviyo/projects/career/perf/<year>/` whose date falls within the quarter's 3 months.
- Prefer the `date` frontmatter field (filed entries use `date:`; some may use `event_date:`); fall back to the `YYYY-MM-DD` filename prefix.
- Read those entries (they are concise) so their recognition/metrics content is available for attaching to initiatives.

## Step 3: Cluster into top initiatives and map values (parent)

1. Cluster the quarter into **top initiatives** (the highest-impact threads of the quarter, not every small task), drawing on the 3 monthlies loaded in Step 1.
2. For each initiative:
   - Fuse the activity narrative (from monthlies) with attached recognition and metrics (from perf evidence).
   - Map to the Klaviyo values it genuinely demonstrates. Only assert a value when the behavior strongly aligns, do not force it. Klaviyo values: Put customers first; Win together; Know the score; Be meticulous in your craft; Move fast, no shortcuts; Drivers wanted; Stay hungry, stay humble; We're 1% done.
3. Build a quarter-wide values scorecard (which initiatives demonstrated each value), a collaborators list, and a carry-forward list into the next quarter.

## Step 4: Write the file (parent)

**Path**: `/Users/jeff.diteodoro/o/Career/<year>/Quarterly/Quarterly Narrative - <YYYY> - Q<n>.md`
Example: `Quarterly Narrative - 2026 - Q2.md`

If the file already exists, show the user the new content and confirm before overwriting.

**File structure:**
```markdown
---
aliases:
tags: quarterly
---
# <Year> Q<n> Quarterly Narrative

## Quarter at a Glance
<short arc across the 3 months>

## Top Initiatives
### <Initiative name>
- **What & impact:** <narrative + outcome>
- **Scope & complexity:** <size, stakes>
- **Recognition:** <praise, metrics from perf/<year>>
- **Values:** <Klaviyo values genuinely demonstrated>
- **Evidence:** <PR/ticket links + `perf/<year>/<file>.md` pointers>

### <next initiative>
...

## Values Scorecard (across quarter)
- **<Value>:** <which initiatives demonstrated it>

## Collaborators (quarter)
- <Name>: <context>

## Carry-forward → Q<n+1>
- <ongoing thread>

---
*Generated: <timestamp> from monthlies <list> + N perf entries*
```

Use real newlines. Do NOT use em dashes anywhere in the output.

## Step 5: Display summary in chat

Show the "Quarter at a Glance" plus the top-initiative headings and their mapped values so I can review.

## Quality Checklist
- [ ] Organized around top initiatives, evidence and recognition fused per initiative
- [ ] Each initiative maps to Klaviyo values only where genuinely demonstrated
- [ ] Values scorecard rolls up across the quarter
- [ ] Every initiative cites evidence (links and/or perf pointers)
- [ ] Missing monthlies are surfaced, not silently skipped
- [ ] Footer notes coverage if a monthly was missing or the quarter is partial
- [ ] No em dashes in the output
