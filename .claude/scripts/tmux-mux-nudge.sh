#!/bin/bash
set -euo pipefail

# PreToolUse hook (matcher: Bash, if: "Bash(tmux *)" — see ~/.claude/settings.json).
#
# Fires on every raw `tmux` Bash invocation. Logs the attempt to
# ~/.claude/logs/raw-tmux-usage.jsonl for periodic review (see
# ~/.agents/skills/tmux/SKILL.md) — including whether the subcommand already
# has a direct `mux` equivalent, a cheap prefix check, not real semantic
# judgment, so it can't tell whether this exact invocation's flags/arguments
# are actually covered. Never blocks or prompts; triage happens later by
# reading the log, not by interrupting the agent mid-task.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

if [[ -z "$command" ]]; then
  exit 0
fi

# Belt-and-suspenders: the settings.json `if` matcher already restricts
# invocation to `tmux *` commands, but re-check here too so this script
# stays correct even if that wiring ever changes.
if [[ ! "$command" =~ ^[[:space:]]*tmux([[:space:]]|$) ]]; then
  exit 0
fi

# $2 (skipping known value-taking global flags) is the subcommand.
subcommand=$(echo "$command" | awk '{
  for (i=2; i<=NF; i++) {
    if ($i == "-L" || $i == "-S" || $i == "-f") { i++; continue }
    if ($i ~ /^-/) continue
    print $i
    exit
  }
}')

mux_equivalent=""
case "$subcommand" in
  display-message) mux_equivalent="mux status" ;;
  new-window) mux_equivalent="mux spawn" ;;
  new-session) mux_equivalent="mux new-workspace" ;;
  send-keys) mux_equivalent="mux send / mux send-key" ;;
  paste-buffer | set-buffer) mux_equivalent="mux paste" ;;
  capture-pane) mux_equivalent="mux read" ;;
  kill-window) mux_equivalent="mux close" ;;
  rename-window) mux_equivalent="mux rename" ;;
  select-window | switch-client) mux_equivalent="mux focus" ;;
  list-sessions | list-windows) mux_equivalent="mux list" ;;
esac

log_dir="$HOME/.claude/logs"
mkdir -p "$log_dir"
jq -n \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg session "$session_id" \
  --arg cwd "$cwd" \
  --arg command "$command" \
  --arg subcommand "$subcommand" \
  --arg mux_equivalent "$mux_equivalent" \
  '{ts:$ts, session:$session, cwd:$cwd, command:$command, subcommand:$subcommand, mux_equivalent:$mux_equivalent}' \
  >> "$log_dir/raw-tmux-usage.jsonl"

exit 0
