---
name: trunk-merge-queue
description: Use when adding a PR to the merge queue, removing one from it, or checking where a PR sits in it, in a repo that uses Trunk Merge Queue (k-repo). Triggers include "add to the merge queue", "queue this PR", "enqueue", "merge this PR", "ship it", "take it out of the queue", "cancel the merge", "is my PR merged yet", "merge queue status", or "trunk merge". Use the `trunk` CLI. Do not use `gh pr merge`, the GitHub merge button, or the browser extension.
---

# Trunk Merge Queue

k-repo merges through Trunk Merge Queue, so `gh pr merge` is the wrong tool there. Use the `trunk` CLI, installed at `/opt/homebrew/bin/trunk` and already logged in.

Run every command from inside a k-repo checkout. Any worktree works (`~/r/k-repo` or `~/r/k-repo.<branch>`), because the CLI reads `.trunk/trunk.yaml` to find the repo. Always pass `--no-progress` so the output stays readable.

## Commands

| Goal | Command |
|------|---------|
| Add a PR to the queue | `trunk merge <pr> --no-progress` |
| Check one PR | `trunk merge status <pr> --no-progress` |
| Show the whole queue | `trunk merge status --no-progress` |
| Remove a PR from the queue | `trunk merge cancel <pr> --no-progress` |

`<pr>` is the PR number (`1234` or `#1234`). To find the number for the current branch, run `gh pr view --json number -q .number`.

## Rules

- Queue a PR only when the user asks for that specific PR. Queueing starts a merge to `main`, which is hard to undo.
- Do not pass `-p/--priority` unless the user asks for it. `-p 0` interrupts PRs that are already testing.
- `pause` and `resume` stop or restart the queue for everyone (admin only). Never run them.
- To change a PR that is already in the queue, cancel it first, then queue it again after pushing.

## Reading status

The states are `Not Ready` (required checks or approvals missing), `Pending`, `Testing`, `Merged`, `Failed`, and `Cancelled`. If a PR shows `Failed`, run `trunk merge status <pr> --no-progress` to see its history, then look at the CI failure (see the `buildkite-mcp` skill).

If a command fails with `User not logged in`, ask the user to run `! trunk login`. Do not try to log in yourself.
