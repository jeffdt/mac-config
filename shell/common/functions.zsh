# Worktrees managed by wt (worktrunk)
wtc() {
    wt switch --create "jeffdt/$1" -x claude
}

# Wrap pbcopy to play a sound on clipboard copy
pbcopy() {
    command pbcopy "$@"
    (afplay /System/Library/Sounds/Frog.aiff &>/dev/null &)
}

# Suppress Node's experimental SQLite warning from context-mode's MCP bridge.
pi() {
    local node_options="${NODE_OPTIONS:-}"
    local warning_flag="--disable-warning=ExperimentalWarning"

    if [[ " $node_options " != *" $warning_flag "* ]]; then
        node_options="${node_options:+$node_options }$warning_flag"
    fi

    NODE_OPTIONS="$node_options" command pi "$@"
}
