# Session Prompt Template

Full detail for Step 4 (Generate Session Prompts): file structure and the per-repo prompt body.

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

You are already inside a fresh worktree on the correct branch, with cwd set to `<target_cwd>` — do NOT create another worktree, and do NOT cd up. The init-time context for this directory has been loaded. Use /superpowers:writing-plans to create an implementation plan from this spec. Your implementation plan MUST turn the spec's verification contract into a local testing plan: for each changed behavior or boundary, identify the smallest test layer that proves it, the existing coverage you inspected and will rely on, the missing proof to add, commands to run, manual verification steps, and any mock/stub setup needed for cross-repo dependencies. Do not add overlapping tests merely to be exhaustive. Add end-to-end coverage only when it proves the explicitly named integration risk that cannot be established at a lower layer; state that reason in the plan. Do NOT execute the testing plan during implementation; it runs after code review and refactoring have stabilized the code. Your implementation plan MUST also realize the spec's Observability section using this repo's local instrumentation libraries and conventions: emit the metrics/logs/traces the spec calls for, honor any cross-repo correlation fields (e.g., shared trace IDs, request IDs), and flag any observability gap you notice that the spec missed. If the spec says no new instrumentation is needed, confirm by reading the existing instrumentation you'll rely on, and surface any mismatch before implementing.

When writing-plans saves the plan and offers the execution-approach choice, pause before answering. First run Codex adversarial review against the plan:

```bash
node "$(ls -t ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | head -1)" task --wait --fresh "Review the implementation plan at <absolute-plan-path>. Design spec context: <absolute-spec-path>. Adversarially challenge the planned approach, function signatures, retry/error handling, test coverage gaps or duplication, hidden assumptions about the runtime, and any steps that conflict with the spec's contracts. Confirm that each planned test is the smallest useful proof and that each end-to-end test has a unique stated purpose. Prioritize issues expensive to fix once code is written. Return findings organized by severity (Critical/Important/Suggestion)."
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
