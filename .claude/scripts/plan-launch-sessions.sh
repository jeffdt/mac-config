#!/usr/bin/env bash
# Launches one agent session per (repo, prompt, branch) triple.
#
# Inside tmux or cmux (detected via `mux status`): spawns each session in a
# new tab/window within the workspace/session that hosts the *calling shell*
# (resolved via `mux status --json` → workspace field), falling back to
# $CMUX_WORKSPACE_ID if mux status can't resolve.
#
# The workspace is resolved from `mux status` rather than a focus-tracking
# API so the target stays stable even if the user has switched views in the
# UI. On tmux, workspace = session name.
# Outside tmux/cmux: copies each launch command to the clipboard via pbcopy,
# with short sleeps between so a clipboard manager captures each as a
# distinct history entry.
#
# Usage:
#   plan-launch-sessions.sh [--cli claude|codex] <repo_path> <prompt_path> <branch> <subdir_relative> [<repo> <prompt> <branch> <subdir> ...]
#
# --cli selects the agent CLI used to launch each session. Default: claude.
# codex launches `codex --full-auto "$(cat <prompt>)"`; the $-escape ensures
# command substitution happens in the wt subshell, so prompt content with
# embedded quotes survives intact.
#
# <subdir_relative> is the path relative to the worktree root that the new
# session should cd into before launching the agent (pass `.` to launch at
# the repo root). All other paths must be absolute and contain no spaces.

set -euo pipefail

cli=claude
if [[ "${1:-}" == "--cli" ]]; then
  cli=${2:-}
  shift 2
  case "$cli" in
    claude|codex) ;;
    *) echo "invalid --cli value: $cli (expected claude or codex)" >&2; exit 1 ;;
  esac
fi

if (( $# == 0 )) || (( $# % 4 != 0 )); then
  echo "usage: $0 [--cli claude|codex] <repo_path> <prompt_path> <branch> <subdir_relative> [<repo> <prompt> <branch> <subdir> ...]" >&2
  exit 1
fi

build_launch_cmd() {
  local repo=$1 prompt=$2 branch=$3 subdir=$4
  case "$cli" in
    claude)
      printf 'cd %s && wt switch --create %s -x "cd %s && cat %s | claude"' "$repo" "$branch" "$subdir" "$prompt"
      ;;
    codex)
      printf 'cd %s && wt switch --create %s -x "cd %s && codex --full-auto \\"\$(cat %s)\\""' "$repo" "$branch" "$subdir" "$prompt"
      ;;
  esac
}

mode=mux
if ! command -v mux >/dev/null 2>&1; then
  mode=pbcopy
elif ! mux status >/dev/null 2>&1; then
  mode=pbcopy
fi

# In mux mode, resolve the workspace that hosts the calling shell via
# `mux status --json`. This reflects the current multiplexer session
# regardless of what the user is viewing in the UI. Fall back to
# $CMUX_WORKSPACE_ID (cmux-only, sticky to original workspace) only if
# mux status can't determine the workspace.
target_workspace=""
if [[ $mode == mux ]]; then
  status_json=$(mux status --json 2>/dev/null || true)
  if [[ -n "$status_json" ]]; then
    target_workspace=$(printf '%s' "$status_json" | sed -n 's/.*"workspace":"\([^"]*\)".*/\1/p' 2>/dev/null || true)
  fi
  if [[ -z "$target_workspace" ]]; then
    target_workspace="${CMUX_WORKSPACE_ID:-}"
  fi
fi

echo "mode: $mode"
if [[ $mode == mux && -n "$target_workspace" ]]; then
  echo "target workspace: $target_workspace"
fi

launched=()
first=1
while (( $# >= 4 )); do
  repo=$1 prompt=$2 branch=$3 subdir=$4
  shift 4

  if [[ ! -d "$repo" ]]; then
    echo "repo not found: $repo" >&2
    exit 2
  fi
  if [[ ! -f "$prompt" ]]; then
    echo "prompt file not found: $prompt" >&2
    exit 2
  fi
  if [[ "$subdir" == /* ]]; then
    echo "subdir must be relative to repo root, got absolute path: $subdir" >&2
    exit 2
  fi
  if [[ ! -d "$repo/$subdir" ]]; then
    echo "subdir not found under repo: $repo/$subdir" >&2
    exit 2
  fi

  cmd=$(build_launch_cmd "$repo" "$prompt" "$branch" "$subdir")
  label=$(basename "$repo")

  case $mode in
    mux)
      mux_args=(spawn --no-focus --cmd "$cmd" --title "$label")
      [[ -n "$target_workspace" ]] && mux_args=(spawn --workspace "$target_workspace" --no-focus --cmd "$cmd" --title "$label")
      sid=$(mux "${mux_args[@]}") \
        || { echo "mux spawn failed for $label" >&2; exit 2; }
      echo "launched $label in $sid: $cmd"
      ;;
    pbcopy)
      if (( ! first )); then sleep 0.2; fi
      printf '%s' "$cmd" | pbcopy
      echo "copied $label command to clipboard: $cmd"
      ;;
  esac

  launched+=("$label")
  first=0
done

echo
echo "done: ${#launched[@]} session(s): ${launched[*]}"
if [[ $mode == pbcopy ]]; then
  echo "last command is on clipboard; earlier commands available in clipboard history"
fi
