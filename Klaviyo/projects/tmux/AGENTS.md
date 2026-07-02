# AGENTS.md

This project manages Jeff's tmux setup and related terminal workflow configuration.

It is the home for:

- tmux configuration and defaults
- status line configuration and styling
- keyboard shortcuts and keybinding experiments
- customization of panes, windows, sessions, and workflows
- notes and examples for learning tmux more deeply

When making changes here, prefer clear, practical configuration that supports day-to-day use. Keep notes useful for future reference, especially when documenting shortcuts, workflow patterns, or lessons learned.

Before making tmux recommendations, heavily ground the advice in Jeff's current `~/.tmux.conf`. Check the active config first so suggestions fit the existing setup, bindings, plugins, and style choices instead of relying on generic tmux defaults.

Once Jeff confirms the direction for a tmux config change, make the change directly in `~/.tmux.conf` rather than only telling him what to edit. Validate or reload the config when practical, and summarize the exact change made.

When Jeff agrees to adding a tmux plugin managed by TPM, update `~/.tmux.conf`, run TPM's install script (`~/.tmux/plugins/tpm/bin/install_plugins`) when available, reload tmux, and summarize the installed plugin. If TPM is missing or the install fails, explain the blocker and ask for guidance.

When a tmux configuration session appears complete, ask whether Jeff wants to back up the change to the dotfiles bare repo. The `config` git alias is a shell alias that expands to `/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`; use it to inspect, stage, commit, and push dotfile changes such as `~/.tmux.conf`. Tested behavior: `config` is available in interactive zsh (`zsh -ic`) but is not available in non-interactive bash or non-interactive zsh (`bash -lc`, `zsh -c`, or the default bash tool shell). For automation, either run through interactive zsh or use the expanded command directly. Do not run the backup commit or push until Jeff confirms.
