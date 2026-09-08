---
name: reviewing-prs
version: 1.0.0
description: "Use before reviewing an existing GitHub pull request, checking whether a PR is ready to merge, or responding to requests such as \"review PR #123\", \"look at this pull request\", or \"review the PR for my current branch\". Runs orchestration in the main session and directly dispatches specialized reviewers so the Claude task hierarchy stays at two layers."
---

# Reviewing Pull Requests

Run this workflow in the main conversation. Do not launch a `pr-review` agent or delegate orchestration to another agent. Assess PR complexity, directly dispatch 3 specialized reviewer subagents for medium/large PRs, and synthesize their findings. This keeps the Claude task hierarchy to two layers: main session → specialized reviewers.

**Resolve the PR:**

- If the user supplied a PR number or URL, use it.
- Otherwise, find PRs for the current branch with `gh pr list --head "$(git branch --show-current)"`.
- If exactly one PR is found, use it. If multiple PRs are found, ask which one to review. If none are found, report that and stop.

**Step 1 — Fetch PR Data**

Determine the repository owner and name from `gh repo view --json owner,name` (or from context if already known).

Gather the PR information concurrently, following the `github-pr-routing` skill:

1. `gh pr view <number> --json number,url,title,body,state,author,labels,headRefName,baseRefName,files,additions,deletions` — metadata and changed-file summary
2. `gh pr diff <number>` — complete diff
3. `gh pr checks <number>` — CI status
4. `gh pr view <number> --comments` — general PR comments
5. `mcp__plugin_github_github__pull_request_read` with `method: "get_review_comments"` and `perPage: 100` — threaded review comments with resolution status

**Step 2 — Extract and Fetch Ticket**

Look for a ticket reference in this priority order:

1. **PR description body** — check for Linear URL: `https://linear.app/klaviyo/issue/PROJ-123`
2. **PR description body** — bare mentions matching `[A-Z]{2,10}-[0-9]+`
3. **PR title** — often prefixed like `[PROJ-123] Feature description`
4. **Branch name** — patterns like `feature/PROJ-123-description`

If a ticket is found, fetch it with `mcp__plugin_linear_linear__get_issue`.

If no ticket is found, proceed without ticket context.

**Step 3 — Assess Complexity**

Determine the PR's complexity tier using these guidelines:

| Signal | Small | Medium | Large |
|--------|-------|--------|-------|
| Lines changed | <50 | 50-500 | >500 |
| Files changed | 1-3 | 4-15 | >15 |
| New files | 0 | 1-3 | >3 |
| Nature | Bug fix, typo, config | Feature, moderate refactor | Major feature, new system |

These are guidelines, not hard rules. Use judgment — a 30-line auth change may warrant the full pipeline due to security sensitivity.

**Step 4 — Route Based on Complexity**

- **Small PR**: Perform a single-pass inline review yourself, AND in the same response fire the Codex Bash call:
  ```bash
  node "$(ls -t ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | head -1)" review --wait --scope branch
  ```
  Then proceed to **Step 7** with both your inline analysis and Codex's output as inputs to the synthesis. Codex always runs; small PRs can be small-but-critical (auth, migrations), and second-opinion value is the same regardless of PR size.
- **Medium or Large PR**: Continue to **Step 5**.

**Step 5 — Read Reviewer Prompts**

Read all 3 reviewer prompt files from `/Users/jeff.diteodoro/.agents/agent-prompts/pr-review/`:
- `meta.md`
- `code-quality.md`
- `security-and-performance.md`

**Step 6 — Dispatch Specialized Reviewers (Including Codex)**

Launch 4 parallel review sources directly from the main session in a single response so they run concurrently:

- 3 Claude Task subagents using `subagent_type: "general-purpose"` (Meta, Code Quality, Security & Performance); each prompt combines the reviewer's instructions with the relevant PR context.
- 1 Codex review via Bash, invoking the codex-companion runtime against the branch diff:

```bash
node "$(ls -t ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | head -1)" review --wait --scope branch
```

The Codex call resolves the codex-companion script from the plugin cache at invocation time (latest installed version wins, robust to upgrades). `CLAUDE_PLUGIN_ROOT` is intentionally NOT used here because this agent is a user agent, not a component of the codex plugin, so that variable is unset at Bash time. Codex's review covers the same branch diff vs the default base that Claude reviewers see. It acts as a second LLM perspective on the same code, not a different review framing.

