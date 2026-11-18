# Shell config

Personal zsh configuration with a portable tier and a machine-specific tier.

- `common.zsh` is the entry point, sourced from `~/.zshrc`. It and `common/` are portable and tracked.
- `local/` holds machine-specific files (work aliases, credentials, tool setup). It is gitignored and never backed up.

`~/.zshrc` itself is untracked and should contain only `source ~/shell/common.zsh`.

**IMPORTANT: This is NOT a normal git repo.** Dotfiles are managed with a bare repo at `~/.dotfiles/`. The `config` alias replaces `git` for all operations:

```
config status          # not: git status
config add <file>      # not: git add <file>
config commit -m "..." # not: git commit -m "..."
config push            # not: git push
```

Bare `git` in this directory fails with "not a git repository". The work tree root is `$HOME`, so run `config add` from `~` or use paths like `shell/common/functions.zsh`.

## Load order

`common.zsh` runs in this order:

1. `compinit`, skipped if completions are already initialized. Tools that register completions (`tp`, `wt`) must come after it.
2. Everything in `common/*.zsh`, alphabetically.
3. Tool inits that need to run late: `starship`, `tp-core`, `wt`.
4. Machine-specific config. If `~/shell/local.zsh` exists it is sourced and is then responsible for loading `local/`. If not, `local/*.zsh` are sourced alphabetically.

Files in a directory load alphabetically, so a file that depends on another must sort after it (a numeric prefix like `10-envvars.zsh` works). Local files load last and can override anything in `common/`.

## Conventions

- `common/` must work on any machine. Guard every optional tool with `command -v`, so a missing tool is skipped, not an error.
- Anything specific to one job or machine goes in `local/`.
- `local/envvars.zsh`, if present, holds real tokens. Never read, display, or commit it.
- Use zsh syntax (`${0:a:h}` for the script dir, `[[ ]]` tests).
- Do not add per-file inventories to this doc. List the directories to see what exists.
