---
name: cmux
description: >-
  Use when driving the `cmux` CLI to automate terminal tabs — spawning new tabs, sending input to
  other tabs, querying workspace or tab state, reading pane output, renaming or closing tabs, or any
  `cmux <subcommand>` invocation. Triggers include "spawn a cmux tab", "new cmux tab", "send to
  another tab", "open a tab in cmux", running a command in another tab, or detecting
  `$CMUX_WORKSPACE_ID` in the environment. Also use when implementing slash commands that fan work out
  across cmux tabs (e.g. `/handoff:spawn`). Note: in cmux's CLI vocabulary a "tab" is called a
  "surface" — `cmux <subcommand> --surface ...` is how you address the thing the user calls a tab.
---

# cmux

Reference for automating cmux from the shell. cmux is a terminal multiplexer with a fixed hierarchy: `window > workspace > pane > surface(tab)`. Commands take typed refs (`workspace:N`, `pane:N`, `surface:N`) and can return new refs on stdout.

> **Reader note — `$N` stripping.** Some skill-rendering pipelines treat awk positional refs (`$0`, `$1`, `$2`, `$NF`) as unset shell variables and expand them to empty before you see the recipe. To survive that, awk references in this file are written `\$N` (escaped). When you execute, drop the backslash: `awk '{print \$2}'` means `awk '{print $2}'`. If you ever see a snippet like `awk '{print }'` (nothing between the braces), the renderer ate the escape too — read this file from disk for the verbatim recipe.

## Prefer `cmx` for common recipes

`cmx` (`~/.agents/scripts/cmx`, symlinked from `~/.local/bin/cmx`) is a single-subprocess wrapper around the recipes below. Each verb runs as one bash invocation, so the user can allowlist `Bash(cmx <verb>:*)` and skip the per-call permission prompt. **Use `cmx` for routine automation; drop down to raw `cmux` only when a recipe isn't covered.**

> **Unified front door:** `mux` (`~/.agents/scripts/mux`) now fronts both tmux and
> cmux with this same verb interface. On a cmux machine, `mux <verb>` simply
> `exec`s `cmx <verb>` unchanged — so callers can target `mux` and the cmux path
> is identical to calling `cmx` directly. See the `tmux` skill for the tmux side.

Quick map:

| Want to… | `cmx` verb | Replaces |
|---|---|---|
| Check we're in cmux + daemon is up | `cmx status [--json]` | preflight block |
| Spawn a tab + run a command + focus it | `cmx spawn [--workspace W] [--cwd PATH] [--cmd TEXT] [--title NAME] [--no-focus]` | `new-surface` + `send` + `rename-tab` + focus dance |
| New workspace + focus | `cmx new-workspace --name N [--cwd] [--cmd]` | `new-workspace` + `select-workspace` + `open -a cmux` |
| Send a command to a named tab | `cmx send [--workspace W] --tab REF\|TITLE --cmd TEXT [--no-enter]` | `cmux send` + title→ref lookup |
| Send a key | `cmx send-key --tab REF\|TITLE --key NAME` | `cmux send-key` |
| Read a tab's screen | `cmx read --tab REF\|TITLE [--lines N] [--scrollback]` | `cmux read-screen` |
| Poll until a pattern matches | `cmx wait-for --tab REF\|TITLE --pattern REGEX [--interval N] [--timeout N]` | `until grep -q ...; do sleep N; done` |
| Wait for output to stop changing | `cmx settle --tab REF\|TITLE [--interval] [--budget] [--required-stable]` | `relay-auto-poll.sh` |
| Close / rename a tab | `cmx close --tab …` / `cmx rename --tab … --title …` | `close-surface` / `rename-tab` |
| Run the three-call focus dance | `cmx focus [--workspace W] [--tab REF\|TITLE] [--app]` | `move-surface --focus true` + `select-workspace` + `open -a cmux` |
| Look up a workspace by name | `cmx resolve workspace NAME` | the awk lookup |
| Look up a surface by tab title | `cmx resolve tab --workspace W --title T` | the awk lookup |
| Enumerate workspaces/tabs (with `--json`) | `cmx list workspaces` / `cmx list tabs --workspace W` | `list-workspaces` / `tree` parsing |

