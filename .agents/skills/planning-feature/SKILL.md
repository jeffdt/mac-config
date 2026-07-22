---
name: planning-feature
description: >-
  This skill should be used when the user asks to "plan a feature", says "let's plan...", "plan this
  work", "plan out this feature", or otherwise signals they want to kick off structured feature
  planning. Owns the end-to-end flow: brainstorm, design spec with contracts and testing strategy,
  sequencing analysis, per-repo session prompts. Assumes the user is working inside a
  ~/Klaviyo/projects/ or ~/p/ directory; errors out if not. The /project:plan command is a thin
  wrapper around this skill. Do NOT fire on generic planning language like "what's the plan for today"
  or "plan the week"; only fires on planning a feature, project, or piece of engineering work.
---

# Planning a Feature

Plan a multi-repo feature from idea through to per-repo session prompts. This skill produces design specs and contracts, NOT implementation plans. Repo-local agents create their own implementation plans with full access to local conventions.

**Feature topic:** Use the feature topic from the user's message or the `Feature topic:` line passed by `/project:plan` as the seed for brainstorming. If none provided, ask the user what they want to plan.

---

## Step 1: Detect Project

Run `pwd` to check if the cwd is under `~/Klaviyo/projects/` or `~/p/`.

- **If yes**: Extract the project name. Read `CLAUDE.md` to get the repo list and project context. Proceed.
- **If no**: Error with "Run this from within a project directory (`~/Klaviyo/projects/<name>` or `~/p/<name>`)."

---

## Step 2: Brainstorm

Invoke the `superpowers:brainstorming` skill. Pass the feature topic as the seed if provided.

