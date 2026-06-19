---
description: Interactive chunk-by-chunk PR walkthrough with narrative ordering and inline observations
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr comment:*), Bash(gh pr review:*), Bash(gh repo view:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(python3:*), Bash(open:*), Bash(mkdir:*), Bash(cat:*), Write, mcp__plugin_github_github__pull_request_read, mcp__plugin_github_github__pull_request_review_write, mcp__plugin_github_github__add_comment_to_pending_review, AskUserQuestion, Task, Read, Grep, Glob
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Repo info: !`gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null || echo "UNKNOWN_REPO"`
- PR info: !`gh pr view --json number,url,title,body,state,author,commits,additions,deletions,baseRefName,headRefName,headRefOid 2>&1 || echo "NO_PR_FOUND"`

## Phase 1: Resolve PR and Gather Data

### 1.1 Resolve the PR

Determine which PR to review using this priority:

1. **Argument provided:** If the user passed a PR number or URL as `$ARGUMENTS`, use it.
   - Full URL (`https://github.com/owner/repo/pull/123`): extract owner/repo and number.
   - Bare number: use it with the repo from pre-computed context.

2. **Current branch PR:** If no argument, check pre-computed PR info above.
   - If it contains valid PR data (not `NO_PR_FOUND`), use that PR.
   - Do NOT ask the user to confirm; proceed directly.

3. **No PR found:** Use AskUserQuestion to ask for a PR number or URL. If the user cannot provide one, stop.

Store the PR number, owner/repo, and headRefOid for use throughout the walkthrough.

### 1.2 Fetch PR Data

Gather all data needed for the walkthrough. Make independent calls in parallel where possible.

**Metadata** (from pre-computed context if current branch PR, otherwise fetch):
```bash
gh pr view {number} --json title,body,author,state,commits,additions,deletions,baseRefName,headRefName,headRefOid --repo {owner/repo}
```

**Diff:**
```bash
gh pr diff {number} --repo {owner/repo}
```

**Threaded review comments** (with resolution and outdated status):
Use MCP `mcp__plugin_github_github__pull_request_read` with:
- `owner`: repo owner
- `repo`: repo name
- `pullNumber`: PR number
- `method`: `"get_review_comments"`

Capture each comment's `html_url` along with author, body, file path, line, and resolution status. The URL is required by Phase 3.2 — without it the reader can't open the thread to verify what was actually said or whether it's still open.

**General comments:**
```bash
gh pr view {number} --json comments --repo {owner/repo}
```

### 1.3 Handle Errors

- **No PR found:** "No PR found for branch `X`. Provide a PR number or URL."
- **Auth failures:** Suggest `gh auth status` and `unset GITHUB_TOKEN` if a stale token may be interfering.
- **Empty PR:** If zero changed files, report and stop.

## Phase 2: Build the Narrative

Analyze all changes and construct a reading order before presenting any chunks to the user.

### 2.1 Understand the PR's Intent

Read the PR title, body/description, and commit messages. The PR description is the primary guide for what the author was trying to do and why. Commit messages provide supporting context.

### 2.2 Categorize Each Changed File

| Priority | Category | Examples |
|----------|----------|---------|
| 1 | Schema/model/type definitions | Models, migrations, protobuf, TypeScript types, GraphQL schemas |
| 2 | Core logic/business logic | Services, handlers, domain logic |
| 3 | Integration points/API surfaces | Controllers, endpoints, serializers, API routes |
| 4 | Tests | Test files |
| 5 | Config/infra/boilerplate | CI configs, Dockerfiles, settings, package manifests |
| Skip | Low-value | Lockfiles, generated code, binary files, vendored deps |

### 2.3 Group Related Files into Chunks

A chunk is a unit of review. Use judgment on grouping:
- **Single file** if the file is large or self-contained
- **Multiple small related files** when tightly coupled (e.g., a model + its migration + its serializer)

### 2.4 Order Chunks by the PR's Story

Use the PR description as a guide. If it describes "Added endpoint X backed by service Y", the order is: schema changes, then service Y, then the endpoint, then tests, then config. Fall back to the priority order in 2.2 if the description doesn't suggest an obvious flow.

### 2.5 Handle Skipped Files

Files categorized as "Skip" are excluded from the chunk walkthrough but NOT silently dropped:
- List them in the narrative overview with stats (e.g., "`yarn.lock` (+200 -180)")
- **Flag anything unexpected:** binary files in unusual locations, lockfiles that shouldn't have changed, generated files with apparent manual edits, new files that look sensitive (e.g., `credentials.json`, `.env`)

### 2.6 Handle Large PRs (50+ files)

- Group more aggressively (combine related small files into fewer chunks)
- Auto-skip low-value changes with a note
- Use AskUserQuestion to offer category skip options before starting: "This PR has N files. Want to skip any categories?" Options: "Review everything", "Skip test files", "Skip config/infra", "Skip tests and config"

### 2.7 Write Narrative Content

1. **Narrative overview** (2-4 sentences): What the PR does, why, and key architectural decisions.
2. **Chunk intro** (1-2 sentences each): For every chunk, a brief intro explaining what it does and why the reader is seeing it at this point in the story.

## Phase 2.5: Pre-vet Observations Per Chunk

Before presenting any chunks to the user, fan out per-chunk vetters to generate observations *with evidence*. This frontloads codebase exploration so the interactive phase moves quickly and observations survive pushback. The user is willing to wait here so the walkthrough itself is fast.

### 2.5.1 Dispatch Vetters

For each chunk from Phase 2.3, launch one `Task` subagent with `subagent_type: "general-purpose"` and `model: "sonnet"`. Run them in parallel — cap concurrency at **8 subagents per response**; batch any remainder in subsequent parallel rounds. Do not skip vetting to save time.

**Inputs to each vetter (in the prompt):**
- The chunk's file paths and the diff content for those files (the patch as it appears in the PR)
- PR title, body, and commit messages
- The repo's working directory (vetter will Read/Grep against the *checked-out* branch — note that for PRs against a different branch this is approximate; the vetter should prefer reading the head ref via `gh` if needed, but for the common case of reviewing your own branch the local checkout is correct)
- The repo owner/name and PR number (so the vetter can pull additional file content via `gh` if needed)

**The vetter's job:**

Apply a strict filter — only include items that may warrant a comment or pushback: load-bearing decisions, one-way doors, bugs, missing edge cases, security/performance issues, or quality improvements worth raising. **Do NOT include neutral observations** like "not necessarily a problem", "fine because X", "worth noting but harmless", or balanced both-sides analysis. Cut those entirely; they are noise.

Then:

1. For each potential Concern or Suggestion the diff suggests, do at least one of:
   - Read the full file containing the change (not just the diff hunk)
   - Grep for callers, related code, or existing handling
   - Check related files in the same chunk
2. For every Concern or Suggestion that survives, include an `Evidence:` line: what was checked and what would falsify the claim. Examples:
   - `Evidence: checked callers of parse_token() via grep; all 3 callers pass validated input from middleware.`
   - `Evidence: searched for retry handling in this module; found none. Would be falsified by a wrapper at the call site.`
   - `Evidence: read tests/foo_test.py; no coverage exists for the error path.`
3. **Drop a draft observation only when evidence concretely refutes it.** "I couldn't confirm" is *not* grounds to drop — keep it and note the uncertainty in the Evidence line ("Evidence: could not locate input validation upstream; flagging for author confirmation"). The goal is to remove false claims, not to suppress legitimate ones.
4. Each surviving Concern/Suggestion gets a `recommend_fix: true|false` flag using the same bar as Phase 3.2's `[recommend fixing]` marker — items the vetter would personally fix if it were their PR.
5. Strengths are bulleted one-liners; no Evidence line required.

**Vetter return shape** (structured, easy to parse):
```
chunkId: <id matching input>
concerns:
  - body: "<the concern>"
    evidence: "<what was checked>"
    recommend_fix: true|false
    anchor_file: "<new-side path of the line>"
    anchor_snippet: "<verbatim ~20-60 char substring of the exact + line the issue lives on, or empty if file-wide>"
suggestions:
  - body: "<the suggestion>"
    evidence: "<what was checked>"
    recommend_fix: true|false
    anchor_file: "<new-side path of the line>"
    anchor_snippet: "<verbatim substring of the exact + line, or empty if file-wide>"
strengths:
  - "<short bullet>"
```

For `anchor_snippet`, copy the text **verbatim from the diff** — do not paraphrase, do not count line numbers. The renderer locates the line by matching this string, so an exact copy of a distinctive part of the line is what makes the finding pin to the right place. Leave it empty only when the observation is genuinely file-wide.

If a chunk has nothing worth raising, return empty `concerns` and `suggestions`. Strengths may also be empty.

### 2.5.2 Collect and Number

Once all vetters return:
- Assign continuous numbering for Concerns and Suggestions across chunks (chunk 1's first concern is #1; if chunk 1 produced 2 concerns and 1 suggestion numbered 1-3, chunk 2 starts at #4). Strengths remain bulleted.
- Cache the vetted observations per chunk for Phase 3 rendering.

If a vetter call fails or returns malformed output, retry once. If it still fails, fall back to generating observations inline for that chunk during Phase 3, and note the fallback in the chunk header.

## Phase 2.6: Render HTML companion view (REQUIRED before Phase 3)

**CRITICAL: Phase 2.6 is mandatory. Do not skip it — not for small PRs, not under auto mode, not to save time. The HTML companion is the reader's primary surface; the terminal is a thin driver. If you skip this phase, the user has nothing to read.**

After Phase 2.5 has produced vetted observations for every chunk, render the HTML companion view that lives alongside the terminal walkthrough. The HTML is read-only: terminal continues to drive Phase 3 action prompts.

### 2.6.1 Assemble the JSON

Aggregate the gathered data into a single JSON object matching the contract documented in `~/.claude/scripts/walkthrough_render/fixtures/example.json`. Key fields:

- `pr`: owner, repo, number, title, author, head_branch, base_branch, additions, deletions, files_changed, state, url, ticket (optional `{id, url}`), updated_at
- `narrative`: the 2-4 sentence overview from Phase 2.7 (may contain `<code>` and other inline HTML)
- `chunks`: one entry per chunk from Phase 2.3 with id (1-indexed), title, category, files, intro, additions, deletions, diff (raw unified-diff text from `gh pr diff`), findings, strengths
- `findings`: each has id (continuous across the PR), type (`concern` / `suggestion`), summary (one-line, HTML allowed), body (full HTML), evidence (string), evidence_kind (`evidence` / `source`), recommend_fix (bool), anchor (`{file, snippet}` or null), thread (`{status, url, author}` or null)
  - **anchor**: `file` is the new-side path; `snippet` is a short, **verbatim** substring (≈20-60 chars) copied from the single `+`/context line where the issue is most actionable. **Do NOT count or guess line numbers** — LLMs miscount lines in long diffs, which mis-pins findings. The renderer searches the diff for the snippet and computes the real line number itself, then writes it to `anchors.json` (see 2.6.2). Pick a snippet distinctive enough to appear once in the file; if the issue is genuinely file-wide with no single line, use `null`.
- `skipped_files`: from Phase 2.5 categorization; each has path, additions, deletions, flag (optional warning string)
- `test_plan`: extracted from the PR body; `{present: true, items: [...]}` or `{present: false}`

Write this object to `/tmp/pr-walkthrough-{owner}-{repo}-{number}.json` (substituting actual owner/repo/number).

### 2.6.2 Invoke the renderer

```bash
python3 ~/.claude/scripts/walkthrough_render/render.py \
  /tmp/pr-walkthrough-{owner}-{repo}-{number}.json \
  /tmp/pr-walkthrough-{owner}-{repo}-{number}/
```

If the script exits non-zero, report the error and continue with the terminal walkthrough only — the HTML is a companion, not a blocker. Do not retry; surface the failure to the user and proceed.

The renderer resolves each finding's `anchor.snippet` to a real new-side line number and writes `anchors.json` in the output dir, mapping `f{id}` to `{file, line}`. Phase 3 reads this file for inline-comment targets, so neither you nor the renderer ever counts lines by hand. If the renderer prints `warning: ... snippet not found`, that finding had a snippet that didn't match the diff (treat it as file-wide for that finding); if it prints `anchor lines ... absent from diff`, a legacy line-number anchor pointed outside the diff. Either way the finding is demoted to file-wide rather than mis-pinned.

### 2.6.3 Open the overview

```bash
open /tmp/pr-walkthrough-{owner}-{repo}-{number}/overview.html
```

In conversation, tell the user: "Opened the HTML overview in your browser. The terminal will continue to drive action prompts; the HTML is for reading."

Then proceed to Phase 3.

## Phase 3: Interactive Chunk Walkthrough

### 3.1 Present Narrative Overview

Before the first chunk, present to the user:
- PR title and author
- The 2-4 sentence narrative summary from Phase 2
- Chunk count: "I'll walk you through N chunks of changes."
- One line confirming vetting ran, with totals: "Pre-vetted observations across N chunks: X concerns, Y suggestions flagged." (Skip the line if zero of each.)
- Skipped files summary with any flags for unexpected items
- **HTML companion pointer:** an explicit line stating the HTML overview was opened, e.g. "HTML companion opened: `/tmp/pr-walkthrough-{owner}-{repo}-{number}/overview.html` — use it as the primary reading surface; this terminal will drive action prompts." This line is REQUIRED. If you cannot write it because Phase 2.6 was not executed, stop and execute Phase 2.6 now before continuing.

Note: the same narrative and per-chunk data is also available in the HTML overview opened in Phase 2.6. The terminal version stays concise; the HTML is the deeper reading surface.

### 3.2 For Each Chunk: Two-Step Output

**CRITICAL: Observations MUST appear in conversation output (Step A), NOT inside AskUserQuestion (Step B). This ensures observations remain visible when the user interacts with the prompt.**

**Step A: Conversation output (persists in scroll-back):**

1. Chunk header: `## Chunk N of M: path/to/file.py` (list all files if the chunk contains multiple)

2. The 1-2 sentence context intro for this chunk.

3. The diff in a code block:
   ````
   ```diff
   [patch content]
   ```
   ````
   For renamed files with no content change: "File renamed from `old/path` to `new/path` (no content changes)"

4. **Observations:** Render the pre-vetted Concerns/Suggestions/Strengths cached in Phase 2.5 for this chunk. **Do NOT generate observations inline here** — that path produces unverified claims that fold under pushback. The vetting was done up front for that reason.

   Split into three sections. **Omit any section that has nothing** — do not write empty headers.

   **Concerns:** Numbered list of bugs, broken invariants, security/performance issues, missing error handling for real failure modes, suspicious one-way doors.

   **Suggestions:** Numbered list of quality refactors, design alternatives, naming/clarity improvements, missing tests worth raising.

   **Strengths:** Bulleted (not numbered) one-liners. Brief — do not enumerate everything good or litigate why it's good. Skip the section entirely if nothing notable stands out.

   **Formatting:** Put a blank line between each numbered item so the list doesn't run together as a wall of text. Each Concern and Suggestion is rendered as a single paragraph with Evidence inline at the end, in italic parens:

   ```
   1. <body of the concern/suggestion> [**[recommend fixing]** if flagged] *(Evidence: <what was checked, one line from Phase 2.5>)*
   ```

   **Do NOT put Evidence on its own line** (with or without indentation). Separate-line Evidence renders in some terminals as a duplicate numbered item ("1. concern ... 1. Evidence ..."), which looks broken. Keep Evidence inline in the same paragraph as the body so it stays grouped with its finding and the numbering reads cleanly.

   The italicized Evidence keeps the grounding visible. If the user asks "why do you think that?", point them to it first.

   **Numbering:** Use the continuous numbering assigned in Phase 2.5.2 (chunk 1 starts at #1; chunk 2 continues from where chunk 1 left off, across both Concerns and Suggestions sections). Strengths are bulleted, not numbered.

   **Recommendation marker:** Apply ` **[recommend fixing]**` based on the `recommend_fix: true` flag from Phase 2.5. If you'd recommend fixing an existing review comment from another reviewer, mark it too.

   **Chunk recap:** After the Concerns/Suggestions/Strengths sections, if any items in this chunk are marked `[recommend fixing]`, end with a one-line summary: `**Recommended:** #N, #M` listing the item numbers. Skip the line if nothing was recommended.

   If existing review comments reference lines in this chunk, include them as numbered Concerns using the same single-paragraph format, with the thread URL inline at the end in italic parens:

   ```
   N. Existing comment from @user on line K (`<status>`): <paraphrase or short quote, plus brief analytical context if useful>. *(Source: <html_url>)*
   ```

   `<status>` is `unresolved` / `resolved` / `outdated` (from Phase 1.2). The URL is required — without it the reader can't open the thread to verify what was said or whether it's still open. Paraphrase preferred for long threads; short verbatim quote fine when brief.

   If a chunk has no Concerns or Suggestions, write "No concerns spotted." Strengths section is still optional.

**Step B: AskUserQuestion (action prompt ONLY, no observations):**

- Question: "What would you like to do with this chunk?"
- Options (the option set is conditional on whether this chunk has any `[recommend fixing]` items):

  **If the chunk has one or more recommended items:**
  - **Comment on recommended fixes** (description: "Draft and post comments for #N, #M") — list the actual item numbers in the description, in the order they appeared in the chunk. This option goes FIRST to signal stance: the vetter already flagged these as worth fixing, so commenting is the expected default.
  - **Looks good** (description: "Approve this chunk and move to the next one")
  - **Leave a comment** (description: "Post a different comment on this chunk")

  **If the chunk has no recommended items:**
  - **Looks good** (description: "Approve this chunk and move to the next one")
  - **Leave a comment** (description: "Post a review comment on this chunk")

- Free-text hint: "Ask a question about this chunk"

**Handling responses:**
- **Comment on recommended fixes:** Enter the recommended-fix flow (3.3.1). Do NOT prompt "what to comment on" — the recommendations themselves are the targets.
- **Looks good:** Advance to the next chunk.
- **Leave a comment:** Enter free-form comment posting flow (3.3).
- **Free-text:** Answer the user's question in context, then re-present the same AskUserQuestion for this chunk. Do not advance.

  **When the user pushes back on an observation** (e.g., "isn't this handled in X?", "are you sure?"): first answer from the cached Evidence line for that item. State what was already checked and stand by the observation, or concede if the user surfaces new information you didn't have. Only re-explore the code if the user's pushback raises something the Phase 2.5 vetter didn't cover. Do *not* reflexively concede — the observation already cleared the verification bar, so a thoughtful "here's what I checked: ..." is the right starting move.

### 3.3.1 Recommended-Fix Flow

When the user selects "Comment on recommended fixes":

1. For each `[recommend fixing]` item in this chunk, in order, draft an inline comment:
   - Use the `jeff-github-review-voice` skill if available; otherwise draft in a direct, declarative tone (point out the problem, not a question).
   - Target line comes from `anchors.json` (written by the renderer in 2.6.2): look up `f{id}` for the `{file, line}` to comment on. Do NOT recount lines yourself. If the item has no entry there (file-wide or unresolved snippet), treat it as a general PR comment.
   - Keep the comment focused on the specific finding — do not bundle multiple items into one comment.

2. Present all drafted comments together in conversation output, one per item, with their inferred targets. Format:
   ```
   #N → path/to/file.py:K
   <drafted comment body>
   ```

3. Use a single AskUserQuestion to batch-confirm:
   - Question: "Post these comments?"
   - Options:
     - **Post all** (description: "Submit every drafted comment as-is")
     - **Edit one** (description: "Revise a specific comment before posting")
     - **Skip one** (description: "Drop a specific comment from the batch")
     - **Cancel** (description: "Discard all drafts and return to chunk")
   - Free-text hint: "Describe edits or which to skip"

4. Handle the response:
   - **Post all:** Post each comment via the pending MCP review (same mechanism as 3.3 step 4). Confirm each post.
   - **Edit one / Skip one:** Resolve the user's intent for the named item(s), then re-present the updated batch and ask again.
   - **Cancel:** Discard the drafts and return to the chunk's AskUserQuestion.

5. After posting, return to the same chunk's AskUserQuestion. The user may still want to leave a free-form comment or move on.

### 3.3 Comment Posting Flow

When the user selects "Leave a comment":

1. Output a plain text prompt and wait for the user's reply. Do NOT use AskUserQuestion here — it surfaces guessed option chips that get in the way.

   Example prompt: "What would you like to comment on?"

   The user's reply is free-form. Infer from context what they want:
   - **Ready-to-post comment text** → use it verbatim as the comment body.
   - **Multiple comments in one response** (e.g., two distinct points, or a list) → treat each as a separate comment and post them individually, inferring the target line for each.
   - **Notes / ideas for drafting** (e.g., "raise the concern about the cache TTL, mention X") → draft the comment in their voice (consult the `jeff-github-review-voice` skill if available) and confirm the drafted text before posting.
   - **A question or request for help** → answer it in conversation, then re-prompt.

   When in doubt about whether the reply is verbatim text or drafting notes, ask a single short clarifying question rather than guessing.

2. **Infer the target from context.** Do NOT ask the user where to post. Instead:
   - Read the comment text and match it against the chunk's diff to determine the most relevant file and line.
   - Choose the line where the issue is most actionable for the author (where the fix should go, not where the symptom appears).
   - If the comment doesn't map to a specific line, treat it as a general PR comment.

3. **Confirm before posting.** Present your inferred target in conversation output:
   - Line-level: "I'll post this on `path/to/file.py` line N. OK?"
   - General: "I'll post this as a general PR comment. OK?"
   - Use AskUserQuestion with options: **Post it** / **Change target** (free-text: specify file and line) / **Cancel**
   - If the user selects "Change target", use their specified file/line instead.

4. Post the comment:
   - **Line-level:** Use MCP `mcp__plugin_github_github__pull_request_review_write` to create a pending review if one hasn't been started yet. Then use MCP `mcp__plugin_github_github__add_comment_to_pending_review` with the file path, line number, and comment body. Pending review accumulates comments across chunks and is submitted in Phase 4.
   - **General:** `gh pr comment {number} --body "{comment}" --repo {owner/repo}`

   **Do NOT also copy the comment to the clipboard.** Posting to the PR is the action; clipboard copy is redundant. Only `pbcopy` the comment if the user explicitly asks for it.

5. Confirm the comment was posted. Return to the same chunk's AskUserQuestion (the user may want to leave additional comments).

## Phase 4: Review Summary & Submission

### 4.1 Recap

After all chunks have been presented, output in conversation:
- Total chunks reviewed
- Number of comments posted (line-level and general)
- Concerns Claude flagged that were not addressed via a comment (omit observations the user already approved or commented on)
- **Recommended fixes still open:** list every `[recommend fixing]` item from the walkthrough that the user did not comment on or otherwise address, by number and one-line description. If everything recommended was addressed, say so explicitly.

### 4.2 Smoke Test Option

Before asking for final disposition, offer the user the chance to smoke test the changes.

Use AskUserQuestion:
- Question: "Want to smoke test the changes before deciding?"
- Header: "Smoke test"
- Options:
  - **Yes, smoke test** (description: "Evaluate the PR's test plan and run a smoke test against the changes")
  - **Skip, go to disposition** (description: "Skip smoke testing and decide on approval now")

If the user picks **Skip**, jump to 4.3.

If the user picks **Yes**, run the smoke test flow:

**4.2.1 Evaluate the PR's stated test plan.**

Re-read the PR description for any test plan section (commonly under headings like `## Test plan`, `## Testing`, `## How to test`). Output a brief assessment in conversation:
- **Coverage:** Which of the PR's behaviors does the stated plan actually exercise?
- **Gaps:** Use cases, edge cases, or regressions the plan misses, drawn from the Concerns/Suggestions surfaced in Phase 2.5 and the diff itself.
- **Misleading or stale steps:** Anything that no longer applies, references removed code, or would pass even if the change were broken.

If the PR has no test plan, say so and proceed to build one from scratch.

**4.2.2 Build a smoke test plan.**

Synthesize a focused plan that covers the golden path plus the gaps identified in 4.2.1. Keep it tight: aim for the smallest set of steps that exercises the PR's actual behavior changes and any high-risk edge cases. For each step, state:
- What to do (command, URL, UI action, API call, etc.)
- What to expect (the observable signal that proves the change works)
- Why it matters (which behavior or risk it covers)

Present the plan in conversation, then use AskUserQuestion:
- Question: "Run this smoke test plan?"
- Header: "Run plan"
- Options:
  - **Run it** (description: "Execute the smoke test plan as written")
  - **Adjust the plan** (description: "Edit steps before running")
  - **Cancel smoke test** (description: "Skip smoke testing and go to disposition")
- Free-text hint: "Describe edits to the plan"

If the user picks **Adjust**, incorporate their edits and re-confirm before running. If **Cancel**, jump to 4.3.

**4.2.3 Execute the plan.**

Walk through the steps with the user. For automatable steps (commands, file checks, etc.), run them directly. For manual steps (UI clicks, external systems), prompt the user and capture their reported result. After each step, record pass/fail and any unexpected output.

**4.2.4 Summarize smoke test results.**

Output a concise summary in conversation:
- Steps run, passed, failed
- Any failures with the observed vs. expected behavior
- New Concerns that emerged (number them continuing from Phase 2.5's sequence so they fold into the recap cleanly)

Smoke test results feed into 4.3. If failures surfaced new issues, recommend `Request changes` or `Comment only` in the disposition prompt; if everything passed and earlier Concerns are resolved, lean toward `Approve`. The user still picks; this is just an informed default.

### 4.3 Final Review Disposition

Use AskUserQuestion to ask how to submit the review:

- **Approve** (description: "Submit approval with no comment")
- **Approve with comment** (description: "Submit approval with a summary comment")
- **Comment only** (description: "Submit as comment, no approval or rejection")
- **Request changes** (description: "Request changes with a summary of what needs fixing")

**Handling responses depends on whether a pending MCP review exists from Phase 3 line-level comments.**

**If NO pending MCP review exists** (no line-level comments were posted, only general comments or none):

- **Approve:** `gh pr review {number} --approve --repo {owner/repo}`
- **Approve with comment:** Ask for text, then `gh pr review {number} --approve --body "{comment}" --repo {owner/repo}`
- **Comment only:** Ask for text, then `gh pr review {number} --comment --body "{comment}" --repo {owner/repo}`
- **Request changes:** Ask for summary, then `gh pr review {number} --request-changes --body "{summary}" --repo {owner/repo}`

**If a pending MCP review EXISTS** (line-level comments were accumulated via `add_comment_to_pending_review`):

Submit the pending review via MCP `mcp__plugin_github_github__pull_request_review_write` with the appropriate event type. This submits all accumulated inline comments as part of the review. The event types map to:
- **Approve:** submit with event `APPROVE`
- **Approve with comment:** ask for text, submit with event `APPROVE` and body
- **Comment only:** ask for text, submit with event `COMMENT` and body
- **Request changes:** ask for summary, submit with event `REQUEST_CHANGES` and body

Do NOT use `gh pr review` when a pending MCP review exists; that would create a separate review without the inline comments.

Do NOT auto-generate a comment body. "Approve" means approve silently. Only include a body if the user explicitly provides one.

---

## Important Notes

- All GitHub interaction uses `gh` CLI or GitHub MCP tools. Do not use `gh api`.
- When posting comments, properly escape special characters for the shell.
- If a `gh` command fails, show the error and offer to retry or skip.
- Be concise in chunk intros and observations; the user is here to review code, not read essays.
- If a chunk is trivial (e.g., a single-line import change), say so briefly and keep the intro and observations short.
- If the user skips several chunks in a row, don't slow down with lengthy intros.
