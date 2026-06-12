# Portable shell configuration
# This file sources common configs, then machine-specific local.zsh if it exists

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="subl --wait"

SHELL_DIR="${0:a:h}"

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
if command -v warp-core >/dev/null 2>&1; then
  eval "$(warp-core --init zsh)"
fi

# Machine-specific config (not tracked in git)
[[ -f "$SHELL_DIR/local.zsh" ]] && source "$SHELL_DIR/local.zsh"
