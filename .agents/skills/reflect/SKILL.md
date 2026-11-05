---
name: reflect
version: 2.0.0
description: "This skill should be used when the user explicitly asks for it (phrases like \"/reflect\", \"reflect on this session\", \"update AGENTS.md from what we learned\", \"what should the docs have said\") or when a workflow step explicitly calls for it, such as an implementation session reaching the mark-ready point of its PR. Generic session wind-down language (\"wrap up\", \"summarize what we did\") is NOT sufficient to trigger it on its own. Reviews the current conversation for papercuts a future session would hit again, traces each one to the doc that misled the session or the doc that should have prevented it, and proposes conservative diffs for the user to approve before any file is touched."
---

# Reflect

Look back at this conversation for friction that better docs would have prevented, and propose fixing it at its source. This is not a session summary and not a code review. It is narrowly about whether a doc a future session will read said something wrong, or failed to say something it should have.

**Default outcome is nothing.** Most sessions produce no finding worth documenting. Saying "nothing worth documenting" in one line is a successful run.

Runs entirely on the conversation already in context. Do not dispatch a subagent for this: a freshly spawned agent has none of this session's history, which is the only input this skill has.

## Step 1: Identify repos and projects actually worked in

Scan the conversation for repos with real activity: file edits/writes, commands executed, or non-trivial multi-step exploration (an `Explore`/`Agent` dispatch, several rounds of `Grep`/`find`). A repo that was only glanced at (one `Read` for passing context, a single reference) does not count.

For each repo found, locate its root (nearest directory with its own `AGENTS.md`, `CLAUDE.md`, or `.git`). If a repo's `CLAUDE.md` is just an `@AGENTS.md` include (the pattern across `app`, `k-repo`, `fender`, `infrastructure-deployment`, and likely others), the target file is `AGENTS.md`, never `CLAUDE.md`. `~/.agents` counts like any other repo if it was worked in.

Also note whether the session ran under a project directory (`~/p/<project>` or `~/Klaviyo/projects/<project>`), or was seeded by a prompt that came from one (a session prompt citing a spec under `<project>/specs/`). That project's docs (`CLAUDE.md`, `project-map.md`, `map/*`, `roadmap.md`) are in scope for Step 4.

If nothing rises to "worked in," say so and stop.

## Step 2: Detect candidate papercuts

Look for these signals:

- **User corrections** revealing a stable fact ("no, that lives in X", "the Makefile already handles that"). The strongest signal.
- **Wrong actions that had to be undone**: a file created then deleted, a change reverted, a step done by hand that a script or `make` target already does (e.g. symlinking `.env` into a worktree when `make` already links it).
- **Trial-and-error command failures** where the fix was a fixed convention (a required flag, a specific target or script instead of the obvious command), not a typo or environment fluke.
- **Repeated exploration** to locate something that turned out to have one well-known answer.
- **Acting on doc content that turned out wrong**: a path, command, or claim read from any doc (project map, README, AGENTS.md, a spec) that did not match reality.

## Step 3: Filter hard

Keep a candidate only if all of these hold:

1. **Durable**: a *different* future session doing *different* work here would hit it too.
2. **Costly**: it wasted real effort (a wrong action, a revert, a user correction, several failed attempts), not just one extra search.
3. **Non-obvious**: the wrong move looked reasonable. "The Makefile links `.env` into worktrees, don't symlink it by hand" passes. "Function X lives in file Y" fails; a search finds it.
4. **Not already covered**: re-read the current target docs from disk (not from earlier context, which may be stale) and discard anything they already say correctly.

If nothing survives, say "nothing worth documenting" and stop.

## Step 4: Trace each finding to its source

For each survivor, ask: did the session act on something it read?

- **Yes, a doc said something wrong or stale** → the fix target is *that doc*, wherever it lives: `project-map.md`, `map/*`, `roadmap.md`, a repo `README.md` or `AGENTS.md`, a doc under a repo's `docs/`. Propose correcting or deleting the wrong content. Never add a new note elsewhere that contradicts it; two disagreeing docs are worse than one wrong one.
- **No, the knowledge was simply missing** → add it to the nearest doc a future session will actually load:
  - Repo-specific fact → that repo's `AGENTS.md`.
  - Cross-repo or project-wide fact → the project's `CLAUDE.md`.
  - Setup or tooling fact a human also needs (dev setup, `make` targets) → the repo `README.md`, only if it already covers that topic; otherwise `AGENTS.md`.
- **Global tool-caused**: a globally defined skill, MCP server, or plugin steered the session wrong in a way that would recur in any repo → no doc edit. Name the likely culprit for the closing callout. Do not edit it as part of this flow.

Rules for specific doc types:

- **Project maps** (`project-map.md`, `map/*`) follow the rules in `/project:map`: high bar for inclusion, no broken links, its fixed format. Propose the smallest fix that keeps those rules. If an area map is broadly stale, recommend re-running `/project:map <area>` instead of rewriting it here.
- **Specs, plans, prompts, and other records of finished or in-flight work** are historical. Never edit them. If one misled the session, name it in the output and put the correct fact in a living doc instead.
- **Docs outside this session's write scope** (e.g. an implementation session finding a wrong line in the parent project's map): do not edit. Report it as a project-level gotcha in the `/handoff:debrief` Gotchas section so the orchestrating session, which owns those files, can fix it.

## Step 5: Draft and present

For each target doc:
- Show the relevant existing excerpt and the proposed change as a diff. Corrections and deletions first. Additions are one or two terse bullets matching the file's voice (clipped bullets, not prose; never an exhaustive file listing).
- One-line rationale tying the change to what actually happened in the session.
- If the right target doesn't exist (a repo with no `AGENTS.md`), say so plainly instead of creating it.

End with, when applicable:
- A short callout naming any global-tool culprits from Step 4 as candidates for a separate follow-up.
- A short list of project-level gotchas held for the debrief (out-of-scope docs).

## Step 6: Approve and apply

Ask for approval before touching any file. Changes can be approved individually or as a batch; the user's call. A "no" leaves that doc untouched. Apply approved diffs with `Edit`.

## What this skill is not

- Not the personal memory system (`~/.claude/projects/.../memory`). That covers how Claude collaborates with the user and is private. This skill only edits docs any agent working in the repo or project would read.
- Not a mechanism for editing skills, MCP servers, or plugins (see Step 4).
- Not a session summary or decision log.
