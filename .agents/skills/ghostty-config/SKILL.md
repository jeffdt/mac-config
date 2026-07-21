---
name: ghostty-config
description: This skill should be used when the user asks to "configure ghostty", "change ghostty keybind", "add a keybind", "ghostty keyboard shortcut", "set ghostty theme", "change terminal font", "edit ghostty config", "list ghostty actions", "find ghostty themes", "validate ghostty config", "ghostty font rendering", or mentions Ghostty terminal configuration, keybindings, fonts, themes, or diagnostics.
---

# Ghostty Configuration

Manage and modify the Ghostty terminal emulator configuration with confidence by using
Ghostty's built-in discovery commands before making changes.

## Config File Location

On macOS, the config file lives at:

```
~/Library/Application Support/com.mitchellh.ghostty/config
```

The config format is `key = value`, one per line. Comments use `#`.

## Core Workflow: Discover Before Configuring

**Always verify before writing config.** Ghostty provides CLI discovery commands that
prevent guessing and mistakes. Follow this pattern:

1. **Discover** what's available using `ghostty +` commands
2. **Read** the current config file
3. **Edit** the config
4. **Validate** with `ghostty +validate-config`

Instruct the user to reload config with `cmd+shift+,` (`reload_config` keybind) after changes.

## Discovery Commands

### Keybinds

Before adding or changing a keybind:

```bash
# Check what a key is currently bound to
ghostty +list-keybinds --default | grep "super+shift+t"

# List all valid actions (ALWAYS do this before writing a keybind)
ghostty +list-actions

# Get documentation for all actions
ghostty +list-actions --docs
```

Keybind syntax in config: `keybind = <modifier>+<key>=<action>:<args>`

Modifiers: `super` (Cmd on macOS), `ctrl`, `alt`, `shift`. Chain with `+`.

### Config Options

```bash
# Browse ALL config options with full documentation
ghostty +show-config --default --docs

# See only what the user has changed from defaults
ghostty +show-config --changes-only

# Search for a specific option
ghostty +show-config --default --docs | grep -A5 "font-family"
```

### Themes

```bash
# Interactive theme preview (TUI)
ghostty +list-themes

# Plain list for scripting/searching
ghostty +list-themes --plain

# Filter by color scheme
ghostty +list-themes --plain --color=dark
ghostty +list-themes --plain --color=light

# Show file paths to theme files
ghostty +list-themes --plain --path
```

### Fonts

```bash
# List all available fonts
ghostty +list-fonts

# Filter to a specific family
ghostty +list-fonts --family="Hack Nerd Font"

# Check which font renders a specific character
ghostty +show-face --string="→"
```

### Validation

After editing config, validate before asking the user to reload:

```bash
ghostty +validate-config
```

Silent output means success. Errors print with line numbers.

## Common Tasks

### Adding a Keybind

1. Run `ghostty +list-actions` to confirm the action name exists
2. Run `ghostty +list-keybinds --default` to check if the key is already bound
3. Read the config file
4. Add the keybind line
5. Run `ghostty +validate-config`

### Changing Theme

1. Run `ghostty +list-themes --plain` to find available themes
2. Add `theme = <name>` to config (or `theme = dark:<name>,light:<name>` for auto-switching)

### Changing Font

1. Run `ghostty +list-fonts` to find available font families
2. Set `font-family = <name>` in config
3. Optional: set `font-family-bold`, `font-family-italic`, `font-family-bold-italic`

## Additional Resources

For the complete reference of all discovery commands and their flags, consult:
- **`references/discovery-commands.md`** — Full catalog of `ghostty +` commands with flags and examples