Shared flags: every verb that targets a workspace accepts `--workspace <focused|caller|sticky|workspace:N|<name>>`. Default is `focused` with `sticky` as fallback. **For orchestrated work that spans multiple `cmx` calls, pass `--workspace caller` (or a name/ref) explicitly** — `focused` drifts the moment the user clicks away, which silently breaks follow-up sends/reads/closes.

Exit codes: `0` ok | `1` generic/not-in-cmux | `2` bad args | `3` not found | `124` timeout.

Tab refs: `cmx` accepts either a `surface:N` ref or a tab title anywhere it takes `--tab`. Output always prints raw cmux refs (`surface:N`, `workspace:N`) so you can drop down to raw `cmux` and the refs still match.

The rest of this file documents the underlying `cmux` CLI — use it when `cmx` doesn't cover the recipe (browser surfaces, panels, tmux-compat verbs, anything not yet wrapped) or when something inside `cmx` itself needs debugging.

## Pre-flight: Are we inside cmux?

Before running any `cmux` automation, verify the environment.

```bash
if ! command -v cmux >/dev/null 2>&1 || [[ -z "${CMUX_WORKSPACE_ID:-}" ]]; then
  # Not in cmux — STOP and ask the user how to proceed.
  exit 0
fi
cmux ping >/dev/null  # confirms the daemon responds
```

**If cmux is unavailable, pause and ask the user how to proceed. Do NOT silently fall back to clipboard, file, or printout schemes.** The user may want to launch cmux, run the command somewhere else, or skip the automation entirely — that's their call, not yours.

## CRITICAL: pair `--workspace` with `--surface`

