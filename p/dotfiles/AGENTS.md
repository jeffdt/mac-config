# AGENTS.md

This directory is the Claude Code project root for Jeff's dotfiles workflow: syncing his `mac-config` bare repo (tracked at `~/.dotfiles`, working tree `$HOME`). Subdirectories here (e.g. `tmux/`) hold notes/AGENTS.md/CLAUDE.md for specific config areas that are also synced through the same bare repo; they inherit this file and the `/dotfiles-sync` command automatically since Claude Code cascades both `CLAUDE.md`/`AGENTS.md` and `.claude/commands/` up the directory tree.

For how the bare repo actually works (the `config` git alias, safety rules around `$HOME` being the work-tree, the branch model, and troubleshooting bad syncs), see `~/.dotfiles/AGENTS.md` — that file is the canonical reference for the bare-repo mechanics, not this one.

When Jeff asks to sync dotfiles from anywhere under this directory (including subdirectories like `tmux/`), run the `/dotfiles-sync` command (`.claude/commands/dotfiles-sync.md`, tracked in this repo at `p/dotfiles/.claude/commands/dotfiles-sync.md`).
