# FZF setup
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# Custom keybindings (commented out - uncomment to customize)
# bindkey -r '^T'
# bindkey '^[f' fzf-file-widget

# bindkey -r '^R'
# bindkey '^[r' fzf-history-widget