For any cross-surface operation (`send`, `send-key`, `read-screen`, `rename-tab`, `close-surface`, etc.), **always pass both `--workspace` and `--surface`**. If you pass only `--surface`, cmux defaults to `$CMUX_SURFACE_ID` (the *caller's* surface), and the error you'll get is misleading:

- `Error: invalid_params: Surface is not a terminal`
- `Error: not_found: Surface not found for the given surface_id`

Neither hints at the workspace-scoping problem. Pair the flags every time.

## Workspace targeting: caller vs focused vs sticky

There are **three** workspace concepts, not two. Picking the wrong one is the most common cause of "my tab went somewhere weird."

| Concept | How to get it | What it means |
|---|---|---|
| **Caller** | `cmux identify \| jq -r '.caller.workspace_ref'` | The workspace the **calling shell** is in right now. Tracks the shell across workspace moves. |
| **Focused** | `cmux identify \| jq -r '.focused.workspace_ref'` | The workspace the **user** is currently looking at. Can drift mid-automation if the user clicks around. |
| **Sticky** | `$CMUX_WORKSPACE_ID` | Workspace where the shell launched. Does NOT follow the shell if it's moved. Use as last-resort fallback only. |

**Decision rule:**

- **Orchestrated spawn** (Claude / a script creating sibling tabs near itself): use **caller**. The user expects new tabs to land next to the running orchestrator, not wherever they happen to be clicking when the spawn finally fires.
- **Interactive "open a tab where I'm looking"** (a human-triggered command that should follow user attention): use **focused**.
- **Daemons / cron-style work that just needs *some* valid workspace**: caller, with sticky as fallback.

The bug case `focused` causes: the user runs `/handoff:spawn`, then clicks to another workspace while Claude reads files and writes prompts. By the time `cmux identify` runs, `focused` has drifted; tabs spawn in the wrong place. `caller` is immune.

```bash
# Default for orchestrated work — use this in most automation.
caller_ws=$(cmux identify | jq -r '.caller.workspace_ref // empty')
target_ws=${caller_ws:-$CMUX_WORKSPACE_ID}

# Only when the intent is "follow user attention":
focused_ws=$(cmux identify | jq -r '.focused.workspace_ref // empty')
```

Use `target_ws` for all subsequent calls. The distinction matters for any command that spawns visible UI (new surfaces, new splits, etc.).

## Listing & inspection

| Command | Returns |
|---------|---------|
| `cmux list-workspaces` | One workspace per line: `[* ]workspace:N  <name>[  [flag]]`. Focused row prefixed `* `. Names may contain spaces. |
| `cmux list-panes --workspace W` | Pane refs + surface counts in workspace W. |
| `cmux list-pane-surfaces --workspace W` | Surfaces of the **focused pane only**, not all panes. For full enumeration, use `tree`. |
| `cmux tree [--workspace W]` | Full hierarchy printout. Surface lines: `surface surface:N [terminal] "<title>" [selected] tty=ttysXX`. |
| `cmux read-screen --workspace W --surface S --lines N [--scrollback]` | Visible/scrollback text from a surface — useful for state detection by matching log markers. |
| `cmux ping` | Returns 0 if daemon is up. Preflight only. |
| `cmux identify` | JSON with `focused.workspace_ref`, etc. Use `jq` to parse. |

## Creation

| Command | Notes |
|---------|-------|
| `cmux new-surface --pane P [--type terminal\|browser]` | Creates a tab inside an existing pane. Output is `OK surface:N pane:M workspace:K` — parse with `awk '{print \$2}'` (drop the backslash when running) and assert it starts with `surface:`. |
| `cmux new-split <left\|right\|up\|down> --workspace W --surface S` | Returns `OK surface:M workspace:N`. Deterministic when explicit `--surface` is passed. |
| `cmux new-pane [--direction D] [--type terminal\|browser]` | Uses current focus. Less deterministic than `new-split`. Prefer `new-split` for scripting. |

`cmux new-surface` without a workspace flag uses the focused pane in the current workspace. To target a specific workspace, pass `--workspace W` (cmux picks a pane within it).

**Gotcha: `new-surface` and `new-pane` do NOT accept `--cwd` or `--command`.** Only `new-workspace` does. To spawn a tab in an existing workspace and run a specific command, use the create-then-send pattern: `new-surface` to spawn the surface, then `cmux send --workspace W --surface S -- "cd … && <cmd>\n"` to deliver the command. See "spawn a tab in a named workspace" recipe below.

## Sending input

```bash
# Full-line command. Literal \n in the argument IS interpreted as newline by cmux.
cmux send --workspace "$ws" --surface "$sid" 'cd /repo && make up\n'

# Named key event. Use 'ctrl+c', 'enter', 'tab' — NOT tmux-style 'C-c'/'Enter'.
cmux send-key --workspace "$ws" --surface "$sid" ctrl+c
```

Wrong key name → `Error: invalid_params: Unknown key`. The key vocabulary is lowercase with `+` separators.

## Renaming tabs

```bash
cmux rename-tab --workspace "$ws" --surface "$sid" "review-PR-12345"
```

Tab titles set this way show up in `tree` output's quoted-name field, so renamed titles are usable as stable lookup keys (see below).

## Bringing the new tab/workspace to the foreground

**Gotcha:** `cmux new-surface` and `cmux new-workspace` create the surface/workspace, but they do **NOT** make it the focused one. The new tab opens in the background and the cmux app itself doesn't come to the foreground on macOS. If your automation ends with the user expected to start typing into the new tab, you need three explicit focus calls.

| Want to focus | Command |
|---------------|---------|
| A specific tab inside its workspace | `cmux move-surface --workspace W --surface S --focus true` |
| A specific workspace inside cmux | `cmux select-workspace --workspace W` |
| The cmux app itself (macOS) | `open -a cmux` |

`move-surface` with **no positional move target** (no `--pane`/`--workspace`/`--window`/`--before`/`--after`/`--index`) just toggles focus — the surface stays where it is. That's the lever for "I just created a tab via `new-surface`, now focus it." Suppress its `OK …` line in scripts: append `>/dev/null`.

Apply all three when spawning into an existing named workspace; apply select-workspace + `open -a cmux` (and skip `move-surface`, since a fresh workspace's default surface is already focused) when spawning a brand-new workspace.

## Worked recipe: focus a newly created tab inside an existing workspace

```bash
surface_line=$(cmux new-surface --type terminal --workspace "$ws")
sid=$(echo "$surface_line" | awk '{print \$2}')
[[ "$sid" == surface:* ]] || { echo "couldn't parse surface ref from: $surface_line" >&2; exit 1; }

cmux send        --workspace "$ws" --surface "$sid" -- "cd '$repo' && $cmd\n"
cmux rename-tab  --workspace "$ws" --surface "$sid" -- "$tab_label"
cmux move-surface --workspace "$ws" --surface "$sid" --focus true >/dev/null
cmux select-workspace --workspace "$ws"
open -a cmux
```

## Worked recipe: focus a freshly created workspace

`cmux new-workspace` prints `OK workspace:<n>` on success — parse the ref out and select it so the right workspace is foreground when cmux comes forward.

```bash
ws_line=$(cmux new-workspace --name "$name" --cwd "$cwd" --command "$cmd")
ws=$(printf '%s\n' "$ws_line" | awk '{for (i=1;i<=NF;i++) if (\$i ~ /^workspace:[0-9]+/) { print \$i; exit }}')
[ -n "$ws" ] && cmux select-workspace --workspace "$ws"
open -a cmux
```

## Identity & lookup patterns

**IDs are not stable** across cmux app restarts or workspace rebuilds. **Names are stable.** Cache nothing across sessions.

Pattern: look up workspace by name, then surfaces within it by tab title.

```bash
# Workspace lookup by name (handles "* " prefix, leading spaces, trailing "[flag]").
# Awk positional refs are escaped (\$0, \$1, \$NF) so they survive renderers
# that expand $N. Bash variables ($WS_NAME, $ws) are NOT escaped — bash needs
# to expand them. Drop the awk backslashes when running.
ws=$(cmux list-workspaces | awk -v name="$WS_NAME" '
  { sub(/^[* ]+/, ""); }
  /^workspace:[0-9]+/ {
    line = \$0
    sub(/[ \t]+\[[^]]*\][ \t]*$/, "", line)
    n = index(line, " ")
    ref = substr(line, 1, n-1)
    rest = substr(line, n+1)
    sub(/^[ \t]+/, "", rest); sub(/[ \t]+$/, "", rest)
    if (rest == name) { print ref; exit }
  }')

# Surface lookup by tab title within a workspace (tree → TSV → match).
sid=$(cmux tree --workspace "$ws" \
  | awk 'match(\$0, /surface surface:[0-9]+/) {
      ref = substr(\$0, RSTART+8, RLENGTH-8)
      if (match(\$0, /"[^"]*"/)) {
        title = substr(\$0, RSTART+1, RLENGTH-2)
        print ref "\t" title
      }
    }' \
  | awk -F'\t' -v t="$TAB_TITLE" '\$2 == t { print \$1; exit }')
```

## Closing tabs

```bash
cmux close-surface --workspace "$ws" --surface "$sid"
```

## Worked recipe: spawn a tab in a named workspace + run a command

Use when you need a NEW tab inside a SPECIFIC named workspace (not the focused
one) — e.g. routing PR reviews into a dedicated `pr reviews` workspace.
Combines the workspace-by-name lookup with the create-then-send pattern.

Why name-based lookup: workspace refs (`workspace:N`) are not stable across
cmux restarts. Names are. Re-resolve every time; never cache.

```bash
WS_NAME="pr reviews"

# 1. Resolve workspace ref by name (re-resolved each call — refs aren't stable).
#    Awk positional refs are escaped (\$0); drop the backslash when running.
ws=$(cmux list-workspaces | awk -v name="$WS_NAME" '
  { sub(/^[* ]+/, ""); }
  /^workspace:[0-9]+/ {
    line = \$0
    sub(/[ \t]+\[[^]]*\][ \t]*$/, "", line)
    n = index(line, " ")
    ref = substr(line, 1, n-1)
    rest = substr(line, n+1)
    sub(/^[ \t]+/, "", rest); sub(/[ \t]+$/, "", rest)
    if (rest == name) { print ref; exit }
  }')
[ -n "$ws" ] || { echo "workspace not found: $WS_NAME" >&2; exit 1; }

# 2. Create a fresh terminal surface in that workspace.
surface_line=$(cmux new-surface --type terminal --workspace "$ws")
sid=$(echo "$surface_line" | awk '{print \$2}')
[[ "$sid" == surface:* ]] || { echo "couldn't parse surface ref from: $surface_line" >&2; exit 1; }

# 3. Send cd + command. cmux interprets the literal \n at the end as enter.
cmux send --workspace "$ws" --surface "$sid" -- "cd '$repo' && $cmd\n"

# 4. Rename the tab so it's identifiable later.
cmux rename-tab --workspace "$ws" --surface "$sid" -- "$tab_label"

# 5. Focus the new tab, the workspace, and the app. Skip these and the tab
#    opens in the background and the user has to click to it.
cmux move-surface --workspace "$ws" --surface "$sid" --focus true >/dev/null
cmux select-workspace --workspace "$ws"
open -a cmux
```

Compare with `cmux new-workspace --name … --cwd … --command …` when you want a
brand-new workspace per invocation (e.g. one-off triage sessions). Use the
named-workspace path when invocations should accumulate as tabs in a stable
home (e.g. PR reviews, ongoing work queues). The new-workspace path also needs
explicit focus — see the "focus a freshly created workspace" recipe above.

**Sharp edge — embedding this awk in a Lua `[[ … ]]` long string.** The
workspace-lookup regex contains `[^]]` (negated char class with `]`), which
expands to `]]` — and `]]` prematurely closes a level-0 Lua long string. If
you're generating shell scripts from Lua (e.g. inside a Hammerspoon module),
use a level-N delimiter like `[==[ … ]==]`. The Lua parse error is
`unexpected symbol near '\'`, which doesn't hint at the real cause; if you see
that while editing this kind of script, suspect an unbalanced `]]` inside the
embedded awk before anything else.

## Worked recipe: spawn a fresh tab + claude + prompt-from-file

Common pattern: spawn a new tab in the focused workspace, cd into a repo, start `claude` with a prompt piped from a file.

```bash
focused_ws=$(cmux identify | jq -r '.focused.workspace_ref // empty')
target_ws=${focused_ws:-$CMUX_WORKSPACE_ID}

# Create a new terminal surface in the target workspace.
# Awk positional ref escaped (\$2); drop the backslash when running.
surface_line=$(cmux new-surface --type terminal --workspace "$target_ws")
sid=$(echo "$surface_line" | awk '{print \$2}')
[[ "$sid" == surface:* ]] || { echo "could not parse surface ref from: $surface_line" >&2; exit 2; }

# Send the launch command. Note the literal \n at the end to execute.
# IMPORTANT: the leading `cd $repo_path` is load-bearing — new surfaces inherit
# the SPAWNING shell's cwd, NOT any workspace-default or per-tab cwd. Drop the cd
# and tools like `wt switch --create` will operate on whatever directory the
# orchestrator happened to be in, which is rarely the repo you want.
cmd="cd $repo_path && wt switch --create $branch -x \"cat $prompt_path | claude\""
cmux send --workspace "$target_ws" --surface "$sid" -- "${cmd}\n"

# Optional: rename so the tab is identifiable later.
cmux rename-tab --workspace "$target_ws" --surface "$sid" "$tab_label"

# Focus the new tab + surface its workspace + foreground the app. Without these,
# the tab opens behind whatever the user is currently looking at.
cmux move-surface --workspace "$target_ws" --surface "$sid" --focus true >/dev/null
cmux select-workspace --workspace "$target_ws"
open -a cmux
```

## Worked recipe: send a command to an existing named tab

```bash
ws=$(cmux list-workspaces | awk '...')   # see lookup pattern above
sid=$(cmux tree --workspace "$ws" | ...) # see lookup pattern above

cmux send --workspace "$ws" --surface "$sid" -- "make test\n"
```

## Worked recipe: poll a surface's output for a marker

```bash
ws=$CMUX_WORKSPACE_ID
sid=$target_sid

until cmux read-screen --workspace "$ws" --surface "$sid" --lines 200 \
        | grep -q "Build succeeded"; do
  sleep 2
done
```

## Useful environment variables

- `$CMUX_WORKSPACE_ID` — workspace where this shell launched (sticky).
- `$CMUX_SURFACE_ID` — surface where this shell launched.
- `$CMUX_TAB_ID` — tab id (alias for surface in most contexts).
- `$CMUX_SOCKET_PASSWORD` — IPC auth, if not using saved Settings password.

Most commands fall back to these env vars when `--workspace`/`--surface` flags are omitted — which is exactly what causes the misleading errors above. **Be explicit.**

## Unverified APIs (exist, not exercised)

These appear in `cmux --help` but haven't been battle-tested. Verify behavior before relying on them:

- `cmux pipe-pane --command CMD [--workspace W] [--surface S]` — pipes pane output through an external shell command (tmux-like).
- `cmux tab-action --action <name>` — generic action dispatcher. Vocabulary: `rename`, `clear-name`, `close-left`, `close-right`, `close-others`, `new-terminal-right`, `new-browser-right`, `reload`, `duplicate`, `pin`, `unpin`, `mark-unread`. **No `focus`/`select` action** — use `move-surface --focus true` for tab focus instead.
- `cmux focus-pane --pane P [--workspace W]` — explicit pane focus (takes pane ref, not surface). Focuses a pane, but does NOT pick which surface within the pane is active. For surface-level focus use `move-surface --focus true`.
- `cmux reorder-surface`, `cmux drag-surface-to-split` — manipulate existing surfaces.
- `cmux surface-health [--workspace W]` — health check.
- `cmux capture-pane` — listed in `--help`, behavior unverified.
- `cmux notify --title T [--body B]` — programmatic notification.
- `cmux send-panel`, `cmux send-key-panel`, `cmux focus-panel`, `cmux list-panels` — "panels" are a separate primitive from "panes" (likely sidebar/info panels). Don't confuse them.

When using any of these, run a small probe first and update this section with verified behavior.

## Common mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `--surface` without `--workspace` | `Surface is not a terminal` or `Surface not found` | Pair both flags. |
| Using `$CMUX_WORKSPACE_ID` when the user has moved the session | Tabs spawn in the wrong workspace | Use `cmux identify` to get the focused workspace. |
| Tmux-style key names (`C-c`, `Enter`) | `invalid_params: Unknown key` | Lowercase with `+`: `ctrl+c`, `enter`. |
| Forgetting `\n` in `cmux send` | Command typed but not executed | Append `\n` (cmux interprets the literal). |
| Omitting `cd <repo>` when sending a worktree/repo-scoped command to a new surface | `wt switch --create`, `git`, or build tools operate on the orchestrator's cwd instead of the target repo (e.g. a worktree gets created off the wrong repo) | New surfaces inherit the spawning shell's cwd. Always prefix the sent command with `cd <absolute-repo-path> && …`. |
| Caching surface/workspace IDs across sessions | Stale refs after restart | Look up by name/title each time. |
| Using `list-pane-surfaces` to enumerate a workspace | Misses surfaces in non-focused panes | Use `tree` for full enumeration. |
| Silently doing nothing / falling back when not in cmux | User confused by missing tabs | Pause and ask the user how to proceed. |
| `new-surface` / `new-workspace` followed by no focus calls | New tab opens behind another tab; cmux app stays in background | Follow with `move-surface --focus true` + `select-workspace` + `open -a cmux`. See "Bringing the new tab/workspace to the foreground". |
