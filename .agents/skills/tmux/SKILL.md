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

## Identify "this" window before touching it

Before any action that targets "the current" window/pane — closing it,
renaming it, sending keys "here" — confirm identity with `mux status
--json`. It resolves via `$TMUX_PANE`, the pane id tmux actually assigned
this process, so it's correct even when this process is a spawned/backgrounded
agent rather than the attached client.

**Never use bare `tmux display-message -p` (no explicit `-t`) to
self-identify.** Without a target it falls back to tmux's notion of the
session's current/active window, which can be a DIFFERENT window than the
one this process is actually running in — especially for a non-interactive
process like an agent's Bash tool, where there's no real attached client to
resolve against. This has already caused a real incident: asked "what
window am I in?", a bare `tmux display-message -p` returned an unrelated
window that merely happened to be tmux's "current" one; that window was
then closed, destroying a different, active session's in-progress work. The
process asking the question was still alive afterward — proof the command
had targeted the wrong window — and the mistake stayed silent until the
user asked "did you just close a different window?"

If you must fall back to raw `tmux` instead of `mux`, always thread
`$TMUX_PANE` through explicitly rather than omitting `-t`:

```bash
tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_index} #{window_id} #{window_name}'
```

## Prefer `mux`

`mux` (`~/.agents/scripts/mux`, symlinked from `~/.local/bin/mux`) is the
allowlist-friendly wrapper around tmux, so `Bash(mux <verb>:*)` can be
allowlisted.

| Want to… | `mux` verb |
|---|---|
| Confirm backend + identity | `mux status [--json]` |
| Spawn a window + run a command | `mux spawn [--workspace caller] [--cwd P] [--cmd T] [--title N] [--focus] [--keep-open]` |
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
| Enumerate sessions / windows | `mux list workspaces` / `mux list tabs --workspace W` / `mux list tabs --all` (every window, every session — session, index, tab id, title, cwd, current command) |

**Handle contract:** workspace token = session name; tab token = window id
`@N`. `spawn` prints the tab token on stdout; pass `--json` for
`{workspace, tab, title}`. Tokens are opaque — pass them back, never parse them.
`--workspace`/`--tab` also accept human names, and `--tab` also accepts a
plain window index (e.g. `--tab 1`, matching raw tmux's `session:1`
addressing) when you only have the position, not the name or `@id`.

**`@N` is for `mux` calls, not for talking to the user.** It's tmux's internal
window id — meaningless to a human, and it doesn't even tell you which session
a window is in. Always pass an explicit `--title` when spawning (never leave a
window unnamed), and when telling the user what you did, say the session name
and window title ("the `debug` window in `pi`"), never the raw `@N` token. Keep
the token around only to pass into your own follow-up `mux` calls.

**`spawn --keep-open`** sets `remain-on-exit on` on the new window, so it
survives even if `--cmd` itself replaces the window's shell process (e.g. a
caller wrapping it in `exec`). Not needed for ordinary `--cmd` usage — `spawn`
already runs commands inside a persistent shell (see the gotcha below), so the
window outlives a normal command exit either way. Use it as a defensive
backstop for long-running interactive commands you don't fully control.

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
| `tmux display-message -p` with no `-t` doesn't mean "here" | resolves to the session's current/active window, not necessarily this process's actual pane | use `mux status --json`, or pass `-t "$TMUX_PANE"` explicitly |

## Raw tmux recipes (when `mux` doesn't cover it)

```bash
# Spawn a detached window in a named session, capture its id:
wid=$(tmux new-window -d -t "=mywork:" -c /path -n title -P -F '#{window_id}' 'cmd')

# Send a command (literal text + Enter):
tmux send-keys -t "=mywork:$wid" -l 'make test'; tmux send-keys -t "=mywork:$wid" Enter

# Read the last 200 lines including scrollback:
tmux capture-pane -p -t "=mywork:$wid" -S -200
```
