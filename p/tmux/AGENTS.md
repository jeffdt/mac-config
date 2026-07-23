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

When a tmux configuration session appears complete, ask whether Jeff wants to back up the change to the dotfiles bare repo (`~/.tmux.conf` is tracked there). Do not run the backup commit or push until Jeff confirms. For how the bare repo works, safety rules around it, and the sync procedure, see `~/.dotfiles/AGENTS.md` and its `/dotfiles-sync` command — that repo is the canonical home for this guidance, not here.
