# AGENTS.md

This project manages Jeff's tmux setup and related terminal workflow configuration.

It is the home for:

- tmux configuration and defaults
- status line configuration and styling
- keyboard shortcuts and keybinding experiments
- customization of panes, windows, sessions, and workflows
- notes and examples for learning tmux more deeply

When making changes here, prefer clear, practical configuration that supports day-to-day use. Keep notes useful for future reference, especially when documenting shortcuts, workflow patterns, or lessons learned.

Before making tmux recommendations or configuration changes, start by reading Jeff's current `~/.tmux.conf` so suggestions fit the existing setup, bindings, plugins, and style choices instead of relying on generic tmux defaults. If the task involves keybindings, prefix behavior, copy mode, pane or window navigation, or unexpected key behavior, also inspect active tmux bindings with targeted `tmux list-keys` calls for the relevant key tables. Do not rely on generic tmux defaults when Jeff's config or active tmux state could affect the answer.

Once Jeff confirms the direction for a tmux config change, make the change directly in `~/.tmux.conf` rather than only telling him what to edit. Validate or reload the config when practical, and summarize the exact change made.

When Jeff agrees to adding a tmux plugin managed by TPM, update `~/.tmux.conf`, run TPM's install script (`~/.tmux/plugins/tpm/bin/install_plugins`) when available, reload tmux, and summarize the installed plugin. If TPM is missing or the install fails, explain the blocker and ask for guidance.

When a tmux configuration session appears complete, ask whether Jeff wants to back up the change to the dotfiles bare repo. The `config` git alias is a shell alias that expands to `/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`; use it to inspect, stage, commit, and push dotfile changes such as `~/.tmux.conf`. Tested behavior: `config` is available in interactive zsh (`zsh -ic`) but is not available in non-interactive bash or non-interactive zsh (`bash -lc`, `zsh -c`, or the default bash tool shell). For automation, either run through interactive zsh or use the expanded command directly. Do not run the backup commit or push until Jeff confirms.

### Working with the dotfiles bare repo safely

The bare repo's `--work-tree` is `$HOME`, so any git command that scans the work tree (`status -u`, `stash push -u`/`-a`, `add -A`) walks the **entire home directory**, not just tracked dotfiles. Lessons from doing this the hard way:

- `status.showUntrackedFiles` is set to `no` for this repo on purpose, so plain `config status` stays quiet. Only pass `-uall` (or `status -u`) when you deliberately want to see untracked files, and expect a lot of noise (macOS `Library/` dirs will also throw `Operation not permitted` warnings).
- Never run `config stash push -u` or `config add -A` unscoped — both crawl all of `$HOME` looking for untracked files, which is slow (can hang for minutes on `Library/`) and risks sweeping up unrelated untracked content (e.g. a stray `node_modules/` or `package-lock.json` sitting in a project dir) into a commit. Always scope with explicit `--` paths, e.g. `config stash push -m "..." -- ~/.agents/scripts/mux ...` or `config add -u ~/.agents` (the `-u` here only re-stages already-tracked files under that path, it does not scan for new ones).
- Before assuming local dotfiles are in sync with remote, `config fetch origin` first and compare with `config status -sb` — `git status` alone can report "up to date" when it's actually just stale against a remote that has moved (i.e. it was never fetched).
- If local uncommitted changes and incoming remote commits touch different files, a scoped stash + `merge --ff-only` + stash pop is a clean, conflict-free way to reconcile without touching unrelated content.
