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
alias ghm="gh pr merge --squash --delete-branch"

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

_prr_parse_url() {
    local input="$1"
    if [[ "$input" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)([/?#].*)?$ ]]; then
        echo "${match[1]} ${match[2]} ${match[3]}"
        return 0
    fi
    return 1
}

_pr_prepare_slot() {
    local caller="${funcstack[2]:-pr-launcher}"
    local input="${1:-}"

    if [[ "$input" == "-h" || "$input" == "--help" ]]; then
        cat >&2 <<EOF
Usage:
  $caller <pr-url>   Prepare review slot for a GitHub PR URL
  $caller <number>   Resolve PR number in current repo (must be inside a repo)
  $caller            Read PR URL from clipboard (pbpaste)
EOF
        return 2
    fi

    if [[ -z "$input" ]]; then
        input="$(pbpaste)"
        if [[ -z "$input" ]]; then
            echo "$caller: no URL in clipboard. Usage: $caller <pr-url> | <number>" >&2
            return 1
        fi
    fi

    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local cur_repo
        cur_repo="$(git rev-parse --show-toplevel 2>/dev/null)"
        if [[ -z "$cur_repo" ]]; then
            echo "$caller: numeric form requires cwd inside a tracked repo" >&2
            return 1
        fi
        input="$(gh pr view "$input" --json url -q .url 2>/dev/null)"
        if [[ -z "$input" ]]; then
            echo "$caller: could not resolve PR number via gh" >&2
            return 1
        fi
    fi

    local parsed
    if ! parsed="$(_prr_parse_url "$input")"; then
        echo "$caller: not a GitHub PR URL: $input" >&2
        return 1
    fi
    local org repo number
    read -r org repo number <<< "$parsed"

    local repo_path="$HOME/r/$repo"
    local slot_path="$HOME/r/$repo.pr-review"

    if [[ ! -d "$slot_path" ]]; then
        if [[ ! -d "$repo_path/.git" ]]; then
            echo "$caller: $repo_path is not a git repo; cannot create review slot" >&2
            return 1
        fi
        git -C "$repo_path" fetch origin >/dev/null || return 1
        git -C "$repo_path" worktree add --detach "$slot_path" origin/HEAD || return 1
    fi

    if ! git -C "$slot_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "$caller: $slot_path exists but is not a git worktree. Remove it and retry." >&2
        return 1
    fi

    local current_branch expected_branch
    current_branch="$(git -C "$slot_path" branch --show-current 2>/dev/null)"
    expected_branch="$(gh pr view "$number" --json headRefName -q .headRefName --repo "$org/$repo" 2>/dev/null)"

    if [[ -n "$current_branch" && "$current_branch" == "$expected_branch" ]]; then
        cd "$slot_path" || { echo "$caller: could not cd into $slot_path" >&2; return 1; }
        return 0
    fi

    cd "$slot_path" || return 1
    git reset --hard >/dev/null || return 1
    git clean -fd >/dev/null || return 1
    git fetch origin || return 1
    gh pr checkout "$number" || return 1
}

prr() { _pr_prepare_slot "$@" && exec claude "/pr:review"; }
prw() { _pr_prepare_slot "$@" && exec claude "/pr:walkthrough"; }
