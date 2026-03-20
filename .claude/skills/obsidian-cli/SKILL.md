---
name: obsidian-cli
description: This skill should be used when interacting with Obsidian vaults from the terminal, including "read a note", "search my vault", "find notes", "append to daily note", "add to my daily note", "create a note", "list tasks", "check tags", "search obsidian", "check backlinks", "find orphaned notes", "open a note", or any task involving the `obsidian` CLI command. Also triggers on references to Obsidian notes, daily notes, or vault content when a CLI operation is implied.
---

# Obsidian CLI

The Obsidian CLI ships with Obsidian v1.12.4+. It communicates with the running Obsidian app — Obsidian must be open in the background for commands to work.

## Syntax Conventions

```
obsidian <command> [key=value ...] [flags]
```

- **`file=<name>`** — Resolve by name (like wikilinks). Use for note titles.
- **`path=<path>`** — Exact path relative to vault root (e.g., `folder/note.md`).
- **`vault=<name>`** — Target a specific vault (omit to use the active vault).
- **Flags** — Boolean options with no value (e.g., `total`, `verbose`, `inline`).
- **Quoting** — Quote values with spaces: `name="My Note"`.
- **Escapes** — Use `\n` for newline, `\t` for tab in content values.
- **Formats** — Many commands accept `format=json|tsv|csv` (default varies).
- **Defaults** — Most commands default to the active file when file/path is omitted.

## Command Inventory

### Vault & Files
| Command | Purpose |
|---------|---------|
| `vault` | Show vault info (name, path, file/folder count, size) |
| `vaults` | List known vaults |
| `files` | List files (filter by folder, extension) |
| `file` | Show file info |
| `folders` | List folders |
| `folder` | Show folder info |
| `create` | Create a new file (with optional template, content) |
| `read` | Read file contents |
| `append` | Append content to a file |
| `prepend` | Prepend content to a file |
| `delete` | Delete a file (trash or permanent) |
| `move` | Move a file to a new location |
| `rename` | Rename a file |
| `open` | Open a file in Obsidian |

### Daily Notes
| Command | Purpose |
|---------|---------|
| `daily` | Open today's daily note |
| `daily:read` | Read daily note contents |
| `daily:path` | Get daily note file path |
| `daily:append` | Append content to daily note |
| `daily:prepend` | Prepend content to daily note |

### Search
| Command | Purpose |
|---------|---------|
| `search` | Search vault text (returns file matches) |
| `search:context` | Search with surrounding line context |
| `search:open` | Open search view in Obsidian UI |

### Tags & Properties
| Command | Purpose |
|---------|---------|
| `tags` | List tags (vault-wide or per-file, with counts) |
| `tag` | Get info for a specific tag |
| `properties` | List frontmatter properties |
| `property:read` | Read a property value from a file |
| `property:set` | Set a property on a file |
| `property:remove` | Remove a property from a file |

### Tasks
| Command | Purpose |
|---------|---------|
| `tasks` | List tasks (filter: done, todo, by file, daily note) |
| `task` | Show/update a task (toggle, done, todo, set status) |

### Links & Graph
| Command | Purpose |
|---------|---------|
| `links` | List outgoing links from a file |
| `backlinks` | List backlinks to a file |
| `aliases` | List aliases |
| `orphans` | Files with no incoming links |
| `deadends` | Files with no outgoing links |
| `unresolved` | Unresolved/broken links |

### Templates
| Command | Purpose |
|---------|---------|
| `templates` | List available templates |
| `template:read` | Read template content (optionally resolve variables) |
| `template:insert` | Insert template into active file |

### Bookmarks
| Command | Purpose |
|---------|---------|
| `bookmark` | Add a bookmark (file, folder, search, URL) |
| `bookmarks` | List bookmarks |

### Bases (Databases)
| Command | Purpose |
|---------|---------|
| `bases` | List base files |
| `base:query` | Query a base view (json, csv, tsv, md, paths) |
| `base:create` | Create a new item in a base |
| `base:views` | List views in a base |

### Plugins & Themes
| Command | Purpose |
|---------|---------|
| `plugins` | List installed plugins |
| `plugin:enable` / `plugin:disable` | Toggle a plugin |
| `plugin:install` / `plugin:uninstall` | Install/remove community plugins |
| `themes` / `theme:set` / `theme:install` | Manage themes |
| `snippets` / `snippet:enable` | Manage CSS snippets |

### Navigation & UI
| Command | Purpose |
|---------|---------|
| `tabs` | List open tabs |
| `tab:open` | Open a new tab |
| `workspace` | Show workspace tree |
| `recents` | Recently opened files |
| `random` | Open a random note |
| `command` | Execute any Obsidian command by ID |
| `commands` | List available command IDs |

### History & Versions
| Command | Purpose |
|---------|---------|
| `history` | List file history versions |
| `history:read` | Read a specific version |
| `history:restore` | Restore a version |
| `diff` | Diff local/sync versions |

### Utility
| Command | Purpose |
|---------|---------|
| `outline` | Show headings (tree, md, json) |
| `wordcount` | Count words/characters |
| `version` | Show Obsidian version |
| `reload` | Reload the vault |
| `eval` | Execute JavaScript in Obsidian |

## Common Recipes

### Daily Notes & Capture

```bash
# Read today's daily note
obsidian daily:read

# Quick-capture a thought to today's daily note
obsidian daily:append content="- Meeting with design team at 3pm"

# Prepend a priority item
obsidian daily:prepend content="## Top Priority\nFinish Q1 review"

# Check today's tasks
obsidian tasks daily todo
```

### Search & Read

```bash
# Full-text search across the vault
obsidian search query="project kickoff"

# Search with surrounding context lines
obsidian search:context query="API design" path="Engineering"

# Search and get just the match count
obsidian search query="TODO" total

# Read a specific note by name (wikilink-style)
obsidian read file="Meeting Notes"

# Read by exact path
obsidian read path="Projects/Q1/roadmap.md"
```

### Quick Note Creation

```bash
# Create a note with content
obsidian create name="Standup Notes" content="## 2026-03-05\n- Updates here"

# Create from a template
obsidian create name="New Project Brief" template="Project Template"

# Create and open in Obsidian
obsidian create name="Draft" content="Starting point" open
```

### Tags & Properties

```bash
# List all tags with counts, sorted by frequency
obsidian tags counts sort=count

# See which files use a tag
obsidian tag name="project/active" verbose

# Read a frontmatter property
obsidian property:read name="status" file="Project X"

# Set a property
obsidian property:set name="status" value="in-progress" file="Project X"
```

### Vault Health

```bash
# Find orphaned notes (no incoming links)
obsidian orphans

# Find broken/unresolved links
obsidian unresolved verbose

# Find dead-end notes (no outgoing links)
obsidian deadends
```

## Important Notes

- Obsidian must be running in the background for the CLI to work.
- The `file=` parameter resolves names like wikilinks (partial matches work). Use `path=` for exact paths.
- Ignore the loading/version preamble line in CLI output when parsing results.
- "Active file" means whatever is currently focused in the Obsidian UI.
- For full flag-level details on any command, run `obsidian help <command>` or consult `references/command-reference.md`.