Mix Bash and Task tool calls in the same parallel response. Claude Code will execute them concurrently.

**Model selection per tier:**

| PR Complexity | Meta | Code Quality | Security & Performance | Codex | Synthesizer |
|---|---|---|---|---|---|
| Medium | sonnet | sonnet | sonnet | (default) | current main-session model |
| Large | sonnet | opus | opus | (default) | current main-session model |

Set the `model` parameter on each Task accordingly. Meta always uses `sonnet`. Codex uses its built-in review model. Pass no model flag.

**What context to pass to each reviewer:**

- **Meta**: PR metadata (title, description, author, labels, branch), CI check status, PR comments/reviews, list of changed files (names only). Do NOT include the diff.
- **Code Quality**: The full PR diff AND the PR description (for understanding intent).
- **Security & Performance**: The full PR diff AND the PR description (for rollout/deployment context).
- **Codex**: No prompt context needed. `--scope branch` resolves the diff against the default base from the working tree. Codex reads the diff itself.

Each Task prompt should be structured as:
```
[Paste the reviewer prompt file content here]

Do not launch subagents. Perform this review yourself and return your findings directly to the parent session.

---

## PR Context

[Paste the relevant context here]
```

Launch all 3 Tasks AND the Codex Bash call directly from the main session in a single message so they run in parallel.

**Step 7 — Synthesize Unified Report**

Collect findings from all sources:
- Medium/Large PRs: 3 Claude Task reviewers (Meta, Code Quality, Security & Performance) + Codex review output.
- Small PRs: your inline analysis + Codex review output.

Codex's output is prose with structured findings (severity, file:line refs, recommendations). Treat it as one more reviewer source for dedup and merge purposes. Deduplicate findings that overlap across reviewers. Rank by severity. Produce this exact report format:

```markdown
## Ticket Context
[From ticket fetch — ticket link, summary, acceptance criteria. Omit section if no ticket found.]

## PR Overview
- What the PR does (2-3 sentences)
- Complexity tier assessed: Small / Medium / Large
- CI Status: Passing / Failing (details)
- Codex: [one of the three states below — MANDATORY, never omit]
  - `ran — N findings incorporated (X unique to Codex)` if Codex returned findings
  - `ran — no findings` if Codex completed cleanly with nothing to flag
  - `unavailable — <reason>` if the Bash call failed (e.g. `permission denied`, `CLI not installed`, `auth missing`, `timeout`, `non-zero exit: <code>`)

## Risk Profile

| Dimension | Rating | Detail |
|-----------|--------|--------|
| Scale | [Small / Medium / Large / XL] | [N files, +X/-Y lines, N new files] |
| Blast Radius | [Narrow / Moderate / Wide] | [what's affected if a bug slips through] |
| Sensitivity | [Low / Elevated / High / Critical] | [domains touched: auth, billing, data models, etc.] |
| Reversibility | [Easy / Moderate / Difficult] | [rollback constraints: migrations, API contracts, etc.] |

[If all dimensions are Low/Small/Narrow/Easy, compress to a single line: "Low risk — small, isolated change with easy rollback."]

## Outstanding Comments
[From Meta PR — unresolved human and bot comments, summarized. Omit if none.]

## Findings

**ID scheme (MANDATORY):** Every item in Critical, Important, Suggestions, and Notes MUST carry a prefix code so users can reference it in followup conversation. Use `C1, C2, ...` for Critical, `I1, I2, ...` for Important, `S1, S2, ...` for Suggestions, `N1, N2, ...` for Notes. Numbering restarts within each section. Never emit a plain bullet or a naked number in these sections. Strengths remain unnumbered bullets (rarely referenced).

### Critical (Blocking)
[Severity-ranked. Each tagged with a concern category.]
- **[C1] Security**: [finding] (file:line)
- **[C2] Correctness**: [finding] (file:line)

### Important (Should Fix)
- **[I1] Reliability**: [finding] (file:line)
- **[I2] Performance**: [finding] (file:line)
- **[I3] Maintainability**: [finding] (file:line)

### Suggestions (Non-blocking)
- **[S1] Convention**: [finding] (file:line)
- **[S2] Maintainability**: [finding] (file:line)

## Strengths
[Positive observations from across reviewers, unnumbered bullets.]

## Notes (Optional)
[Contextual observations that aren't findings, e.g. coverage stats, follow-up ticket candidates, ambient caveats. Omit the section if there are none.]
- **[N1]** [observation]
- **[N2]** [observation]

## Alignment with Requirements
[Does the implementation address the ticket? Omit if no ticket found.]
- Requirements Met
- Potential Gaps
- Clarification Needed

## Verdict
Status: Approved / Conditional Approval / Needs Changes

Code Quality   ●●●●○  4/5
Security       ●●●●●  5/5
Test Coverage  ●●●○○  3/5
Architecture   ●●●●○  4/5
Documentation  ●●●○○  3/5

Risk: [Low / Elevated / High / Critical] — [one sentence synthesizing scale, blast radius, sensitivity, and reversibility]

(Use ● for filled and ○ for empty. Align columns. Risk uses a qualitative label, not a numeric rating, because risk is orthogonal to quality.)

Summary: [2-3 sentences with clear next steps]
```

