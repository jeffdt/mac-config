---
name: relay-auto
description: >-
  Activate relay-auto mode: clipboard commands to the user (like relay) AND
  read the output of a designated tab/window automatically. Use when the user
  asks to "auto relay", "watch the other tab", or invokes `/relay:auto`.
  Requires tmux or cmux. NEVER injects input into the watched tab; clipboard only.
---

You are now in **relay-auto mode**. Follow these rules until the user exits the mode or the task is naturally complete.

## Hard rules (non-negotiable)

1. **NEVER send input to the watched tab.** Forbidden against the watched tab: `mux send`, `mux send-key` (and any raw `tmux send-keys` / `cmux send` to it). The user is the only thing that types there.
2. **Allowed `mux` verbs in this mode:** `status`, `read`, `settle`, `wait-for`, `resolve`, `list`, `rename`.
3. **Sends to other surfaces are fine.** The rule scopes to the watched surface only. Handoff spawns and similar still work.
4. **All commands you want the user to run go through `pbcopy`.** No sentinel injection. No regex prompt parsing. You read the screen and judge from context.

## Activation

Run these steps once when entering the mode.

1. **Preflight mux:**

   ```bash
   if ! command -v mux >/dev/null 2>&1; then
     echo "relay-auto needs mux on PATH" >&2; exit 1
   fi
   mux status >/dev/null 2>&1 || { echo "relay-auto: not inside tmux or cmux" >&2; exit 1; }
   ```

   If preflight fails, tell the user clearly and exit the mode.

2. **Resolve the watched tab:**

   - Get this session's identity: parse `mux status --json` to extract `workspace` and `tab` fields.
   - Enumerate tabs in the workspace: `mux list tabs --workspace "$ws"`.
   - Exclude your own tab (the one in `mux status`). If exactly one remains, use it.
   - If multiple, list them (tab ref + title) and ask the user which one to watch.
   - If zero, tell the user to open the target tab and re-run.
   - If the user passed an argument to `/relay:auto`, treat it as a tab title and match against the candidates.

3. **Persist target to state file:**

   ```bash
   self_tab="$(mux status --json | sed -n 's/.*"tab":"\([^"]*\)".*/\1/p')"
   state_file="/tmp/.claude-relay-auto-state.${self_tab//[:@\/]/_}"
   {
     echo "ws=$target_ws"
     echo "sid=$target_sid"
     echo "title=$target_title"
   } > "$state_file"
   ```

4. **Confirm:** "Watching `<title>` (`<sid>` in `<ws>`). I will pbcopy commands for you to paste; you don't need to switch back here."

## Per-turn loop

For each command you want the user to run:

1. **Draft the command.** Explain briefly what it does and what to look for.

2. **Copy it to the clipboard:**

   ```bash
   echo -n 'COMMAND_HERE' | pbcopy
   ```

   Strip markdown formatting. Escape single quotes appropriately.

3. **Wait for the output to settle:**

   ```bash
   self_tab="$(mux status --json | sed -n 's/.*"tab":"\([^"]*\)".*/\1/p')"
   state_file="/tmp/.claude-relay-auto-state.${self_tab//[:@\/]/_}"
   . "$state_file"   # sources ws=, sid=, title=
   mux settle --workspace "$ws" --tab "$sid"
   ```

   Exit codes:
   - `0`: settled. Read the printed screen. Decide next step from conversation context + visible output.
   - `1`: read-screen errored. Tab is likely closed or daemon is down. Tell the user, exit the mode.
   - `124`: budget expired (90s) without settling. Print the last screen and ask the user whether to keep waiting, send Ctrl+C themselves, or move on.

4. **Move on.** Draft the next command, or report the result, or ask a clarifying question.

## Exit conditions

Exit the mode when:

- The user says "stop", "done with relay-auto", "exit relay-auto", "exit auto", or similar.
- `mux settle` returns exit code 1 (target tab gone or daemon down).
- The task is naturally complete.

On exit:

```bash
self_tab="$(mux status --json | sed -n 's/.*"tab":"\([^"]*\)".*/\1/p')"
rm -f "/tmp/.claude-relay-auto-state.${self_tab//[:@\/]/_}"
```

And tell the user the mode is off.

## Failure handling

- **Output looks unrelated** to the last command (user ran something else in the tab): show what you read and ask, don't guess.
- **Polling budget expires repeatedly**: ask the user if relay-auto is the right tool for this workflow (long-running servers fit poorly).
- **The user pastes output back to you manually anyway**: trust their paste over what you read; they're closer to ground truth.
