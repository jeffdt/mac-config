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

# Debug log for the PR launcher flow (prr/prw/prf/prd). Tentacle-spawned tmux
# windows run the launcher and then `exec` the chosen CLI (claude for prr/prw;
# claude or pi for prd/prf); if anything before the handoff fails or the CLI
# exits immediately, the window can vanish before its output can be read. This
# file records how far slot prep got and whether the exec handoff was reached.
# It lives under $TMPDIR (macOS purges it, so it never grows unbounded across
# reboots); override with $PR_LAUNCHER_LOG. Tail it while reproducing:
#   tail -F "${TMPDIR:-/tmp}/pr-launcher.log"
_PR_LOG_FILE="${PR_LAUNCHER_LOG:-${TMPDIR:-/tmp}/pr-launcher.log}"
_pr_log() {
    print -r -- "$(date '+%Y-%m-%d %H:%M:%S') [pid $$] ${funcstack[2]:-?}: $*" >> "$_PR_LOG_FILE" 2>/dev/null
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
    _pr_log "ENTER input='${input}' cwd='$PWD'"

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
    _pr_log "parsed org='$org' repo='$repo' number='$number'"

    local repo_path
    if ! repo_path="$(_pr_locate_repo "$repo")"; then
        _pr_log "FAIL repo not found: '$repo' (PR_REPO_BASE_DIRS='${PR_REPO_BASE_DIRS:-<unset>}')"
        _pr_locate_repo_error "$caller" "$repo"
        return 1
    fi
    # Slots are keyed on PR number so multiple reviews on the same repo can
    # run in parallel. Re-running on the same PR reuses its existing slot.
    local slot_path="${repo_path}.pr-review-${number}"
    _pr_log "repo_path='$repo_path' slot_path='$slot_path' slot_exists=$([[ -d "$slot_path" ]] && echo yes || echo no)"

    if [[ ! -d "$slot_path" ]]; then
        _pr_log "fetch origin in '$repo_path'"
        git -C "$repo_path" fetch origin >/dev/null || { _pr_log "FAIL fetch rc=$?"; return 1; }
        _pr_log "worktree add --detach '$slot_path' origin/HEAD"
        git -C "$repo_path" worktree add --detach "$slot_path" origin/HEAD || { _pr_log "FAIL worktree add rc=$?"; return 1; }
    fi

    if ! git -C "$slot_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _pr_log "FAIL slot exists but not a worktree: '$slot_path'"
        echo "$caller: $slot_path exists but is not a git worktree. Remove it and retry." >&2
        return 1
    fi

    local current_branch expected_branch
    current_branch="$(git -C "$slot_path" branch --show-current 2>/dev/null)"
    expected_branch="$(gh pr view "$number" --json headRefName -q .headRefName --repo "$org/$repo" 2>/dev/null)"
    _pr_log "current_branch='$current_branch' expected_branch='$expected_branch'"

    if [[ -n "$current_branch" && "$current_branch" == "$expected_branch" ]]; then
        _pr_log "branch already checked out; cd into slot (direnv fires here)"
        cd "$slot_path" || { _pr_log "FAIL cd rc=$?"; echo "$caller: could not cd into $slot_path" >&2; return 1; }
        _pr_log "RETURN 0 (reused slot) cwd='$PWD'"
        return 0
    fi

    _pr_log "cd into slot (direnv fires here)"
    cd "$slot_path" || { _pr_log "FAIL cd rc=$?"; return 1; }
    _pr_log "git reset --hard"
    git reset --hard >/dev/null || { _pr_log "FAIL reset rc=$?"; return 1; }
    _pr_log "git clean -fd"
    git clean -fd >/dev/null || { _pr_log "FAIL clean rc=$?"; return 1; }
    _pr_log "git fetch origin"
    git fetch origin || { _pr_log "FAIL fetch rc=$?"; return 1; }
    _pr_log "gh pr checkout $number"
    gh pr checkout "$number" || { _pr_log "FAIL gh pr checkout rc=$?"; return 1; }
    _pr_log "RETURN 0 (checked out) cwd='$PWD'"
}

# Run slot prep, then hand off to claude. /pr:review and /pr:walkthrough are
# structured, multi-subagent workflows that Claude coordinates (the review
# orchestrator delegates to Codex for model diversity), so prr/prw are pinned
# to claude with no engine choice. Logging is split out so the launcher log
# shows the prep result and whether the `exec claude` handoff was reached, even
# if claude itself exits immediately afterward and takes the tmux window down.
_pr_launch() {
    local prompt="$1"; shift
    _pr_prepare_slot "$@"
    local rc=$?
    _pr_log "_pr_prepare_slot rc=$rc; $([[ $rc -eq 0 ]] && echo "exec claude ${prompt%%$'\n'*}" || echo "NOT exec'ing claude") cwd='$PWD'"
    (( rc == 0 )) && exec claude "$prompt"
    return $rc
}
prr() { _pr_launch "/pr:review" "$@"; }
prw() { _pr_launch "/pr:walkthrough" "$@"; }

# Resolve an optional leading engine flag for the selectable launchers (prd/prf)
# into the CLI to exec. Defaults to claude. `--gpt`/`--pi` route to pi (GPT);
# `--claude` is the explicit default. Sets the `engine` and `nshift` locals in
# the caller's scope (nshift = how many args to shift off the flag).
_pr_engine() {
    engine=claude
    nshift=0
    case "$1" in
        --gpt|--pi) engine=pi;     nshift=1 ;;
        --claude)   engine=claude; nshift=1 ;;
    esac
}

# Open a fresh session on a PR with a user-typed opening instruction (the
# "Discuss…" mode from the Tentacle dropdown). The engine is selectable because
# a discuss can be anything from a narrow technical question to a broad
# architectural debate; defaults to claude, `--gpt`/`--pi` routes to GPT via pi.
# Uses the feedback-style slot prep so discuss-mode on your own open PR reuses
# your existing feature worktree rather than failing to check the branch out
# twice; for others' PRs it falls back to a per-PR review slot.
prd() {
    local engine nshift
    _pr_engine "$1"; shift $nshift
    local url="$1" prompt="$2"
    if [[ -z "$url" || -z "$prompt" ]]; then
        echo "prd: usage: prd [--claude|--gpt] <pr-url> <prompt>" >&2
        return 1
    fi
    _pr_feedback_prepare "$url" && exec "$engine" "$prompt"
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

# Engine-selectable like prd (default claude, `--gpt`/`--pi` for GPT): addressing
# review threads is usually mechanical, but a thread can turn into a design call.
prf() {
    local engine nshift
    _pr_engine "$1"; shift $nshift
    _pr_feedback_prepare "$@" && exec "$engine" $'/pr:feedback\n\nScope: address only unresolved review threads. Ignore threads that are already resolved.'
}
