# Claude Code aliases
alias c='claude'
alias c1='claude -p --model haiku  --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent --'  # fastest
alias c2='claude -p --model sonnet --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent --'  # balanced
alias c3='claude -p --model opus   --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent --'  # most capable

alias cdc='cd ~/.claude'
alias cds='cd ~/shell'
alias cdcc='cd ~/.claude && claude'
alias cdsc='cd ~/shell && claude'

# Headless edit ~/.claude from anywhere (subshell preserves cwd)
cdch() { (cd ~/.claude && claude -p --model opus --allowedTools Edit,Write,Read,Glob,Grep,Skill,Agent -- "$@") }
