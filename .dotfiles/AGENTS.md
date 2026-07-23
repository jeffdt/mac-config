# AGENTS.md

This is Jeff's bare-repo dotfiles setup for macOS (GitHub: `jeffdt/mac-config`). It tracks config files in their natural locations under `$HOME` without turning the whole home directory into a normal git working copy.

Its two jobs for a Claude session working here:

1. Keep this machine's dotfiles synced with the `mac-config` remote (pull down changes made elsewhere, push up changes made here).
2. Troubleshoot problems caused by bad syncs (blocked pulls, conflicts, stale branches, accidentally-committed clutter).

## How the bare repo works

There is no working tree at `~/.dotfiles` itself — that path *is* the git metadata (`--git-dir`). The working tree is `$HOME`. Every git command needs both pointed at the right place, which is why the `config` shell alias exists:

```
config = /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME
```

`config` is defined as an interactive-shell alias, so it's available in `zsh -ic` but **not** in non-interactive shells (`bash -lc`, `zsh -c`, or Claude Code's default Bash tool shell). For automation, either run through `zsh -ic '...'` or use the fully-expanded `git --git-dir=... --work-tree=...` form directly.

### Safety rules (read before running anything that touches `$HOME`)

`status.showUntrackedFiles` is set to `no` on purpose, so plain `config status` only shows tracked-file changes. The moment a command scans for *untracked* files, it walks the entire home directory, not just dotfiles:

- **Never** run `config add -A`, `config add .`, or `config stash push -u`/`-a` unscoped. These crawl all of `$HOME` (slow, can hang on `Library/`, throws `Operation not permitted` noise on macOS-protected dirs) and risk sweeping unrelated untracked content (stray `node_modules/`, a `package-lock.json` in some project dir) into a commit or stash.
- Always scope to explicit paths: `config add <file1> <file2>`, `config stash push -u -m "msg" -- <path>`.
- Before assuming local is in sync with remote, `config fetch origin` first, then compare with `config status -sb` — `git status` alone can say "up to date" when it just hasn't fetched.
- If local uncommitted changes and incoming remote commits touch different files, a scoped stash + `pull --ff-only` + stash pop reconciles cleanly without touching unrelated content.
- Review the diff of every file about to be committed. If a change weakens something security-relevant (`.claude/settings.json` hooks or permission allowlists, SSH/GPG config, etc.) in a way that doesn't match what Jeff asked for, stop and flag it rather than committing silently.

Full step-by-step sync procedure: `/dotfiles-sync` (`.claude/commands/dotfiles-sync.md`, tracked in this repo).

## Branch model

`main` is the only branch in active use and should be treated as canonical. There is also a `personal` branch from an earlier attempt to keep a separate profile for a personal Mac — that split didn't work out and is considered dead. If you ever find a machine still checked out on `personal`, or a stash/PR targeting it, flag it and help consolidate that machine back onto `main` rather than continuing to develop `personal` as if it were live.

## What's tracked here

The repo groups into these categories (see `README.md` for full setup-on-a-new-machine steps; treat its "Currently Tracked Files" list as stale — the tree below is closer to current reality, but when in doubt, check with `git cat-file -p main:<path>` or `config ls-tree main`):

- **Shell** — `shell/common.zsh` and `shell/common/*` (aliases, functions, fzf). `shell/local.zsh` and `shell/local/` are intentionally *not* tracked (machine-specific).
- **tmux** — `.tmux.conf` (the live config), and `p/tmux/` (a plain directory, not its own git repo, holding tmux notes/`AGENTS.md`/`CLAUDE.md` and any project-local Claude commands or skills — see its own `AGENTS.md`). Only what's explicitly tracked syncs; `p/tmux/.claude/settings.local.json` is deliberately left untracked (machine-local permissions, same convention as `~/.claude/settings.local.json`). Currently tracked: `p/tmux/AGENTS.md`, `p/tmux/CLAUDE.md`. If commands or skills get added under `p/tmux/.claude/`, `config add` them explicitly so they reach both machines.
- **Terminal / editor** — Ghostty (`Library/Application Support/com.mitchellh.ghostty/config`), Zed (`.config/zed/settings.json`).
- **Git** — `.config/git/ignore` (global gitignore).
- **Claude Code** — `.claude/` (settings, commands, agents, skills, scripts, statusline).
- **Pi agent** — `.pi/agent/` (settings, keybindings).
- **Agent sources & scripts** — `.agents/` (canonical source published via `agents-publish` into `~/.claude/*` and `~/.pi/agent/agents/generated/`), `.local/bin/` (symlinks: `mux`, `cmx`, `csa`, `agents-publish`).
- **LaunchAgents** — `Library/LaunchAgents/` (e.g. the `agents-publish` login/watch agent).

`.claude/local/`, `.claude/.gitignore`-matched paths, and anything under `shell/local*` are deliberately machine-specific and should stay untracked.

## Troubleshooting bad syncs

Common failure modes, roughly in order of how often they actually happen:

- **`pull --ff-only` refuses because a local file is untracked but would be overwritten.** Back the file up (copy aside, don't delete), retry the pull, then diff the backup against the pulled version by hand before deciding what to keep.
- **A previous session ran an unscoped `add -A`/`stash -u`** and pulled in unrelated `$HOME` clutter. Check `config status -sb` and the last commit's file list; if clutter got committed, `config reset HEAD~1 -- <clutter-path>` and re-commit cleanly (don't `reset --hard`).
- **Conflict markers after a stash pop or merge.** Resolve by reading both sides, don't guess. If the file is JSON (e.g. `.claude/settings.json`, `.pi/agent/settings.json`), validate after editing: `python3 -c "import json; json.load(open(path))"`.
- **A machine is still on the `personal` branch** and diverging further from `main`. Don't feed it — help merge whatever's genuinely machine-specific into `main` (or drop it if `main` has since replaced it) and switch the machine to `main`.
- **`.agents/` and `~/.claude/*` disagree.** `.agents/` is the canonical source; generated targets under `.claude/agents`, `.claude/skills`, `.claude/scripts`, `.claude/agent-prompts` are overwritten by `agents-publish` and shouldn't be hand-edited. If they've drifted, run `agents-publish --dry-run` to see what would change before publishing for real.
