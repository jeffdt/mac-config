# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal zsh shell configuration using a two-tier architecture:

- **`common.zsh`** — Entry point. Sources all `common/` modules, initializes starship prompt, then conditionally sources `local.zsh` for machine-specific config. This file and `common/` are portable and tracked in git via a bare repo at `~/.dotfiles/`.
- **`local.zsh`** — Machine-specific entry point (work laptop). Sources all `local/` modules. **Not tracked in git.**

**IMPORTANT: This is NOT a normal git repo.** Dotfiles are managed with a bare repo at `~/.dotfiles/`. The `config` alias replaces `git` for all operations:

```
config status          # not: git status
config add <file>      # not: git add <file>
config commit -m "..." # not: git commit -m "..."
config push            # not: git push
```

Running bare `git` commands in this directory will fail with "not a git repository". Always use `config`. The work tree root is `$HOME`, so file paths in `config add` are relative to `~` (run `config add` from `~`, or use paths like `shell/common/functions.zsh`).

## Architecture

```
common.zsh            ← entry point, sourced by ~/.zshrc
├── common/
│   ├── aliases.zsh   ← Claude Code quick-question aliases (claude1/2/3), cd shortcuts
│   ├── functions.zsh ← wtc (worktree create shortcut), b64 helper, pbcopy wrapper with sound
│   ├── fzf.zsh      ← fzf initialization
│   ├── git.zsh      ← git aliases (ga, gs, gd, gp, gm, etc.) and functions (gcp, gpa, gpr, gpx)
│   ├── tp.zsh       ← tp (custom portal/teleport app using warp-core): frecency-ranked directory jumping, zsh completion
│   └── utils.zsh    ← general aliases (act, la, src, brewup), b64, kdo
local.zsh             ← machine-specific, NOT in git
├── local/
│   ├── envvars.zsh   ← tokens and credentials (NEVER commit)
│   ├── klaviyo.zsh   ← work aliases (cda, cdf, etc.), AWS/S2A auth, branch helper
│   ├── fender.zsh    ← ~/r/fender: fender dev alias
│   ├── fnm.zsh      ← Node version manager setup
│   ├── jarvis.zsh   ← ~/r/k-ops-jarvis: k8s pod access, 1Password secret retrieval
│   ├── krepo.zsh    ← ~/r/k-repo: dev helpers, krepo:kill-servers (ports 8091-8100)
│   └── prod.zsh     ← prod/infra access: od:* (on-demand servers), kdp:* (KDP pod connect + debug)
```

## Key Conventions

- **`common/`** = portable across machines; **`local/`** = machine-specific, gitignored.
- `local/envvars.zsh` contains real API tokens. Never read, display, or commit its contents.
- Functions use zsh syntax (`${0:a:h}` for script dir, `[[ ]]` tests).
- The `pbcopy` wrapper in `functions.zsh` overrides the system command to add an audio cue.
