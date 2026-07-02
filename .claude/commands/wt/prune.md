---
description: Clean up stale worktrees across repos
allowed-tools: Bash(wt *), Bash(git *), Bash(gh pr view*), Bash(mkdir *), Bash(date *), AskUserQuestion
---

## Pre-computed Context

- Current directory: !`pwd`
- Is git repo: !`git rev-parse --is-inside-work-tree 2>/dev/null && echo "yes" || echo "no"`
- Repo toplevel (if in repo): !`git rev-parse --show-toplevel 2>/dev/null || echo ""`

## Configuration

Repos to process when running in multi-repo mode:
- `~/r/app`
- `~/r/k-repo`
- `~/r/fender`
- `~/r/infrastructure-deployment`

Audit log: `~/.local/share/wt-prune/history.log`

## Scope Detection

Determine which repos to process based on the current working directory:

- If the current directory is `~/r` exactly: process all four configured repos above
- If the current directory is inside a git repo (pre-computed "Is git repo" is "yes"): process only that repo, even if it's not one of the four configured repos
- Otherwise (not in a git repo and not `~/r`): tell the user to run from a repo or from `~/r`

## Phase 1: Merged Worktrees (automatic)

GitHub is the source of truth for "merged", not the local `main_state`. The local default branch (`master`/`main`) drifts behind `origin` whenever a repo is ignored for a while, so `main_state` will report merged branches as `ahead`/`diverged`/`would_conflict` instead of `integrated`. Phase 1 therefore reaps on EITHER signal: local `main_state == "integrated"` OR a GitHub PR whose state is `MERGED`.

For each repo in scope:

1. Run `wt list --format json -C <repo_path>` and parse the JSON output. Derive the GitHub org/repo slug from `git -C <repo_path> remote get-url origin` (strip the `git@github.com:` / `https://github.com/` prefix and `.git` suffix).
2. For each entry where `is_main` is `false`, classify it as merged if EITHER:
   - **(a)** `main_state` is `"integrated"`, OR
   - **(b)** its GitHub PR is merged: `gh pr view <branch> --repo <org/repo> --json state 2>/dev/null` returns `state == "MERGED"`. (For detached-HEAD entries with a null branch, skip the PR check; they only qualify via path (a) which they can't meet, so they fall through to Phase 2.)
3. **Skip any entry whose worktree path basename ends with `.pr-review`** (the legacy unnumbered slot). Per-PR slots matching `*.pr-review-<digits>` are NOT skipped: once their PR is merged they should auto-reap like any other integrated worktree.
4. These are confirmed merged; remove them without asking. Use `-D` so the branch is deleted even when the stale local main still considers it unmerged:
   ```
   wt remove -f -D -y -C <repo_path> <branch_name>
   ```
5. Log each removal to the audit log (note which signal triggered it):
   ```
   echo "<ISO timestamp> MANUAL <repo_name> <branch> removed (merged: <integrated|PR #N>)" >> ~/.local/share/wt-prune/history.log
   ```

Report what was removed per repo before moving to Phase 2.

## Phase 2: Stale Unmerged Worktrees (interactive)

For each repo in scope:

1. From the same JSON output, identify entries where:
   - `main_state` is NOT `"integrated"` and NOT `"is_main"`
   - `is_main` is `false`
   - The entry was NOT already removed in Phase 1 (i.e. its PR is not `MERGED`). These will be the CLOSED, no-PR, or genuinely-unmerged worktrees.
   - The commit timestamp is older than 7 days (compare `commit.timestamp` against current epoch minus 604800)
2. **Skip any entry whose worktree path basename ends with `.pr-review`** (the legacy unnumbered slot, which intentionally holds old branches between reviews). Per-PR slots matching `*.pr-review-<digits>` are NOT skipped: stale ones surface in the interactive prompt like any other unmerged worktree.
3. For each stale unmerged worktree, present:
   - Branch name
   - Age (calculated from `commit.timestamp`)
   - Working tree state (dirty/clean from `working_tree` fields)
   - Whether a GitHub PR exists: `gh pr view <branch> --repo <org/repo> --json state,url 2>/dev/null`
4. Ask the user: "Remove this worktree? The branch has unmerged commits and will be deleted. [y/N]"
5. If confirmed, run: `wt remove -f -D -y -C <repo_path> <branch_name>`
6. Log: `echo "<ISO timestamp> MANUAL <repo_name> <branch> removed (unmerged, user confirmed)" >> ~/.local/share/wt-prune/history.log`

Worktrees younger than 7 days are skipped silently.

## Phase 3: Summary

After both phases, print a summary table:

```
Worktree Prune Summary
======================
app:                       2 merged removed, 0 unmerged removed, 1 skipped (active)
k-repo:                    3 merged removed, 1 unmerged removed, 2 skipped (active)
fender:                    0 merged removed, 0 unmerged removed, 0 skipped
infrastructure-deployment: 1 merged removed, 0 unmerged removed, 0 skipped
```

## Notes

- Always ensure `~/.local/share/wt-prune/` exists before writing: `mkdir -p ~/.local/share/wt-prune`
- The `gh pr view` check requires knowing the GitHub org/repo. Derive it from `git remote get-url origin` for each repo. Both phases use this; fetch each worktree's PR state once in Phase 1 and reuse it in Phase 2 rather than calling `gh` twice per branch.
- Detached HEAD worktrees (branch is null in JSON) should be included in Phase 2 as stale candidates. Use the worktree path for removal instead of branch name.
