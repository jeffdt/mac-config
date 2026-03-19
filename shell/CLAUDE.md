# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal zsh shell configuration using a two-tier architecture:

- **`common.zsh`** — Entry point. Sources all `common/` modules, initializes starship prompt, then conditionally sources `local.zsh` for machine-specific config. This file and `common/` are portable and tracked in git via a bare repo at `~/.dotfiles/`.
- **`local.zsh`** — Machine-specific entry point (work laptop). Sources all `local/` modules. **Not tracked in git.**

Dotfiles are managed with the bare git repo pattern: `config` is aliased to `git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`. Use `config` instead of `git` for dotfile operations.

## Architecture

```
common.zsh          ← entry point, sourced by ~/.zshrc
├── common/
│   ├── utils.zsh   ← general aliases (act, la, src, brewup), b64, kdo
│   ├── git.zsh     ← git aliases (ga, gs, gd, gp, gm, etc.) and functions (gcp, gpa, gpr, gpx)
│   ├── fzf.zsh     ← fzf initialization
│   ├── aliases.zsh ← Claude Code quick-question aliases (claude1/2/3), cd shortcuts
│   └── functions.zsh ← b64 helper, pbcopy wrapper with sound
local.zsh           ← machine-specific, NOT in git
├── local/
│   ├── envvars.zsh ← tokens and credentials (NEVER commit)
│   ├── klaviyo.zsh ← work aliases (cda, cdf, etc.), AWS/S2A auth, branch helper
│   ├── app.zsh     ← on-demand server management (od:request, od:list, od:release, od:connect)
│   ├── fender.zsh  ← fender dev alias
│   ├── jarvis.zsh  ← k8s pod access, 1Password secret retrieval
│   └── fnm.zsh     ← Node version manager setup
```

## Key Conventions

- **`common/`** = portable across machines; **`local/`** = machine-specific, gitignored.
- `local/envvars.zsh` contains real API tokens. Never read, display, or commit its contents.
- Functions use zsh syntax (`${0:a:h}` for script dir, `[[ ]]` tests).
- The `pbcopy` wrapper in `functions.zsh` overrides the system command to add an audio cue.
