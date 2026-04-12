# BASE64
function b64() {
    echo "encoded: $(echo -n $1 | base64)"
    echo "decoded: $(echo $1 | base64 --decode)"
}

# Worktrees managed by wt (worktrunk)
wtc() {
    wt switch --create "jeffdt/$1" -x claude
}

# Wrap pbcopy to play a sound on clipboard copy
pbcopy() {
    command pbcopy "$@"
    (afplay /System/Library/Sounds/Frog.aiff &>/dev/null &)
}
