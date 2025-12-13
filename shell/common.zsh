# Portable shell configuration
# This file sources common configs, then machine-specific local.zsh if it exists

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="zed --wait"

SHELL_DIR="${0:a:h}"

# Dotfiles management (bare git repo pattern)
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Common configs
source "$SHELL_DIR/common/utils.zsh"
source "$SHELL_DIR/common/git.zsh"
source "$SHELL_DIR/common/fzf.zsh"

# Starship prompt
eval "$(starship init zsh)"

# Machine-specific config (not tracked in git)
[[ -f "$SHELL_DIR/local.zsh" ]] && source "$SHELL_DIR/local.zsh"
