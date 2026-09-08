---
name: reflect
description: "This skill should be used only when the user explicitly asks for it — phrases like \"/reflect\", \"reflect on this session\", \"update AGENTS.md from what we learned\", or \"what should AGENTS.md have said\". Generic session wind-down language (\"wrap up\", \"summarize what we did\") is NOT sufficient to trigger it on its own. Reviews the current conversation for dead ends, backtracking, or corrections caused by gaps in a repo's AGENTS.md, and proposes targeted diffs — one per repo actually worked in this session — for the user to approve before any file is touched."
---

> Generated from ~/.agents/skills/reflect/SKILL.md. Do not edit this copy directly.
> Edit the source under ~/.agents, then run agents-publish.

# Reflect

Look back at this conversation for friction that a better `AGENTS.md` would have prevented, and propose fixing it. This is not a session summary and not a code review — it's narrowly about whether any repo's `AGENTS.md` should have said something it didn't.

Runs entirely on the conversation already in context. Do not dispatch a subagent for this — a freshly spawned agent has none of this session's history, which is the only input this skill has.

## Step 1: Identify repos actually worked in

Scan the conversation for repos with real activity: file edits/writes, commands executed, or non-trivial multi-step exploration (an `Explore`/`Agent` dispatch, several rounds of `Grep`/`find`). A repo that was only glanced at — one `Read` for passing context, a single reference — does not count.

For each repo found, locate its root (nearest directory with its own `AGENTS.md`, `CLAUDE.md`, or `.git` above it) and its `AGENTS.md`. If a repo's `CLAUDE.md` is just an `@AGENTS.md` include (check its contents — this is the pattern used across `app`, `k-repo`, `fender`, `infrastructure-deployment`, and likely others), the target file is `AGENTS.md`, never `CLAUDE.md`. `~/.agents` itself counts like any other repo if it was worked in.

If nothing in the session rises to "worked in," say so and stop — don't force a finding.

## Step 2: Detect candidate gaps

Look across the conversation for these signal patterns:

- **User corrections** revealing a stable codebase/repo fact ("no, that lives in X", "we always do Y here"). The strongest signal — direct evidence of a wrong assumption a doc could have prevented.
- **Repeated exploration** — multiple `Explore`/`Grep`/`find` rounds, or an `Agent` dispatch, to locate something that turned out to have one well-known answer.
- **Trial-and-error command failures** where the fix was a fixed convention (a required flag, a specific script to run instead of the obvious one) — not a one-off typo or environment fluke.
- **Clarifying questions** the assistant had to ask whose answer is a stable repo fact rather than a task-specific decision.

## Step 3: Filter for durability

Keep a candidate only if a *different* future session doing *different* work in the same repo would hit the same gap. Discard anything task-specific or one-off.

Re-read the repo's actual current `AGENTS.md` — don't rely on what's already in context from earlier in this session, since it may be stale relative to concurrent edits. Discard anything already covered there.

If nothing survives this filter for a given repo, don't propose anything for it.

## Step 4: Attribution triage

For each surviving candidate, decide where the gap actually lives:

- **Repo-specific** — the fact belongs to this codebase → carry it to Step 5.
- **Global tool-caused** — a globally-defined skill, MCP server, or plugin steered the session wrong, and the same misguidance would recur in *any* repo, not just this one → do not draft an `AGENTS.md` edit for it; editing this one repo's docs wouldn't fix the actual cause. Instead, name the likely culprit (skill/MCP/plugin) and hold it for the closing callout in Step 5. Do not edit that skill/MCP/plugin as part of this flow — that's a separate, deliberate action (e.g. via `skill-creator`), not a side effect of `/reflect`.

## Step 5: Draft and present

For each repo with at least one repo-specific finding:
- Show the relevant existing `AGENTS.md` excerpt and the proposed addition as a diff — one or two terse bullets, matching that file's existing voice (clipped bullets, not prose; never an exhaustive file/directory listing).
- Add a one-line rationale tying the addition to what actually happened in the session.
- If the repo has no `AGENTS.md` at all, say so plainly instead of a diff — name the repo and the gap that would have gone in it. Do not create the file.

If any findings were classified as global-tool-caused in Step 4, add one short callout at the end naming the likely culprit and suggesting it as a candidate for a separate follow-up review — not a diff, not an inline edit.

If nothing survived Step 3 or Step 4 anywhere, say so directly. Don't manufacture a suggestion to justify having run.

## Step 6: Approve and apply

Ask for approval before touching any file. Multiple repos can be approved individually or in one batch — the user's call. A "no" or "skip this one" leaves that repo's `AGENTS.md` untouched. Apply approved diffs with `Edit`.

## What this skill is not

- Not the personal preference/feedback memory system (`~/.claude/projects/.../memory`) — that's about how Claude collaborates with the user, is private, and isn't checked into git. This skill only proposes changes to a repo's own `AGENTS.md`: codebase/project facts any agent working there would need.
- Not a mechanism for editing skills, MCP servers, or plugins — see Step 4.
- Not a general session summary — findings that aren't `AGENTS.md`-shaped (a decision log, a list of artifacts produced) don't belong here.
