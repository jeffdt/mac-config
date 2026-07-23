---
description: Two-way sync the mac-config dotfiles repo (pull, resolve conflicts, commit, push)
---

Sync the dotfiles repo using the `config` git alias (a bare repo whose work-tree is `$HOME`). See `~/.dotfiles/AGENTS.md` for the full safety rules and branch model this procedure assumes.

Steps:

1. `config -C "$HOME" fetch origin main --verbose` to see if there are new upstream commits.
2. `config -C "$HOME" status` to see local tracked changes. Only look at tracked files
   (`git diff --name-only HEAD`) — `git status -uall` will surface unrelated `$HOME` clutter
   (e.g. `.Trash`, app support files) since the work-tree is the whole home directory. Never
   run `git add -A` or `git add .`; only stage specific known dotfiles by name.
3. If there are local uncommitted changes to a file that upstream also touched, stash just
   that pathspec (`config -C "$HOME" stash push -u -m "<msg>" -- <path>`) before pulling, so
   the pull isn't blocked.
4. `config -C "$HOME" pull --ff-only origin main`. If it fails because an untracked file
   would be overwritten, back the local file up (copy it aside, don't delete) before retrying
   — don't silently let either version win without checking the diff.
5. If a stash was created, `config -C "$HOME" stash pop` and resolve any conflict markers by
   hand — read both sides, don't guess blindly. Validate any JSON file touched
   (`python3 -c "import json; json.load(open(path))"`) after editing.
6. Review the diff of every tracked file about to be committed. If anything looks like it
   weakens a security-relevant hook or permission (e.g. changes to `.claude/settings.json`
   hooks, permission allowlists) in a way that doesn't match what the user asked for, stop
   and flag it before proceeding — don't commit it silently.
7. Stage only the specific tracked files that changed, commit with a short imperative message
   describing what changed, and push:
   ```
   config -C "$HOME" add <file1> <file2> ...
   config -C "$HOME" commit -m "<message>"
   config -C "$HOME" push
   ```
8. Report what was pulled, what was committed/pushed, and flag anything left unresolved
   (e.g. a file backed up for manual reconciliation, a stash entry still present).