**Override:** instruct brainstorming to defer its user-approval gate. Include this in your invocation: "After you complete the Spec Self-Review step, return control to planning-feature without executing the User Review Gate. Planning-feature owns the spec approval gate and will present the spec alongside additional adversarial input." (Brainstorming's instruction-priority hierarchy lets the caller override its default flow.)

The brainstorming skill will:
1. Explore project context
2. Ask clarifying questions
3. Propose approaches
4. Present the design
5. Write the spec to `specs/YYYY-MM-DD-<feature>-design.md` (record the **absolute path** for later steps)
6. Run the spec review loop
7. **Return control to planning-feature WITHOUT executing the User Review Gate** (per the override above)

**Multi-repo context to inject during brainstorming:**
- Organize by repo boundary. Flag cross-repo dependencies explicitly. Identify which repo owns each contract.
- The design spec MUST include a **Target Working Directory** per repo. Use the deepest directory whose subtree contains all planned changes for that repo, capped at service/component granularity:
  - Monorepos (k-repo): the service directory (e.g. `~/r/k-repo/python/klaviyo/executive_business_report/insights_service`), never deeper into individual subpackages/modules
  - Component-style repos (fender, app): the component or feature area
  - When uncertain or work spans the repo broadly: the repo root

  **Why this matters:** Claude Code loads `CLAUDE.md` files and path-scoped skills at session init by traversing up from cwd. Init-time context survives compaction; runtime discovery does not. Launching at the service/component level loads the deepest applicable `CLAUDE.md` plus all ancestors automatically.

  Each repo's section in the design spec should include a `**Target cwd:** <absolute path>` line that the agent records during brainstorming.
- The design spec MUST include a **Contracts** section defining all cross-repo boundaries:
  - API request/response schemas (JSON shapes, HTTP methods, status codes)
  - Event payload schemas
  - Shared type definitions
  - Error contracts (error codes, error response format)
  - Authentication/authorization expectations at boundaries
- The design spec MUST include a **Testing Strategy** section per repo describing:
  - How to locally verify the changes work (e.g., run existing test suites, curl an endpoint, trigger an event)
  - Which cross-repo boundaries need stub/mock services for local testing vs can be tested end-to-end
  - Any test data setup or environment prerequisites
  - This section describes the verification APPROACH, not specific test cases or assertions
- The design spec MUST include an **Observability** section describing what production visibility the feature needs:
  - New metrics, logs, or traces required (name, dimensions/fields, what question they answer)
  - Existing instrumentation the feature relies on (and whether it's sufficient)
  - Cross-repo observability contracts (shared trace IDs, correlation fields, consistent log keys across boundaries)
  - What on-call needs to see when this fails (alerts, dashboards, log queries)
  - If genuinely none is needed, a one-line "no new instrumentation; existing X is sufficient" is acceptable and preferred over a fabricated list. The point is forcing the question, not bloating the spec.

**What NOT to include in the design spec:**
- Exact file paths or function signatures (the repo agent will determine these)
- Step-by-step implementation instructions
- Specific test cases, assertion logic, or test file structure (the repo agent determines these; the spec's Testing Strategy covers the approach)
- Utility or helper choices (the repo agent knows its local toolbox)
- Specific logger calls, metric client invocations, or log/trace field plumbing (the repo agent knows its local instrumentation libraries; the spec's Observability section covers WHAT to instrument and the cross-repo contract, not HOW)

The spec should describe WHAT each repo needs to do and the contracts it must satisfy, not HOW to implement it.

---

## Step 2.5: Codex Adversarial Review of the Spec

Before the user reviews the spec, run Codex as an adversarial reviewer to surface design problems early, when changing direction is cheap.

Invoke (foreground, blocking; the user is waiting for the gate in Step 2.6):

```bash
node "$(ls -t ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | head -1)" task --wait --fresh "Review the design spec at <absolute-spec-path>. Adversarially challenge the proposed approach, hidden assumptions, cross-repo contracts, failure modes, rollback/idempotency gaps, and any decisions that seem premature or under-specified. Prioritize issues expensive to fix after implementation begins. Return findings organized by severity (Critical/Important/Suggestion). Do not review it as code; review it as a design artifact."
```

`<absolute-spec-path>` is the path recorded in Step 2 (item 5). The codex-companion script is resolved from the plugin cache at invocation time (latest installed version wins, robust to upgrades). Do not substitute `${CLAUDE_PLUGIN_ROOT}` here, that variable is only populated when the harness is invoking a component of the codex plugin itself; this skill runs outside that context.

If the Codex CLI is unavailable (non-zero exit, missing `codex`, auth missing), do not block the workflow. Note "Codex spec review unavailable" and proceed to Step 2.6 with just the spec.

Capture Codex's stdout for use in Step 2.6.

---

## Step 2.6: Spec Approval Gate

Present to the user, in order:
1. The spec file's absolute path (so they can open it).
2. Codex's review output verbatim (or "Codex spec review unavailable" if Step 2.5 failed).
3. A clear ask: approve, revise, or rethink.

User options:
- **Approve as-is** → proceed to Step 3 (Sequencing).
- **Revise** → loop: brainstorming makes the requested changes, re-runs spec self-review, then re-runs Step 2.5 against the revised spec. Re-present the gate. Repeat until approved or discarded. There is no maximum revision count; the user controls.
- **Discard / rethink** → kill the planning flow.

Do not auto-approve based on Codex's verdict. Codex's role is to surface issues, not to gate progression. The user decides.

---

## Step 3: Discuss Sequencing

After the spec is approved, present a sequencing analysis to the user. The goal is NOT to dictate order (the user controls merge timing), but to surface dependency reasoning so they can make informed decisions.

Present:
1. A boxes-and-arrows dependency graph. Separate independent parallel tracks with a dashed divider. Example:
```
┌─────┐
│ app │
└─────┘
─ ─ ─ ─ ─ ─ ─ ─ ─ ─
┌────────┐     ┌───────┐
│ k-repo │ ──→ │ infra │
└────────┘     └───────┘
```
2. For each dependency edge, explain WHY (e.g., "infra must land first because k-repo needs the secret env vars at runtime" vs "infra can land in any order because scrape failures are harmless")
3. Call out exceptions to usual patterns (e.g., "normally infra lands before k-repo, but in this case...")

Keep it conversational; this is a discussion, not a gate. The user may have context about deploy timing that changes the picture. Wait for acknowledgment before proceeding.

---

## Step 4: Generate Session Prompts

After the design spec is approved and sequencing is discussed:

1. Create `prompts/` directory if it doesn't exist: `mkdir -p prompts`
2. Derive the feature slug from the spec filename
3. Write `prompts/<feature>.md`:

````markdown
# <Feature Name>: Session Prompts

One prompt per repo. Open a Claude Code session in the target repo and paste.

**Design spec:** `<absolute path to spec>` (use the absolute path from Step 2)

---

## 1. <repo> (`<target_cwd>`)

```
I need to implement the <repo> portion of <feature name>.

Design spec: <absolute path to spec>

<2-4 sentence summary of what THIS repo needs to do, written from the perspective of this repo>

Contracts this repo owns:
<paste the specific contracts this repo must implement, extracted from the spec's Contracts section>

Contracts this repo consumes:
<paste contracts from other repos that this repo calls or depends on>

You are already inside a fresh worktree on the correct branch, with cwd set to `<target_cwd>` — do NOT create another worktree, and do NOT cd up. The init-time context for this directory has been loaded. Use /superpowers:writing-plans to create an implementation plan from this spec. Your implementation plan MUST include a local testing plan: what to test, commands to run, manual verification steps, and any mock/stub setup needed for cross-repo dependencies. Do NOT execute the testing plan during implementation; it runs after code review and refactoring have stabilized the code. Your implementation plan MUST also realize the spec's Observability section using this repo's local instrumentation libraries and conventions: emit the metrics/logs/traces the spec calls for, honor any cross-repo correlation fields (e.g., shared trace IDs, request IDs), and flag any observability gap you notice that the spec missed. If the spec says no new instrumentation is needed, confirm by reading the existing instrumentation you'll rely on, and surface any mismatch before implementing.

When writing-plans saves the plan and offers the execution-approach choice, pause before answering. First run Codex adversarial review against the plan:

```bash
node "$(ls -t ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | head -1)" task --wait --fresh "Review the implementation plan at <absolute-plan-path>. Design spec context: <absolute-spec-path>. Adversarially challenge the planned approach, function signatures, retry/error handling, test coverage gaps, hidden assumptions about the runtime, and any steps that conflict with the spec's contracts. Prioritize issues expensive to fix once code is written. Return findings organized by severity (Critical/Important/Suggestion)."
```

Both file paths must be absolute. Pass the spec path even though the plan references it; Codex's cross-document reasoning catches contract drift between spec and plan that single-artifact review misses.

Present the plan and Codex's critique together to the user. The user approves, revises, or discards. On revise, update the plan and re-run Codex; loop until approved (no max revisions; the user controls). Do not auto-approve based on Codex's verdict; the user decides. If Codex is unavailable, note "Codex plan review unavailable" and proceed with just the plan.

When writing-plans finishes and asks you to choose an execution approach, pick option 1 (Subagent-Driven). Execute the plan with superpowers:subagent-driven-development: per task, dispatch a fresh implementer, then the spec-compliance reviewer, then the code-quality reviewer, looping on fixes until both reviewers approve before moving on. Do not choose Inline Execution; the two-stage review is the verification floor.

After all tasks pass both reviews, use /gcpr to commit, push, and create a draft PR. Then run /pr:temper to review and refine the PR.

After /pr:temper finishes, use AskUserQuestion to ask whether to monitor CI and address feedback automatically (default: no). If yes: wait for the Buildkite build on the current HEAD to reach a terminal state via `mcp__buildkite__wait_for_build` (if that tool isn't available, fall back to `gh pr checks --watch --interval 60`, re-running if it hits the Bash timeout). Once the build is terminal, run /pr:hospital — it will auto-fix high-confidence CI failures and clear bot feedback, and surface ephemeral/needs-investigation items and debatable feedback for your confirmation.
```

## 2. <repo2> (`~/r/<repo2>`)

```
<same structure, different repo-specific content>
```
````

Each prompt must be **self-contained**: the repo agent should not need to read other repo prompts or understand the full cross-repo picture. Include enough contract detail inline that the agent can plan and build independently.

Repos listed alphabetically. Use absolute paths for the spec so prompts work when pasted into sessions rooted in different directories.

### Per-Repo Prompt Files

For each repo, also write `prompts/<feature>-<repo>.md` containing ONLY the raw prompt text (no markdown headers, no code fences, no surrounding commentary). These files are piped directly into `claude` as initial input.

---

## Step 5: Launch Sessions

Display (all paths absolute):
- Design spec absolute path
- Combined prompts file absolute path
- Per-repo prompt file paths

For each repo, derive a branch name following the `jeffdt/<domain>-<brief-kebab-description>` convention. The domain reflects the feature area; the brief description is concise kebab-case (drop filler words). Each repo gets its own branch; branch names may be shared across repos for the same feature.

**Before launching**, ask the user which agent CLI to use for implementation sessions, via `AskUserQuestion`. One global choice applies to all repos in this plan:

- **pi** (default) — sessions launch as an interactive `pi "$(cat <prompt>)"` seeded with the prompt, relying on pi's configured provider/model/thinking defaults. This is the standard path: claude handles orchestration and planning (this session), and the narrowly scoped per-repo implementation is delegated to pi.
- **claude** — sessions launch with `cat <prompt> | claude`. Choose when the implementation work is itself complex or orchestration-heavy and benefits from staying on claude.
- **codex** — experimental; sessions launch with `codex --full-auto "$(cat <prompt>)"`. Use for the Claude-plan / Codex-implement A/B test. `--full-auto` is `-a on-request --sandbox workspace-write`: Codex can still ask for approval, writes are sandboxed to the workspace.

Pass the answer through to the launch script as `--cli claude|codex|pi`.

Invoke `scripts/plan-launch-sessions.sh` (absolute path: `/Users/jeff.diteodoro/.agents/scripts/plan-launch-sessions.sh`), passing `<repo_path> <prompt_path> <branch> <subdir_relative>` 4-tuples (alphabetical by repo) as positional args. `<subdir_relative>` is the path relative to the repo root that the new session should `cd` into before launching the agent; derive it from the spec's `Target cwd` for that repo (`.` if the target cwd is the repo root itself):

```bash
/Users/jeff.diteodoro/.agents/scripts/plan-launch-sessions.sh \
  --cli <claude|codex|pi> \
  <abs-repo-1> <abs-prompt-1> <branch-1> <subdir-1> \
  <abs-repo-2> <abs-prompt-2> <branch-2> <subdir-2>
```

The script:
- Detects whether the planner is running inside tmux (via `mux status`).
- **Inside tmux**: spawns one new tab/window per repo in the session that hosts this planning session (resolved via `mux status --json`), regardless of which session the user is currently viewing in the UI. Tabs don't steal focus; they stack in the calling session's workspace.
- **Outside tmux**: pipes each launch command through `pbcopy` with a short sleep between, so the clipboard manager captures each as a distinct history entry.
- Prints the full launch command for each repo (in both modes), plus a final `done: N session(s): <repos>` summary.
- Exits non-zero if any repo path is missing, a prompt file is missing, or a `mux spawn` call fails. Paths must be absolute and contain no spaces.

Surface all launched output from the script verbatim so the user sees which mode was used and which sessions were started. The script's printed launch command IS the command it sent — do not author a separate preview string above the invocation; that creates a second source of truth that can drift from what actually ran.

**Do NOT bypass the script.** If `mux spawn` errors, if a workspace lookup fails, or anything else goes wrong, debug and fix the script — do not spawn tabs/windows manually as a workaround. Manual spawning re-authors the launch payload by hand, which is exactly how `cd <repo>` gets dropped and a worktree is created against the wrong repo.
