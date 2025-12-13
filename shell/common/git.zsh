# Git aliases
alias ga="git add -p"
alias gr="git reset && git status"
alias gb="git checkout -b"
alias gc="git commit -m "
alias gd="git diff"
alias gdc="git diff --cached"
alias gm='git checkout $(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@")'
alias gp="git push"
alias gx="git reset --hard && git status"
alias gs="git status"
alias gu="git pull"
alias gpb="git symbolic-ref --short HEAD"
alias gpbc="git symbolic-ref --short HEAD | pbcopy"
alias gmu='git checkout $(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@") && git pull'
alias rml="rm .git/index.lock"

# Git functions
function gcp() {
    git commit -m "$1" && gp
}

function gpa() {
    git add '*'"$1"'*'
    git status
}

function gpr() {
    git reset '*'"$1"'*'
    git status
}

function gpx() {
    git checkout '*'"$1"'*'
    git status
}