**Synthesis Rules:**
- If multiple reviewers flag the same issue, keep only the most detailed version and note which reviewers flagged it
- Codex is one of the reviewers for dedup purposes. If Codex and a Claude reviewer flag the same issue, dedup as you would across two Claude reviewers. If Codex flags an issue no Claude reviewer caught (or vice versa), keep it. That's exactly the second-opinion value.
- Track two counts for the PR Overview Codex line: `N` = total findings from Codex that survived dedup into the final report, `X` = of those, how many were unique to Codex (not also flagged by any Claude reviewer). `X` is the second-opinion signal — when it's consistently 0, Codex isn't earning its keep on this PR mix.
- Findings severity: Critical > Important > Suggestion. Promote any finding to Critical if it could cause data loss, security breach, or production outage.
- If a findings section has no items, omit it entirely — do not include empty sections
- Tag each finding with a concern category in bold: **Security**, **Performance**, **Correctness**, **Reliability**, **Maintainability**, or **Convention**. These replace reviewer source tags.
- The Verdict ratings should reflect the synthesized view across all reviewers
- **Risk Profile**: Synthesize Scale from Meta's change scale metrics (file/line counts, breakdown). Synthesize Blast Radius, Sensitivity, and Reversibility from Security & Performance's risk signals. For small PRs where you do inline review, assess all four dimensions yourself. The Verdict's Risk line should be a single-sentence synthesis of the Risk Profile table.
- End on a constructive note with clear next steps

**Important Reminders:**
- Always start by fetching PR data — never review without the actual diff
- If the Codex Bash call fails (non-zero exit, permission denied, codex CLI not installed, auth missing, timeout), do not block the review; proceed with the Claude reviewer outputs only. Record the failure in the PR Overview Codex line as `unavailable — <reason>`, citing the most specific cause you can extract from the bash output (e.g. `permission denied`, `auth missing`, `non-zero exit: 1`). Do not retry.
- Be thorough but concise. Quality over quantity in findings.
- Distinguish blocking vs non-blocking issues clearly
- Acknowledge good decisions and well-written code
- If everything looks good, say so — do not invent problems
- Use file:line references for all code-specific findings
- **Prefix codes are non-negotiable.** Every item under Critical, Important, Suggestions, and Notes MUST start with its `[C#]`, `[I#]`, `[S#]`, or `[N#]` tag. This is how the user references items in followup conversation; a review missing these IDs is a defective review. Before emitting the final report, scan every bullet in these sections and confirm each one has its prefix. If you catch a missing or wrong prefix, fix it before sending.


## Smoke Test Offer

After presenting the review report, ask whether the user wants to smoke test the changes. If they decline, stop.

If they accept:

1. Re-read the PR description and briefly assess what its test plan covers, what it misses, and whether any steps are stale or could pass despite a regression. If there is no test plan, say so.
2. Build a focused smoke-test plan covering the golden path and identified gaps. For each step, state the action, expected result, and why it matters.
3. Ask the user to approve or adjust that plan before execution.
4. Run automatable steps directly. Guide the user through manual steps and record their reported results.
5. Summarize steps passed and failed, observed versus expected behavior, any new issues, and whether the results change the review verdict.
