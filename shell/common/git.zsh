# Git aliases
alias ga="git add -p"
alias gr="git reset && git status"
alias gb="git checkout -b"
alias gd="git diff"
alias gdc="git diff --cached"
alias gm='git checkout $(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@")'
alias gx="git reset --hard && git status"
alias gs="git status"
alias gu="git pull"
alias gpb="git symbolic-ref --short HEAD"
alias gpbc="git symbolic-ref --short HEAD | pbcopy"
alias gmu='git checkout $(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@") && git pull'
alias rml="rm .git/index.lock"
alias ghm="gh pr merge --squash --delete-branch"

# Git functions
gc() {
    git commit -m "$*"
}

gp() {
    git push "$@"
}

function gcp() {
    git commit -m "$*" && gp
}

function gpa() {
    git add -- "*$1*"
    git status
}

function gpr() {
    git reset -- "*$1*"
    git status
}

function gpx() {
    git checkout -- "*$1*"
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

# Locate the canonical local clone for a repo by name. Searches the
# colon-separated list in $PR_REPO_BASE_DIRS in order; first match wins.
# If $PR_REPO_BASE_DIRS is unset, falls back to $HOME/Klaviyo/Repos so the
# common case works out of the box for Klaviyo engineers.
_pr_locate_repo() {
    local name="$1"
    local -a bases=(${(s/:/)PR_REPO_BASE_DIRS:-$HOME/Klaviyo/Repos})
    local base
    for base in "${bases[@]}"; do
        if [[ -d "$base/$name/.git" ]]; then
            echo "$base/$name"
            return 0
        fi
    done
    return 1
}

# Shared error message when _pr_locate_repo fails. Pass the caller name and
# repo name; prints to stderr.
_pr_locate_repo_error() {
    local caller="$1" repo="$2"
    local search_list="${PR_REPO_BASE_DIRS:-$HOME/Klaviyo/Repos}"
    echo "$caller: could not find local clone of '$repo' in: ${search_list//:/, }" >&2
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

    local repo_path
    if ! repo_path="$(_pr_locate_repo "$repo")"; then
        _pr_locate_repo_error "$caller" "$repo"
        return 1
    fi
    # Slots are keyed on PR number so multiple reviews on the same repo can
    # run in parallel. Re-running on the same PR reuses its existing slot.
    local slot_path="${repo_path}.pr-review-${number}"

    if [[ ! -d "$slot_path" ]]; then
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

prr() { _pr_prepare_slot "$@" && exec pi "/pr:review"; }
prw() { _pr_prepare_slot "$@" && exec pi "/pr:walkthrough"; }

# Open a fresh pi session on a PR with a user-typed opening instruction
# (the "Discuss…" mode from the Tentacle dropdown). Uses the feedback-style
# slot prep so discuss-mode on your own open PR reuses your existing
# feature worktree rather than failing to check the branch out twice; for
# others' PRs it falls back to a per-PR review slot.
prd() {
    local url="$1" prompt="$2"
    if [[ -z "$url" || -z "$prompt" ]]; then
        echo "prd: usage: prd <pr-url> <prompt>" >&2
        return 1
    fi
    _pr_feedback_prepare "$url" && exec pi "$prompt"
}

# Unlike prr/prw, /pr:feedback is usually run against your OWN open PR, so the
# branch is already checked out in your feature worktree. Using a fresh review
# slot would fail with "already checked out in another worktree".
# Strategy: resolve the PR's headRefName, find a worktree that already has it
# checked out, cd there. If none, fall back to a per-PR review slot (covers
# the rare case of running /pr:feedback on someone else's PR).
_pr_feedback_prepare() {
    local caller="${funcstack[2]:-prf}"
    local input="${1:-}"

    if [[ "$input" == "-h" || "$input" == "--help" ]]; then
        cat >&2 <<EOF
Usage:
  $caller <pr-url>   cd to the existing worktree for the PR's branch
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

    local repo_path
    if ! repo_path="$(_pr_locate_repo "$repo")"; then
        _pr_locate_repo_error "$caller" "$repo"
        return 1
    fi

    local branch
    branch="$(gh pr view "$number" --json headRefName -q .headRefName --repo "$org/$repo" 2>/dev/null)"
    if [[ -z "$branch" ]]; then
        echo "$caller: could not resolve branch name for PR #$number" >&2
        return 1
    fi

    local existing
    existing="$(git -C "$repo_path" worktree list --porcelain \
        | awk -v target="refs/heads/$branch" '
            /^worktree / { path = substr($0, 10) }
            /^branch /   { if ($2 == target) { print path; exit } }
        ')"

    if [[ -n "$existing" && -d "$existing" ]]; then
        cd "$existing" || { echo "$caller: could not cd into $existing" >&2; return 1; }
        git fetch origin "$branch" >/dev/null 2>&1
        return 0
    fi

    echo "$caller: no local worktree for '$branch'; falling back to per-PR review slot" >&2
    _pr_prepare_slot "$1"
}

prf() { _pr_feedback_prepare "$@" && exec pi $'/pr:feedback\n\nScope: address only unresolved review threads. Ignore threads that are already resolved.'; }
