---
name: tmux
description: >-
  Use when driving tmux from the shell to automate windows/panes — spawning a
  new window, sending input to another window, reading pane output, renaming or
  closing windows, or any tmux automation. Triggers include "spawn a tmux
  window", "new tmux tab", "send to another window/pane", "read the other pane",
  detecting `$TMUX` in the environment, or implementing slash commands that fan
  work across tmux windows (e.g. `/handoff:spawn`). Prefer the `mux` wrapper for
  routine automation. In Jeff's model a session is a work area and a window is
  a tab.
---

# tmux

Reference for automating tmux from the shell, plus Jeff's conventions. For
routine automation use the `mux` wrapper (see below). Drop to raw `tmux` only
when `mux` lacks a recipe.

## Jeff's model (the defaults)

- **session = work area** (manually named: "data residency", "pi"), **window =
  tab** (manually named), **pane = pane**.
- `~/.tmux.conf` sets `allow-rename off` + `automatic-rename off`, so window
  names are **stable lookup keys** — no defensive re-resolution mid-session.
- Prefix is `C-Space`; splits `\` (horizontal) / `-` (vertical); windows and
  panes are 1-indexed. Automation uses `send-keys` / `new-window`, which bypass
  the prefix entirely.
- Spawn default: a NEW window in the caller's session that does NOT steal focus.

## Never steal focus unless asked

Default to leaving the user's terminal and window selection alone. Spawning a
window, sending a command, or reading a pane must NOT raise Ghostty,
`select-window`, or `switch-client` — the user should be able to keep working
wherever they are without being yanked away.

- Never pass `mux spawn --focus`, call `mux focus`, or hand-roll
  `select-window`/`switch-client` on your own initiative. Only do it when the
  user explicitly asks to see the result of a specific action right now (e.g.
  "show me that window" or "pull that up").
- The one standing exception is a user-initiated launch button/link (e.g. the
  PR-review Hammerspoon trigger in `~/.hammerspoon`) — there the user personally
  clicked something to kick off the action, so surfacing the result is the
  point. That exception lives in the launcher, not in how you drive `mux`
  yourself.
- If you're unsure whether a spawn should focus, don't — leave it backgrounded
  and tell the user where to find it (session/window name) instead of forcing
  it into view.

## Prefer `mux`

`mux` (`~/.agents/scripts/mux`, symlinked from `~/.local/bin/mux`) is the
allowlist-friendly wrapper around tmux, so `Bash(mux <verb>:*)` can be
allowlisted.

| Want to… | `mux` verb |
|---|---|
| Confirm backend + identity | `mux status [--json]` |
| Spawn a window + run a command | `mux spawn [--workspace caller] [--cwd P] [--cmd T] [--title N] [--focus]` |
| New session + run a command | `mux new-workspace --name N [--cwd] [--cmd]` |
| Send a command to a window | `mux send --workspace W --tab REF\|NAME --cmd T [--no-enter]` |
| Send a key | `mux send-key --tab REF\|NAME --key ctrl+c` (also accepts `C-c`) |
| Deliver multi-line text (safe for pastes) | `mux paste --workspace W --tab REF\|NAME [--enter]` |
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

**`@N` is for `mux` calls, not for talking to the user.** It's tmux's internal
window id — meaningless to a human, and it doesn't even tell you which session
a window is in. Always pass an explicit `--title` when spawning (never leave a
window unnamed), and when telling the user what you did, say the session name
and window title ("the `debug` window in `pi`"), never the raw `@N` token. Keep
the token around only to pass into your own follow-up `mux` calls.

**Workspace targeting:** `caller` (the calling pane's session — robust, never
drifts; use for orchestrated spawns), `focused` (attached client's session).
`/handoff:spawn` passes `--workspace caller`.

Exit codes: `0` ok | `1` generic/not-in-mux | `2` bad args | `3` not found |
`124` timeout.

## Gotchas

| Gotcha | Why | Fix |
|---|---|---|
| Bare `new-window` **selects** the new window | tmux makes a new window current by default | spawn without focus must use `new-window -d`; `mux spawn` does this. `--focus` drops `-d`. |
| `send-keys 'cmd'` doesn't execute | the trailing newline is a separate key event | append `Enter` (or `C-m`). `mux send` does this unless `--no-enter`. |
| `send`/`send-key` mangle multi-line text | embedded newlines act like real Enter presses | use `mux paste` (tmux paste-buffer), which delivers text as one paste event instead of keystrokes. |
| `capture-pane` misses scrollback | it defaults to the visible region | pass `-S -N` (N lines back) or `-S -` (all). `mux read --scrollback`. |
| `switch-client` does nothing | no client is attached | best-effort; the window still exists and shows on next attach. |
| `new-window` accepts cwd + command in ONE call | `-c <dir>` and a trailing shell-command | pass both directly; no create-then-send dance needed for that part. |
| Session-name fuzzy match | `pi` could match `pyAI` | use the `=` exact-match prefix: `tmux ... -t "=$sess"`. `mux` does this. |

## Raw tmux recipes (when `mux` doesn't cover it)

```bash
# Spawn a detached window in a named session, capture its id:
wid=$(tmux new-window -d -t "=mywork:" -c /path -n title -P -F '#{window_id}' 'cmd')

# Send a command (literal text + Enter):
tmux send-keys -t "=mywork:$wid" -l 'make test'; tmux send-keys -t "=mywork:$wid" Enter

# Read the last 200 lines including scrollback:
tmux capture-pane -p -t "=mywork:$wid" -S -200
```
