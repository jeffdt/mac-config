# Claude Code aliases
alias c='claude'
alias c1='claude -p --model haiku  --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent --'  # fastest
alias c2='claude -p --model sonnet --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent --'  # balanced
alias c3='claude -p --model opus   --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent --'  # most capable

alias cdc='cd ~/.claude'
alias cds='cd ~/shell'
alias cdcc='cd ~/.claude && claude'
alias cdsc='cd ~/shell && claude'

# macOS: add a blank spacer tile to the Dock
alias spacer-large="defaults write com.apple.dock persistent-apps -array-add '{\"tile-type\"=\"spacer-tile\";}' && killall Dock"
alias spacer-small="defaults write com.apple.dock persistent-apps -array-add '{\"tile-type\"=\"small-spacer-tile\";}' && killall Dock"

# Headless edit ~/.claude from anywhere (subshell preserves cwd)
cdch() { (cd ~/.claude && claude -p --model opus --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent -- "$@") }
