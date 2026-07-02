# Worktrees managed by wt (worktrunk)
wtc() {
    wt switch --create "jeffdt/$1" -x claude
}

# Wrap pbcopy to play a sound on clipboard copy
pbcopy() {
    command pbcopy "$@"
    (afplay /System/Library/Sounds/Frog.aiff &>/dev/null &)
}

# pi is installed as a global package under the fnm `default` Node. A directory
# that pins a different Node version (.node-version + direnv, e.g. the prr/prw
# PR-review worktrees) drops pi from PATH, so launching it there dies with
# "command not found: pi" -- which, under `exec pi`, takes the whole tmux window
# down. Run pi under the default Node via `fnm exec` so it works from any cwd.
# NODE_OPTIONS carries --disable-warning to suppress Node's experimental SQLite
# warning from context-mode's MCP bridge. Falls back to a bare PATH lookup if
# fnm isn't installed.
pi() {
    local node_options="${NODE_OPTIONS:-}"
    local warning_flag="--disable-warning=ExperimentalWarning"

    if [[ " $node_options " != *" $warning_flag "* ]]; then
        node_options="${node_options:+$node_options }$warning_flag"
    fi

    if command -v fnm >/dev/null 2>&1; then
        NODE_OPTIONS="$node_options" fnm exec --using=default pi "$@"
    else
        NODE_OPTIONS="$node_options" command pi "$@"
    fi
}
