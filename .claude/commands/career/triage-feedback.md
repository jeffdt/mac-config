---
description: Interactively triage the career/perf inbox — filter, frame, and file captured items into perf/<year>/
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(date:*), Bash(pwd:*), Bash(mv:*), Read, Write, AskUserQuestion, Task
argument-hint: "[optional: 'all', 'oldest', 'newest', a count like '3', or empty for interactive selection]"
---

# Career Triage Feedback

Interactively process Jeff's career/perf inbox. For each captured item, decide whether to **file** (synthesize into a `perf/<year>/` entry against the Amplify-Amplify mandate), **defer** (leave in inbox), or **dismiss** (archive to `_dismissed/`).

**Arguments**: $ARGUMENTS

**Career project path**: `/Users/jeff.diteodoro/Klaviyo/projects/career/`
**Inbox path**: `/Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/`

---

## Why triage lives separate from capture

Capture is a low-friction dump from any session. Triage is the synthesis step, run from the career project where the **perf README, the mandate memory, and sibling entries** are all loaded. This is the right lens for filtering and framing. Lean into it: pattern-match against existing entries, anchor framing to the manager mandate, write the entry the way past-Jeff would have wanted today-Jeff to write it.

---

## Operating principles

### 1. Filter ruthlessly. Default to dismiss for marginal items.

Jeff firehoses signal — the inbox is not the same as a perf entry. Items in inbox have crossed the very low bar of "worth pointing at"; they have NOT crossed the bar of "worth synthesizing as perf evidence." Most inbox items should be filed, some should be dismissed, and some should be deferred (collect more context first).

**Skip / dismiss examples:**

- Generic praise without specifics ("great work!", a single :fire: reaction, a thumbs-up)
- Internal team kudos that don't show pillar-level or cross-pillar impact and aren't attached to a concrete artifact
- Adoption signals without attribution ("someone is using X" with no name, no quote)
- Anything already captured in another perf entry (check `ls perf/<year>/` for overlap)
- Routine work updates, status reports, in-progress signals
- Self-praise or self-reported wins without external validation

**File (worth a perf entry) examples:**

- External customer impact tied to something Jeff built, with a quote or artifact
- Cross-team or cross-pillar adoption with explicit attribution
- Manager / skip / VP validation tied to Jeff's growth themes (especially anything that lands against the Amplify-Amplify mandate)
- Force-multiplier evidence: peers investing tooling effort to consume Jeff's work on an ongoing basis
- Concrete metrics (adoption counts, time saved, dollars, latency, error reduction)
- Milestones: shipped feature, project completion, scope change, new responsibility
- Unprompted self-report from a CSM / PM / peer of a real outcome with specifics

**Defer examples:**

- Inbox entry has a thin source — would be stronger with a follow-up Slack pull, a Linear ticket link, or a metric that isn't yet available
- Event is too recent — adoption signal may compound in a week; revisit
- Needs a quote that wasn't preserved at capture time — go pull it before filing

### 2. Frame against the Amplify-Amplify mandate.

Jeff's manager has tied his promotion case to demonstrating that he made the *entire Amplify pillar* more efficient, especially in AI usage. See [[jeff_pillar_and_growth_mandate]] in career-project memory. When writing the "Why it matters for perf framing" section, name how the item lands against this mandate explicitly:

