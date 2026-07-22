---
name: web-to-tmux-launcher
description: This skill should be used when the user asks to "add a click-launcher for [site]", "wire up [website] to tmux", "browser→hammerspoon→tmux→claude", "create a hammerspoon URL flow", or describes wanting a browser button on a third-party site that spawns a fresh tmux window running Claude with site-specific context. Trigger this whenever the user wants to extend Jeff's existing browser→hammerspoon→tmux→claude pattern (canonical example - GitHub PR Review/Walkthrough buttons via the Tentacle Chrome extension). Also trigger when the user describes the workflow without naming the components, e.g. "I want a button on Sentry issue pages that opens claude in a debugging session", "let me click a Linear ticket and start planning it", or "kick off a [task] from [website]". Do not roll a new handler from scratch when this skill applies - it routes through Jeff's Tentacle + hammerspoon + tmux_spawn architecture and every launcher follows the same shape.
---

# Web → Tmux Launcher Pattern

Jeff has an established architecture for "click a button on a third-party website, get a fresh tmux window with Claude already running on the right context." The canonical implementations are the GitHub PR Review, Walkthrough, Feedback, and Discuss buttons. This skill captures the pattern so new launchers (Sentry triage, Linear planning, PagerDuty response, etc.) follow the same shape rather than reinventing.

## Architecture overview

```
[Tentacle Chrome extension]
         |
         | hammerspoon://tentacle?site=<s>&url=<u>&mode=<m>
         v
[~/.hammerspoon/tentacle.lua]    <- single dispatcher
    SITE_PARSERS  (url -> identifier table)
    DISPATCH      ("<site>/<mode>" -> tmux_spawn opts builder)
         |
         | tmux_spawn.spawn({ name, cwd, command, workspace? })
         v
[~/.hammerspoon/lib/tmux_spawn.lua]    <- shared engine
    ensures tmux session exists (created on demand)
    opens a new window with -d (does not steal focus)
    sends command into a shell (create-then-send, keeps window alive)
    open -a Ghostty   <- raise terminal
    switch-client     <- best-effort focus (no-op if no attached client)
```

This replaced the earlier per-site architecture (individual `<name>_claude.lua` handlers per site, plus per-site Tampermonkey userscripts). Everything now flows through `tentacle.lua`.

## The three components

Every launcher has these three pieces. The shared engine is built; the per-launcher pieces are small additions to `tentacle.lua`.

1. **Tentacle Chrome extension** — injects buttons on target sites and emits `hammerspoon://tentacle?site=<s>&url=<u>&mode=<m>` when clicked. The extension handles button injection; no per-site Tampermonkey userscript is needed.

2. **`tentacle.lua` entries** — two additions per new (site, mode) pair:
   - `SITE_PARSERS["<site>"]` — a function `(url) -> identifier table | nil` that parses the page URL into structured fields (owner/repo/num for GitHub PRs, org/id for Sentry, etc.). Omit if the site already has an entry.
   - `DISPATCH["<site>/<mode>"]` — a function `(parsed) -> tmux_spawn opts` that returns `{ name, cwd, command, workspace? }`. This is the only place per-launcher logic lives.

3. **Shell launcher (optional)** — a zsh function that does state setup the workflow needs (worktree slot, fetch, checkout, env), then `exec pi "/<slash-command>"`. For PR review this is `prr`/`prw` in `~/shell/common/git.zsh`. For read-only workflows with no setup, the DISPATCH builder can invoke `pi`/`claude` directly.

`~/.hammerspoon/lib/tmux_spawn.lua` is the shared engine. Its signature is `M.spawn({ name, cwd, command, prelude?, workspace? })`. Don't touch it; just call it via the DISPATCH builder.

## URL contract

The Tentacle extension emits:

```
hammerspoon://tentacle?site=<s>&url=<u>&mode=<m>
```

Parameters:
- `site` — matches a key in `SITE_PARSERS` (e.g. `github-pr`, `sentry-issue`, `linear-ticket`)
- `url` — the full page URL; parsed by the site's SITE_PARSERS entry
- `mode` — matches the second segment of a DISPATCH key (e.g. `review`, `walkthrough`, `triage`)
- `prompt` (optional) — arbitrary user text; currently only used by `github-pr/discuss`

