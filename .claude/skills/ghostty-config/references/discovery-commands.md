# Ghostty CLI Discovery Commands

Complete reference for Ghostty's `+` command family — introspection and discovery tools
available from the CLI.

## Configuration

### `ghostty +show-config`

Show current configuration (only values that differ from defaults).

| Flag | Purpose |
|---|---|
| `--default` | Show the full default config instead of user config |
| `--changes-only` | Only show options changed from default |
| `--docs` | Print documentation above each option as comments |

**Power combo:** `ghostty +show-config --default --docs` dumps all ~634 config lines with
full inline documentation. Best way to explore every available option.

### `ghostty +validate-config`

Validate the current config file (silent on success, prints errors on failure).

| Flag | Purpose |
|---|---|
| `--config-file=<path>` | Validate a specific config file instead of default |

### `ghostty +edit-config`

Open config file in `$VISUAL` or `$EDITOR`. Does NOT auto-reload after editing —
use `cmd+shift+,` (the `reload_config` keybind) to apply changes.

## Keybinds & Actions

### `ghostty +list-keybinds`

List active keybinds (user config merged with defaults).

| Flag | Purpose |
|---|---|
| `--default` | Show all default keybinds (ignoring user config) |
| `--plain` | Disable formatting for piping |

### `ghostty +list-actions`

List all available keybind actions (~83 total). These are the valid values for keybind
targets in config.

| Flag | Purpose |
|---|---|
| `--docs` | Print documentation for each action |

## Fonts

### `ghostty +list-fonts`

List all available fonts, sorted by family.

| Flag | Purpose |
|---|---|
| `--family=<name>` | Filter to a specific family (shows priority order) |
| `--bold` | Filter/prioritize bold styles |
| `--italic` | Filter/prioritize italic styles |
| `--style=<string>` | Filter by style string (e.g., "Heavy", "Light") |

### `ghostty +show-face`

Show which font face Ghostty would use for specific codepoints.

| Flag | Purpose |
|---|---|
| `--cp=<codepoint>` | Single codepoint (decimal, `0x` hex, `0o` octal, `0b` binary) |
| `--string=<text>` | All codepoints in a string |
| `--style=regular\|bold\|italic\|bold_italic` | Search for a specific style |
| `--presentation=text\|emoji` | Force a presentation style |

## Themes

### `ghostty +list-themes`

In a TTY: launches interactive TUI preview (F1 for help, ESC to exit).
When piped or with `--plain`: outputs a plain list of theme names.

Searches user themes (`~/.config/ghostty/themes`) and bundled resources.

| Flag | Purpose |
|---|---|
| `--plain` | Force plain text listing |
| `--path` | Show full filesystem path to each theme file |
| `--color=dark\|light\|all` | Filter by color scheme (default: `all`) |

## Colors

### `ghostty +list-colors`

List all named RGB colors Ghostty recognizes (X11 color names).

| Flag | Purpose |
|---|---|
| `--plain` | Disable formatting for piping |

## SSH & Diagnostics

### `ghostty +ssh-cache`

Manage the SSH terminfo cache (for `shell-integration-features = ssh-terminfo`).

| Flag | Purpose |
|---|---|
| (no args) | List all cached hosts |
| `--host=<hostname>` | Check if a host is cached |
| `--add=<hostname>` | Add a host |
| `--remove=<hostname>` | Remove a host |
| `--clear` | Clear entire cache |
| `--expire-days=<N>` | Set custom expiration period |

### `ghostty +crash-report`

List existing crash reports.

### `ghostty +version`

Print version, build channel, Zig version, build mode, font engine, renderer.

## Quick Reference

| Goal | Command |
|---|---|
| Browse all config options with docs | `ghostty +show-config --default --docs` |
| See what changed from defaults | `ghostty +show-config --changes-only` |
| Preview themes interactively | `ghostty +list-themes` |
| List dark themes | `ghostty +list-themes --plain --color=dark` |
| Find available fonts | `ghostty +list-fonts` |
| Debug font for a family | `ghostty +list-fonts --family="Fira Code"` |
| Check which font renders a char | `ghostty +show-face --string="→"` |
| See all actions with docs | `ghostty +list-actions --docs` |
| See current keybinds | `ghostty +list-keybinds` |
| Validate config | `ghostty +validate-config` |
