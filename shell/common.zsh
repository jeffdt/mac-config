# Portable shell configuration
# This file sources common configs, then machine-specific local.zsh if it exists

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="zed --wait"

SHELL_DIR="${0:a:h}"

# Completions (tp and wt register theirs, so this must run before they init)
(( $+functions[compdef] )) || { autoload -Uz compinit && compinit; }

# Dotfiles management (bare git repo pattern)
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Common configs
for f in "$SHELL_DIR"/common/*.zsh; do
  source "$f"
done

# Starship prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# tp (teleport), directory portals
if command -v tp-core >/dev/null 2>&1; then
  eval "$(tp-core --init zsh)"
fi

# wt (worktrunk), worktree manager shell integration
if command -v wt >/dev/null 2>&1; then
  eval "$(command wt config shell init zsh)"
fi

# Machine-specific config (not tracked in git). A local.zsh takes over entirely
# (it is responsible for sourcing local/); otherwise local/*.zsh load alphabetically.
if [[ -f "$SHELL_DIR/local.zsh" ]]; then
  source "$SHELL_DIR/local.zsh"
else
  for f in "$SHELL_DIR"/local/*.zsh(N); do
    source "$f"
  done
fi