- **Bullseye**: cross-Amplify adoption with attribution, especially with public artifacts (lunch-and-learns, posts in shared channels, peers building tooling around Jeff's work)
- **Adjacent**: IOAmp-internal upskilling, peer adoption within Amplify
- **Stretch signal**: reach beyond Amplify (core infra, IO, other pillars), unsolicited demand from peers asking Jeff to extend his work
- **Weak but worth filing**: 1:1 kudos with concrete artifact attached, customer outcome with named customer + quote + artifact

If a captured item doesn't fit any of these, that's a strong signal to dismiss it, not stretch the framing.

### 3. Use the captured source_context to inform framing.

Every inbox entry has a `source_context:` field describing what the source session was doing when the item was captured. Use this. It often tells you what project the win is attached to, what feature was being built, what conversation it came out of. The career project's lens gives you the perf framing; the source_context gives you the project-correct framing.

### 4. Read the perf README at runtime; pattern-match against sibling entries.

Run `cat /Users/jeff.diteodoro/Klaviyo/projects/career/perf/README.md` to confirm the current frontmatter shape and type values. Then `ls /Users/jeff.diteodoro/Klaviyo/projects/career/perf/<year>/` and skim 2-3 recent entries of the same `type` to match style. Existing entries are the single best guide to what a "good" entry looks like.

### 5. Slack reads still go through a subagent.

If pulling additional source context during synthesis requires Slack reads (e.g., the inbox entry only has a URL and needs the verbatim thread), launch a `Task` subagent. Same rule as capture.

### 6. No em dashes anywhere.

Jeff's global rule. Use commas, semicolons, colons, parentheses, or sentence breaks. Applies to both the perf entry body and conversational output during triage.

---

## Process

### Step 0: Verify we're in the career project

Run `pwd`. If cwd is not under `/Users/jeff.diteodoro/Klaviyo/projects/career/`, warn the user that triage is best done from there (CLAUDE.md, memory, and adjacent entries are loaded), and ask via `AskUserQuestion`:

1. **Cancel and `cd` to career project first** (recommended)
2. **Proceed anyway** (Claude will fetch convention files manually)

### Step 1: List inbox

Run `ls -la /Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/` (excluding `_dismissed/` and `.gitkeep`).

For each inbox file, `Read` the frontmatter and show a tight summary table:

| # | captured_at | event_date | source_type | attribution | initial_read |
|---|-------------|------------|-------------|-------------|--------------|

Show the count. If zero items, say so plainly and stop.

### Step 2: Pick scope

Parse `$ARGUMENTS`:

- **`all`**: triage every item, oldest first
- **`oldest`**: triage the single oldest item
- **`newest`**: triage the single newest item
- **Numeric** (e.g., `3`): triage the N oldest items
- **Empty / interactive**: ask via `AskUserQuestion` (multiSelect: true) which items to triage now, listing each by `#` and `initial_read`. Include "All" and "Cancel" as options.

### Step 3: Triage each selected item

For each item in scope, run this loop:

#### 3a. Display the item

Read the inbox file in full. Display:

- Frontmatter (captured_at, event_date, source_type, source_url, attribution, source_context, initial_read)
- Body (verbatim source content)

#### 3b. Recommend a disposition

Apply the filter rule above. State your recommendation **with reasoning** in 2-4 sentences:

- "Recommend **file** — this is force-multiplier evidence with explicit attribution at a public event; lands against the bullseye of the Amplify-Amplify mandate."
- "Recommend **dismiss** — this is a generic :fire: reaction with no attribution or artifact; doesn't pass the perf-entry bar even though it was worth capturing."
- "Recommend **defer** — the captured Slack thread only has a one-line quote; pull the parent channel post and the customer's follow-up before filing for a stronger entry."

#### 3c. Confirm via AskUserQuestion

Present 3 options (plus "Skip this one for now") and let Jeff redirect:

1. **File** (recommended | accepts your recommendation)
2. **Dismiss** (recommended | accepts your recommendation)
3. **Defer** (recommended | accepts your recommendation)
4. **Skip** (don't decide right now; leave in inbox; move to next item)

Put the recommended option first with "(Recommended)" appended.

#### 3d. On "Dismiss"

Move the inbox file to `_dismissed/`:

```
mv /Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/<filename> \
   /Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/_dismissed/<filename>
```

(Archive rather than delete. Cheap to keep; useful for "wait, did I dismiss something I shouldn't have" recovery.)

#### 3e. On "Defer"

Leave the inbox file in place. Note the deferred status in your running tally for the end-of-triage report. Optionally, ask if Jeff wants you to add a brief `defer_reason:` field to the frontmatter so he remembers why later — only if the reason is non-obvious.

#### 3f. On "File"

Full synthesis flow. This is where the real work happens.

1. **Determine date**: Use `event_date` from frontmatter. If missing, infer from source content; if still unclear, ask via `AskUserQuestion`.

2. **Determine type**: Pick from the perf README's enum (`user-feedback`, `peer-feedback`, `manager-feedback`, `recognition`, `metric`, `milestone`, `retro`, `interaction`, `learning`, `context`). If ambiguous, ask.

3. **Generate filename**: `<event_date>-<specific-kebab-slug>.md`. Slug should be specific (e.g., `csa-james-wagner-cmo-presentation-win`, not `csa-win`). Confirm via `AskUserQuestion` with the recommended slug and 1-2 alternatives.

4. **Check collision**: `ls /Users/jeff.diteodoro/Klaviyo/projects/career/perf/<year>/<filename>`. If exists, ask: append / suffix with `-2` / pick a different slug.

5. **Draft entry** following the perf README's frontmatter shape and the body pattern from sibling entries:

   - **Context**: 1 to 3 paragraphs setting up what happened. Preserve specifics: customer names, CSM names, channel names, dates.
   - **Why it matters for perf framing**: the so-what. Bullet the angles. Lead each bullet with a short bold phrase, then expand. This is where the Amplify-Amplify framing lives explicitly.
   - **Key quotes**: verbatim, with author + timestamp.
   - **Artifacts** (if relevant): file names, sizes, source links. Don't auto-download.
   - **Source**: link to the original Slack URL / Linear ticket / PR / wherever, so the entry is auditable.

   Frontmatter rules: specific tags, not generic; `impact` is one sentence; `date` is the event date.

6. **Show draft, then write**: Display the draft inline. Ask via `AskUserQuestion`:

   - **Write as-is** (recommended if the draft looks solid)
   - **Let me edit first** (return to conversation for edits before writing)
   - **Cancel** (go back to defer / dismiss decision)

7. **On "Write as-is"**: Write to `/Users/jeff.diteodoro/Klaviyo/projects/career/perf/<year>/<filename>`. Then archive the inbox file to `_dismissed/`:

   ```
   mv /Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/<inbox-filename> \
      /Users/jeff.diteodoro/Klaviyo/projects/career/perf/inbox/_dismissed/<inbox-filename>
   ```

   (We archive the inbox file rather than delete it, so the original verbatim source is preserved alongside the synthesized entry. The synthesized entry is the source of truth; the inbox file is the receipt.)

8. **Memory updates**: If during synthesis you uncovered framing nuance that should update career-project memory (e.g., a sharper mandate framing, a new project context, a relationship update), flag it to the user and offer to update the relevant memory file at `/Users/jeff.diteodoro/.claude/projects/-Users-jeff-diteodoro-Klaviyo-projects-career/memory/`. Don't auto-update memory without surfacing the change. If the nuance is project-specific or one-off, do NOT save as memory.

### Step 4: Report

After all selected items are processed, display a summary:

- **Filed**: N items, with clickable links to each new entry: `[perf/<year>/<filename>](file:///...)`
- **Dismissed**: N items
- **Deferred**: N items (still in inbox)
- **Skipped**: N items (still in inbox)
- Any memory updates made or proposed.

If the inbox still has items after triage, note the remaining count and remind: `ls perf/inbox/` to see what's left.

---

## Quality checklist (for each Filed entry)

Before writing, verify:

- Frontmatter is valid YAML and matches the perf README's shape
- `date` is the event date, not today's date
- `type` matches one of the README's enumerated values
- `impact` is one sentence and captures the so-what
- Tags are specific, not generic
- Body has Context, Why it matters, Key quotes (with attribution), Source link
- No em dashes
- Source quotes are verbatim, not paraphrased
- Framing explicitly names how the item lands against the Amplify-Amplify mandate
