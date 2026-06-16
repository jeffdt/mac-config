---
name: tmux
description: >-
  Use when driving tmux from the shell to automate windows/panes — spawning a
  new window, sending input to another window, reading pane output, renaming or
  closing windows, or any tmux automation. Triggers include "spawn a tmux
  window", "new tmux tab", "send to another window/pane", "read the other pane",
  detecting `$TMUX` in the environment, or implementing slash commands that fan
  work across tmux windows (e.g. `/handoff:spawn`). Prefer the `mux` wrapper for
  routine automation; it fronts both tmux and cmux. In Jeff's model a session is
  a work area and a window is a tab.
---

# tmux

Reference for automating tmux from the shell, plus Jeff's conventions. For
routine automation use the `mux` wrapper (see below); it speaks one verb
interface across tmux and cmux. Drop to raw `tmux` only when `mux` lacks a recipe.

## Jeff's model (the defaults)

- **session = work area** (manually named: "data residency", "pi"), **window =
  tab** (manually named), **pane = pane**. This maps onto the cmux
  workspace/surface/pane hierarchy the ecosystem assumes.
- `~/.tmux.conf` sets `allow-rename off` + `automatic-rename off`, so window
  names are **stable lookup keys** — no defensive re-resolution mid-session.
- Prefix is `C-Space`; splits `\` (horizontal) / `-` (vertical); windows and
  panes are 1-indexed. Automation uses `send-keys` / `new-window`, which bypass
  the prefix entirely.
- Spawn default: a NEW window in the caller's session that does NOT steal focus.

## Prefer `mux`

`mux` (`~/.claude/scripts/mux`, symlinked from `~/.local/bin/mux`) is the
allowlist-friendly wrapper. It detects the backend (`$TMUX` -> tmux; else cmux)
and exposes one verb interface, so `Bash(mux <verb>:*)` can be allowlisted.

| Want to… | `mux` verb |
|---|---|
| Confirm backend + identity | `mux status [--json]` |
| Spawn a window + run a command | `mux spawn [--workspace caller] [--cwd P] [--cmd T] [--title N] [--focus]` |
| New session + run a command | `mux new-workspace --name N [--cwd] [--cmd]` |
| Send a command to a window | `mux send --workspace W --tab REF\|NAME --cmd T [--no-enter]` |
| Send a key | `mux send-key --tab REF\|NAME --key ctrl+c` (also accepts `C-c`) |
| Read a window's screen | `mux read --tab REF\|NAME [--lines N] [--scrollback]` |
| Poll until a pattern matches | `mux wait-for --tab REF\|NAME --pattern RE [--interval] [--timeout]` |
| Wait for output to stop changing | `mux settle --tab REF\|NAME [--interval] [--budget] [--required-stable]` |
| Close / rename a window | `mux close --tab …` / `mux rename --tab … --title …` |
| Focus a window (+ raise Ghostty) | `mux focus [--workspace W] [--tab REF] [--app]` |
| Resolve a session / window | `mux resolve workspace NAME` / `mux resolve tab --workspace W --title T` |
| Enumerate sessions / windows | `mux list workspaces` / `mux list tabs --workspace W` |

**Handle contract:** workspace token = session name; tab token = window id
`@N`. `spawn` prints the tab token on stdout; pass `--json` for
`{workspace, tab, title}`. Tokens are opaque — pass them back, never parse them.
`--workspace`/`--tab` also accept human names.

**Workspace targeting:** `caller` (the calling pane's session — robust, never
drifts; use for orchestrated spawns), `focused` (attached client's session),
`sticky` (folds into `caller` on tmux). `/handoff:spawn` passes `--workspace
caller`.

Exit codes: `0` ok | `1` generic/not-in-mux | `2` bad args | `3` not found |
`124` timeout.

## Gotchas

| Gotcha | Why | Fix |
|---|---|---|
| Bare `new-window` **selects** the new window | tmux makes a new window current by default | spawn without focus must use `new-window -d`; `mux spawn` does this. `--focus` drops `-d`. |
| `send-keys 'cmd'` doesn't execute | the trailing newline is a separate key event | append `Enter` (or `C-m`). `mux send` does this unless `--no-enter`. |
| `capture-pane` misses scrollback | it defaults to the visible region | pass `-S -N` (N lines back) or `-S -` (all). `mux read --scrollback`. |
| `switch-client` does nothing | no client is attached | best-effort; the window still exists and shows on next attach. |
| `new-window` accepts cwd + command in ONE call | `-c <dir>` and a trailing shell-command | no create-then-send dance (unlike cmux). |
| Session-name fuzzy match | `pi` could match `pyAI` | use the `=` exact-match prefix: `tmux ... -t "=$sess"`. `mux` does this. |
| Nested in cmux | both `$TMUX` and `$CMUX_WORKSPACE_ID` set | `mux` prefers tmux; set `MUX_BACKEND=cmux` to override. |

## Raw tmux recipes (when `mux` doesn't cover it)

```bash
# Spawn a detached window in a named session, capture its id:
wid=$(tmux new-window -d -t "=mywork:" -c /path -n title -P -F '#{window_id}' 'cmd')

# Send a command (literal text + Enter):
tmux send-keys -t "=mywork:$wid" -l 'make test'; tmux send-keys -t "=mywork:$wid" Enter

# Read the last 200 lines including scrollback:
tmux capture-pane -p -t "=mywork:$wid" -S -200
```