Note: `tentacle.lua` re-parses from the raw URL (not Hammerspoon's pre-decoded params table) to correctly handle `+`-encoded spaces in `prompt` values.

## Knobs to fill in for each new launcher

When designing a launcher, decide these up front.

| Knob | Example: PR review | Example: Sentry triage |
|------|-------------------|------------------------|
| `site` key | `github-pr` (existing) | `sentry-issue` (existing) |
| `mode` key | `review` | `triage` |
| SITE_PARSERS entry needed? | No (already present) | No (already present) |
| URL regex / capture groups | `github%.com/([^/]+)/([^/]+)/pull/(%d+)` | `([^.]+)%.sentry%.io/issues/(%d+)` |
| `workspace` (tmux session) | `"pr reviews"` | `"workbench"` |
| Window `name` format | `"🤖 <repo> #<num>"` | `"🚑 sentry #<id>"` |
| Shell launcher | `prr` (handles worktree slot + checkout) | `sentry-triage` (maps project -> repo dir) |
| State prep needed? | Yes — `.pr-review` worktree slot, `gh pr checkout` | Yes — project -> cwd mapping |

The shell launcher is where "prepare the environment before claude starts" logic goes. If nothing needs preparation, the DISPATCH builder can invoke the slash command directly.

## Step-by-step checklist

1. **Confirm knobs.** Mode name, workspace name, and whether a new SITE_PARSERS entry is needed usually require confirmation first.

2. **Add a SITE_PARSERS entry** if the site is new. The function receives the raw page URL and returns a table of identifiers (or nil if the URL does not match). Use Lua patterns, not regex: `%d` for digits, `[^/]+` for path segments, `%.` to escape literal dots.

3. **Add a DISPATCH entry** for `"<site>/<mode>"`. Return `tmux_spawn` opts:
   ```lua
   ["mysite/mymode"] = function(p)
     return {
       name      = string.format("🔧 %s #%s", p.repo, p.id),
       cwd       = os.getenv("HOME"),
       command   = string.format("my-launcher %q", p.url),
       workspace = "my workspace",
     }
   end,
   ```
   `workspace` is the tmux session name (created on demand if absent). Omit `workspace` to use `name` as the session name — fresh-session mode, like `wt_prune.lua`.

4. **Write the shell launcher** if state setup is needed — a zsh function in `~/shell/common/<area>.zsh`. Otherwise skip; have the DISPATCH builder invoke `pi`/`claude` directly.

5. **Reload Hammerspoon**: `hs -c "hs.reload()"`. Verify tentacle loaded cleanly: `hs -c "print(require('tentacle'))"`. If it errors, it is almost always the Lua long-string `]]` issue (see gotchas).

6. **Smoke-test from the CLI** before involving the browser: `open "hammerspoon://tentacle?site=<s>&url=<u>&mode=<m>"`. Watch the Hammerspoon console: `hs -c "local c = hs.console.getConsole(true); local lines = c:asTable(); for i=math.max(1,#lines-15), #lines do print(tostring(lines[i])) end"`. Then check tmux: `tmux list-sessions` and `tmux list-windows -t "<workspace>"`.

7. **Coordinate with the Tentacle extension** to add the new `(site, mode)` button. The extension side is separate from the hammerspoon side; this step surfaces the button in the browser.

## Worked examples (canonical implementations)

Read `~/.hammerspoon/tentacle.lua` for the full picture. Key entries to study:

- `SITE_PARSERS["github-pr"]` — regex with three captures (owner, repo, num)
- `DISPATCH["github-pr/review"]` — returns `{ name, cwd, command, workspace }` where `command` delegates to the `prr` shell launcher
- `DISPATCH["github-pr/discuss"]` — shows how `parsed.prompt` (from the `prompt` URL param) flows through to the shell command via `shquote()`
- `DISPATCH["linear-ticket/plan"]` — fresh-session mode: no `workspace`, so `name` becomes the session name

`~/.hammerspoon/wt_prune.lua` is a simpler direct consumer of `tmux_spawn` (no `tentacle.lua` indirection) — useful reference for a one-off handler.

`~/shell/common/git.zsh` — `_pr_prepare_slot`, `prr`, `prw`, `prf`, `prd`. The slot setup pattern for the PR review workflow. Model new shell launchers on these.

## Sharp edges & gotchas

- **Lua long-string `]]` collision.** If a DISPATCH builder embeds bash with awk regexes containing `]]` (e.g. `[^]]`), the default `[[ ... ]]` Lua delimiter terminates early with a misleading error near `'\'`. Use level-2 `[==[ ... ]==]` instead. `tmux_spawn.lua` already uses this delimiter; stay consistent.

- **tmux destroys a window when its process exits.** This is why `tmux_spawn` uses the create-then-send pattern: it creates a window with a shell, then sends the command as keystrokes into it. The shell keeps the window alive after the command finishes or errors. Never use `new-window --command <cmd>` for Claude sessions.

- **`new-window -d` does not steal focus.** The window is created in the background; `open -a Ghostty` + `switch-client` bring it forward. `switch-client` is a no-op if no client is currently attached to the session — the window still waits for the next attach.

- **tmux session created on demand.** `tmux_spawn` creates the session if it does not exist. No manual pre-creation step is needed.

- **tmux session names with spaces are fine.** `"pr reviews"` works. The engine uses `has-session -t "=$session"` (exact-match flag `=`) to avoid prefix collisions.

- **`switch-client` vs `select-window`.** `select-window` changes which window is active in the session. `switch-client` moves an attached client to a session. Both are best-effort (silent on failure).

- **First-click Chrome prompt.** First time a browser profile sees a `hammerspoon://` URL, Chrome shows a permission dialog. The "remember" checkbox sticks per-origin.

- **Window name truncation.** The tmux status bar truncates long window names. Put the most distinguishing info first — a mode emoji prefix (`🤖`, `🚶`, `💬`, `🚑`, etc.) survives truncation and reads at a glance.

- **`prompt` newlines.** `tentacle.lua` flattens `\r\n\t` to spaces before storing `parsed.prompt`. This prevents an embedded newline from prematurely submitting the tmux `send-keys` sequence.

- **`hs -c hs.reload()` "communication invalidated" warning.** Expected — happens because the CLI's port gets recycled mid-reload. Wait 1s, then verify with `hs -c "return 'ok'"`.

## Reference files

- **`examples/handler-template.lua`** — a DISPATCH-entry snippet showing the builder pattern. The old architecture used a standalone per-site handler file; that model no longer applies.
- **`examples/userscript-template.user.js`** — the Tampermonkey template from the old per-site architecture. The Tentacle extension supersedes per-site userscripts for new launchers; this file is kept as reference for the button-injection pattern and CSS constants only.
