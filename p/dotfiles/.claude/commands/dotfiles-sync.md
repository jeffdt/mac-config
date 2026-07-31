---
description: Two-way sync the mac-config dotfiles repo (pull, resolve conflicts, commit, push)
---

Sync the dotfiles repo using the `config` git alias (a bare repo whose work-tree is `$HOME`). See `~/.dotfiles/AGENTS.md` for the full safety rules and branch model this procedure assumes.

Steps:

1. `config -C "$HOME" fetch origin main --verbose` to see if there are new upstream commits.
2. Ensure the `abshome` clean filter is registered locally (self-healing — cheap to run every
   time, only sets it if missing):
   ```
   config -C "$HOME" config --get filter.abshome.clean >/dev/null || \
     config -C "$HOME" config filter.abshome.clean '$HOME/.local/bin/dotfiles-normalize-home-paths'
   ```
   This filter neutralizes a known-benign drift: reinstalling the tmux-assistant-resurrect
   tmux plugin rewrites the `command` hooks in `.claude/settings.json` /
   `.pi/agent/settings.json` to a hardcoded absolute path. `.gitattributes` scopes the filter
   to just those two files, so `git status`/`diff`/`add` treat that specific drift as
   equivalent to the tracked `$HOME`-relative form and it never needs manual handling or
   shows up as noise.
3. `config -C "$HOME" status` to see local tracked changes. Only look at tracked files
   (`git diff --name-only HEAD`) — `git status -uall` will surface unrelated `$HOME` clutter
   (e.g. `.Trash`, app support files) since the work-tree is the whole home directory. Never
   run `git add -A` or `git add .`; only stage specific known dotfiles by name. If
   `.claude/settings.json` or `.pi/agent/settings.json` show as modified for no reason other
   than the tmux-assistant-resurrect path rewrite (step 2's filter should normally prevent
   this, but the index can have a stale cached stat right after the drift happens), run
   `config -C "$HOME" add <path>` on just that file — since the filtered content already
   matches HEAD this stages no actual change, it just refreshes the cached stat so status
   stops flagging it.
4. If there are local uncommitted changes to a file that upstream also touched, stash just
   that pathspec (`config -C "$HOME" stash push -u -m "<msg>" -- <path>`) before pulling, so
   the pull isn't blocked.
5. `config -C "$HOME" pull --ff-only origin main`. If it fails because an untracked file
   would be overwritten, back the local file up (copy it aside, don't delete) before retrying
   — don't silently let either version win without checking the diff.
6. If a stash was created, `config -C "$HOME" stash pop` and resolve any conflict markers by
   hand — read both sides, don't guess blindly. Validate any JSON file touched
   (`python3 -c "import json; json.load(open(path))"`) after editing.
7. Review the diff of every tracked file about to be committed. If anything looks like it
   weakens a security-relevant hook or permission (e.g. changes to `.claude/settings.json`
   hooks, permission allowlists) in a way that doesn't match what the user asked for, stop
   and flag it before proceeding — don't commit it silently. If a hardcoded machine-specific
   absolute home path shows up (e.g. `/Users/hom/...`) in a file *not* already covered by the
   `abshome` filter (step 2), don't omit or exclude that line from the commit — rewrite the
   home-directory prefix to `~` in place and commit the corrected line along with everything
   else, then restore the original absolute path in the live working-tree file afterward so
   nothing changes functionally on this machine. If it's a recurring source of drift like the
   tmux-assistant-resurrect case, consider adding it to `.gitattributes`'s `abshome` filter
   instead of hand-fixing it every sync.
8. Stage only the specific tracked files that changed, commit with a short imperative message
   describing what changed, and push:
   ```
   config -C "$HOME" add <file1> <file2> ...
   config -C "$HOME" commit -m "<message>"
   config -C "$HOME" push
   ```
9. If `.tmux.conf` was among the files pulled in step 5 (check with
   `git diff --name-only <old-HEAD> <new-HEAD>` from step 5's output, or `config -C "$HOME"
   log --stat` if unsure), reload it for any running tmux server so the sync takes effect
   immediately, rather than leaving stale config running until the next manual reload or
   server restart:
   ```
   tmux info &>/dev/null && tmux source-file ~/.tmux.conf
   ```
   Skip silently if no tmux server is running (the `tmux info` check above handles that).
10. Report what was pulled, what was committed/pushed, whether `.tmux.conf` was reloaded, and
    flag anything left unresolved (e.g. a file backed up for manual reconciliation, a stash
    entry still present).
