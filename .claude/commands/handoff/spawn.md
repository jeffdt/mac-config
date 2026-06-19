---
description: Spawn a new tab/window + Claude Code session, seeded with a context-derived prompt
allowed-tools: Bash, Write, Read, Skill
argument-hint: [hint]
---

Spawn a new tab/window in the calling session's workspace (tmux or cmux), launch Claude Code in it, and feed it a starter prompt derived from `$ARGUMENTS` and the current conversation.

**Hint**: $ARGUMENTS

## Pre-computed context

- Invoking session's repo: !`git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"`
- Current branch: !`git branch --show-current 2>/dev/null || echo "not a git repo"`
- Multiplexer: !`if [[ -n "${TMUX:-}" ]]; then echo "tmux (session $(tmux display-message -p '#S' 2>/dev/null))"; elif [[ -n "${CMUX_WORKSPACE_ID:-}" ]]; then echo "cmux (workspace ${CMUX_WORKSPACE_ID})"; else echo "none"; fi`

## How to interpret the hint

The hint takes one of three shapes. Decide which before drafting the prompt:

1. **Self-contained instruction** — the hint is already a complete starter prompt. Examples: a slash command invocation (`/pr:review https://github.com/org/repo/pull/123`), a URL to act on, a discrete unambiguous task. Pass it through as the prompt body. Do NOT pad with conversation distillation; the hint is the prompt.
2. **Focusing nudge** — the hint names a target area, repo, or angle but isn't a full instruction. Example: "fender CSRF token handling". Distill from the current conversation using the hint as a focus, the same way `/handoff:dispatch` does.
3. **Empty** — no hint provided. Distill the prompt from the conversation as a whole, in the spirit of `/handoff:dispatch`. If the conversation has no clear handoff-worthy thread, ask the user what they want spawned rather than guessing.

When in doubt between (1) and (2): if the hint by itself would make sense as the entire opening message of a fresh Claude session, treat it as (1).

## Decide the spawn plan

Before spawning, decide:

- **Target repo / cwd** — the directory the spawned tab should `cd` into before launching Claude.

  Default to the most-specific work area inside the invoking session's repo, not the repo root. Use the same granularity rule as planning: service level for monorepos (e.g. `~/r/k-repo/python/klaviyo/executive_business_report/insights_service`), component/feature area for component-style repos (e.g. `~/r/fender/src/components/foo`), repo root when the work is broad or unfocused.

  Sources for inferring the work area: file paths mentioned in the hint, files Claude has read or edited recently in this conversation, the deepest common ancestor of those paths capped at the service/component level. If the hint redirects to another repo ("spawn in fender for..."), apply the same granularity logic in that repo.

  **Why this matters:** Claude loads `CLAUDE.md` and path-scoped skills at init, walking up from cwd. Init-time context survives compaction; runtime discovery does not. A service-level cwd loads service + ancestor `CLAUDE.md` files automatically; the repo root misses all of them.
- **Bash command for the tab** — the shell incantation that runs in the new tab. Default: `cd "$repo" && claude < "$prompt_path"`. If the use case needs more (e.g. a worktree, env setup), compose the bash inline. The command is intentionally not scripted — be explicit about what runs.
- **Tab title** — short label passed as `--title` to `mux spawn`. The goal is for the user to glance at the tab strip and know *which subject* each tab is about, not just which command is running. Kebab-case, no spaces, terminal-friendly.

  If the hint already names the subject (e.g. "fender CSRF token handling"), derive directly: `fender-csrf`.

  If the hint is an opaque reference the orchestrator hasn't actually looked at yet — a bare PR URL, ticket ID, Sentry issue, etc. — do a small lookup first to get a topical keyword before naming the tab. One `gh pr view N --json title` (or equivalent) per spawn is cheap and turns `pr-review-12345` into `review-cache-ttl-12345` — much easier to scan in the tab strip when several tabs are open. Do this triage during spawn-plan preparation, before showing the user the plan.

  Avoid title patterns that only encode the command and ID (`pr-review-12345`, `walkthrough-k-repo-29508`) when N>1 spawns are happening — they're indistinguishable in the tab strip.
- **Prompt body** — the text to write to a temp file and pipe into Claude. From step above.

## Confirm before spawning

Show the user the plan before executing:

```
Spawn plan:
  repo:    <path>
  title:   <tab-label>
  prompt:  <first ~10 lines or summary>
  command: cd <repo> && <launch>
```

Wait for user approval. They may adjust any field. If they're spawning multiple at once (batch fan-out), they may approve the whole batch with one "yes."

## Execute

**REQUIRED:** Use `mux spawn` (the allowlist-friendly multiplexer wrapper at `~/.claude/scripts/mux`) for the actual tab spawn. It detects tmux vs cmux, owns workspace/session resolution, the new-window/new-surface specifics, and the optional focus behavior.

If `mux` is not available (`mux status` fails) or you are not inside tmux or cmux, STOP and ask the user how to proceed. Do not silently fall back to clipboard, file, or printout schemes.

The spawn flow:

1. Write the prompt to a temp file: `prompt_path=$(mktemp -t spawn-prompt.XXXXXX.md)` and write the body there.
2. Compose the bash command. It MUST start with `cd "$repo"` — new shells do NOT reliably inherit the parent shell's cwd, and without an explicit `cd`, Claude may launch outside the project and miss its CLAUDE.md.
3. Spawn the tab:

   ```bash
   mux spawn --workspace caller --cmd "$cmd" --title "$tab_title"
   ```

   - `--workspace caller` is still the right choice: by the time the spawn fires the user may have moved focus, and `caller` keeps the new tab next to the orchestrator. See the cmux/tmux skills for the targeting breakdown.
   - Focus is per-backend by default: cmux foregrounds the new tab; tmux leaves it in the background (your preference). Pass `--focus` to switch to it on tmux.
   - `mux spawn` prints the new tab token (`surface:N` on cmux, `@N` on tmux) on stdout; capture it for the after-spawn summary.

## What NOT to include

- Workflow instructions in the prompt ("use this skill", "create a worktree", "start by grepping for X"). Set up context; let the new session decide how to approach the work.
- Branch / worktree management baked into the command itself. If the use case wants a worktree, the user includes that in the bash command they approve.
- Silent fallback when the multiplexer is unavailable. Pause and ask.

## After spawning

Confirm to the user what was spawned: tab title, surface ref, target workspace. If batch, give a one-line summary per spawn. The new session is now live in the other tab; control returns to the invoking session.
