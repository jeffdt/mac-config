# GENERAL
alias act="source ./.venv/bin/activate"
alias dact="deactivate"
alias la='ls -a'
alias src="source ~/.zshrc"

# BREW
alias brewup="brew update && brew upgrade"

# SUBLIME
export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
alias edit="subl"

# GIT
alias ga="git add -p"
alias gr="git reset && git status"
alias gb="git checkout -b"
alias gc="git commit -m "
alias gd="git diff"
alias gdc="git diff --cached"
alias gm="git checkout master"
alias gp="git push"
alias gx="git reset --hard && git status"
alias gs="git status"
alias gu="git pull"
alias gpb="git symbolic-ref --short HEAD"
alias gpbc="git symbolic-ref --short HEAD | pbcopy"
alias gmu='git checkout $(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@") && git pull'
alias rml="rm .git/index.lock"
