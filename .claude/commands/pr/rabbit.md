---
description: Pre-push CodeRabbit gate — run the CodeRabbit CLI locally, triage findings, and fix before you push
allowed-tools: Bash(coderabbit review:*), Bash(coderabbit auth status:*), Bash(gh pr view:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git symbolic-ref:*), Bash(git add:*), Bash(git commit:*), Read, Edit, Write, Grep, Glob, AskUserQuestion
runInPlanMode: false
---

## Pre-computed Context

- Current branch: !`git branch --show-current`
- Default base: !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main`
- PR info: !`gh pr view --json number,url,title,state 2>&1 || echo "NO_PR_FOUND"`
- CodeRabbit auth: !`coderabbit auth status 2>&1 | perl -pe 's/\e\[[0-9;]*[A-Za-z]//g; s/\r//g' | grep -i 'authentication:' | head -1 || echo "AUTH_STATUS_UNKNOWN"`

## What this is

`/pr:rabbit` is a **pre-push gate**. The CodeRabbit CLI runs the same engine as the CodeRabbit GitHub bot, so the point is to catch its findings locally and fix them before you push, so the bot has less to flag. This is the shift-left complement to `/pr:feedback` (which handles bot + human comments *after* push).

Run it once. It is **not** a loop, and it is **not** part of `/pr:temper`.

## Flow

```
INIT → REVIEW → TRIAGE → PLAN → [approval gate] → FIX → DONE
```

## States

### INIT

Resolve the current branch and default base from pre-computed context. A PR need not exist yet (this is pre-push) — `NO_PR_FOUND` is fine.

Check the CodeRabbit auth line:
- If it contains **"Not logged in"**, is `AUTH_STATUS_UNKNOWN`, or is empty, STOP and tell the user:
  > CodeRabbit CLI isn't authenticated. Run `coderabbit auth login`, then re-run `/pr:rabbit`.

  Do not attempt `coderabbit auth login` yourself — it's an interactive OAuth flow.
- If it contains **"Logged in"** → go to **REVIEW**.

If the current branch equals the default base, or there are no commits/changes relative to base, there is nothing to review — say so and STOP.

### REVIEW

Run CodeRabbit once against the local branch diff vs the default base:

```bash
coderabbit review --agent --base <default-base>
```

`--agent` emits structured findings (severity, file:line, recommendation). `--type` defaults to `all` (committed + uncommitted), which matches what the bot will see on the PR. This call can take a while and may be rate-limited; that's expected — do not retry on failure.

→ Go to **TRIAGE**.

### TRIAGE

Triage inline — no subagent. Single trusted source means there's no cross-cycle bias to guard against. For each finding:
- Group by CodeRabbit's own severity.
- Recommend **fix** or **skip**, with a one-line rationale.

No manifest, no contested-tracking — those belong to `/pr:temper`'s loop, and there is no loop here.

→ Go to **PLAN**.

### PLAN

Present a numbered fix plan, one line per finding to be fixed with its concrete change. List skipped findings separately with reasons.

**⛔ MANDATORY APPROVAL GATE**

Call `AskUserQuestion` and STOP. Do not write any code until you receive a response.

```
AskUserQuestion("Here's the CodeRabbit fix plan:\n\n{numbered plan}\n\nApprove? (approve / modify / skip)")
```

Treating your own plan output as approval is not allowed. On modify, revise and ask again. On skip, go straight to **DONE** with nothing fixed.

→ After explicit approval, go to **FIX**.

### FIX

Implement the approved fixes. Then run the project's test suite (infer from the repo: `npm test`, `pytest`, `make test`, etc.) and fix any failures you introduced.

→ Go to **DONE**.

### DONE

Summarize what was fixed and what was skipped (with reasons). **Do not re-run CodeRabbit** — it's slow and rate-limited, and the GitHub bot is the backstop once you push. If the user wants another pass, they can re-invoke `/pr:rabbit`.

End with a one-line pointer that the changes are ready to push.

## Failure handling

- **Not installed / not authed:** instruct (`coderabbit auth login`) and STOP. Never half-run.
- **Non-zero exit or empty output:** report `no findings` or `unavailable — <reason>` (e.g. `auth missing`, `rate limited`, `non-zero exit: <code>`). Never crash.
- **Rate-limited:** surface the message, suggest retrying later. No auto-retry.
