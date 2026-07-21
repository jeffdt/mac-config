# Obsidian CLI Full Command Reference

Full flag-level reference for all Obsidian CLI commands, providing detail beyond what the SKILL.md command inventory covers.

> To get the latest help for any command: `obsidian help <command>`

## Vault & File Management

### vault
Show vault info.
```
obsidian vault [info=name|path|files|folders|size]
```

### vaults
List known vaults.
```
obsidian vaults [total] [verbose]
```
- `verbose` — include vault paths

### files
List files in the vault.
```
obsidian files [folder=<path>] [ext=<extension>] [total]
```

### file
Show file info.
```
obsidian file [file=<name>] [path=<path>]
```

### folders
List folders in the vault.
```
obsidian folders [folder=<path>] [total]
```

### folder
Show folder info.
```
obsidian folder path=<path> [info=files|folders|size]
```

### create
Create a new file.
```
obsidian create [name=<name>] [path=<path>] [content=<text>] [template=<name>] [overwrite] [open] [newtab]
```

### read
Read file contents.
```
obsidian read [file=<name>] [path=<path>]
```

### append
Append content to a file.
```
obsidian append [file=<name>] [path=<path>] content=<text> [inline]
```
- `inline` — append without newline

### prepend
Prepend content to a file.
```
obsidian prepend [file=<name>] [path=<path>] content=<text> [inline]
```

### delete
Delete a file.
```
obsidian delete [file=<name>] [path=<path>] [permanent]
```
- `permanent` — skip trash, delete permanently

### move
Move or rename a file.
```
obsidian move [file=<name>] [path=<path>] to=<path>
```

### rename
Rename a file.
```
obsidian rename [file=<name>] [path=<path>] name=<name>
```

### open
Open a file in Obsidian.
```
obsidian open [file=<name>] [path=<path>] [newtab]
```

### reload
Reload the vault.
```
obsidian reload
```

## Daily Notes

### daily
Open daily note.
```
obsidian daily [paneType=tab|split|window]
```

### daily:read
Read daily note contents.
```
obsidian daily:read
```

### daily:path
Get daily note path.
```
obsidian daily:path
```

### daily:append
Append content to daily note.
```
obsidian daily:append content=<text> [inline] [open] [paneType=tab|split|window]
```

### daily:prepend
Prepend content to daily note.
```
obsidian daily:prepend content=<text> [inline] [open] [paneType=tab|split|window]
```

## Search

### search
Search vault for text.
```
obsidian search query=<text> [path=<folder>] [limit=<n>] [total] [case] [format=text|json]
```

### search:context
Search with matching line context.
```
obsidian search:context query=<text> [path=<folder>] [limit=<n>] [case] [format=text|json]
```

### search:open
Open search view in Obsidian.
```
obsidian search:open [query=<text>]
```

## Tags

### tags
List tags in the vault.
```
obsidian tags [file=<name>] [path=<path>] [total] [counts] [sort=count] [format=json|tsv|csv] [active]
```

### tag
Get tag info.
```
obsidian tag name=<tag> [total] [verbose]
```
- `verbose` — include file list and count

## Properties (Frontmatter)

### properties
List properties in the vault.
```
obsidian properties [file=<name>] [path=<path>] [name=<name>] [total] [sort=count] [counts] [format=yaml|json|tsv] [active]
```

### property:read
Read a property value from a file.
```
obsidian property:read name=<name> [file=<name>] [path=<path>]
```

### property:set
Set a property on a file.
```
obsidian property:set name=<name> value=<value> [type=text|list|number|checkbox|date|datetime] [file=<name>] [path=<path>]
```

### property:remove
Remove a property from a file.
```
obsidian property:remove name=<name> [file=<name>] [path=<path>]
```

## Tasks

### tasks
List tasks in the vault.
```
obsidian tasks [file=<name>] [path=<path>] [total] [done] [todo] [status="<char>"] [verbose] [format=json|tsv|csv] [active] [daily]
```
- `verbose` — group by file with line numbers
- `daily` — show tasks from daily note

### task
Show or update a task.
```
obsidian task [ref=<path:line>] [file=<name>] [path=<path>] [line=<n>] [toggle] [done] [todo] [daily] [status="<char>"]
```

## Links & Graph

### links
List outgoing links from a file.
```
obsidian links [file=<name>] [path=<path>] [total]
```

### backlinks
List backlinks to a file.
```
obsidian backlinks [file=<name>] [path=<path>] [counts] [total] [format=json|tsv|csv]
```

### aliases
List aliases in the vault.
```
obsidian aliases [file=<name>] [path=<path>] [total] [verbose] [active]
```

### orphans
List files with no incoming links.
```
obsidian orphans [total] [all]
```

### deadends
List files with no outgoing links.
```
obsidian deadends [total] [all]
```

### unresolved
List unresolved links in vault.
```
obsidian unresolved [total] [counts] [verbose] [format=json|tsv|csv]
```

## Bookmarks

### bookmark
Add a bookmark.
```
obsidian bookmark [file=<path>] [subpath=<subpath>] [folder=<path>] [search=<query>] [url=<url>] [title=<title>]
```

### bookmarks
List bookmarks.
```
obsidian bookmarks [total] [verbose] [format=json|tsv|csv]
```

## Templates

### templates
List templates.
```
obsidian templates [total]
```

### template:insert
Insert template into active file.
```
obsidian template:insert name=<template>
```

### template:read
Read template content.
```
obsidian template:read name=<template> [resolve] [title=<title>]
```

## Plugins

### plugins
List installed plugins.
```
obsidian plugins [filter=core|community] [versions] [format=json|tsv|csv]
```

### plugins:enabled
List enabled plugins.
```
obsidian plugins:enabled [filter=core|community] [versions] [format=json|tsv|csv]
```

### plugin
Get plugin info.
```
obsidian plugin id=<plugin-id>
```

### plugin:enable / plugin:disable
```
obsidian plugin:enable id=<id> [filter=core|community]
obsidian plugin:disable id=<id> [filter=core|community]
```

### plugin:install / plugin:uninstall
```
obsidian plugin:install id=<id> [enable]
obsidian plugin:uninstall id=<id>
```

### plugin:reload
Reload a plugin (for developers).
```
obsidian plugin:reload id=<id>
```

### plugins:restrict
Toggle or check restricted mode.
```
obsidian plugins:restrict [on] [off]
```

## Bases

### bases
List all base files in vault.
```
obsidian bases
```

### base:views
List views in the current base file.
```
obsidian base:views
```

### base:query
Query a base and return results.
```
obsidian base:query [file=<name>] [path=<path>] [view=<name>] [format=json|csv|tsv|md|paths]
```

### base:create
Create a new item in a base.
```
obsidian base:create [file=<name>] [path=<path>] [view=<name>] [name=<name>] [content=<text>] [open] [newtab]
```

## History & Versions

### history
List file history versions.
```
obsidian history [file=<name>] [path=<path>]
```

### history:list
List files with history.
```
obsidian history:list
```

### history:read
Read a file history version.
```
obsidian history:read [file=<name>] [path=<path>] [version=<n>]
```

### history:restore
Restore a file history version.
```
obsidian history:restore [file=<name>] [path=<path>] version=<n>
```

### diff
List or diff local/sync versions.
```
obsidian diff [file=<name>] [path=<path>] [from=<n>] [to=<n>] [filter=local|sync]
```

## Commands & Hotkeys

### commands
List available command IDs.
```
obsidian commands [filter=<prefix>]
```

### command
Execute an Obsidian command.
```
obsidian command id=<command-id>
```

### hotkeys
List hotkeys.
```
obsidian hotkeys [total] [verbose] [format=json|tsv|csv] [all]
```

### hotkey
Get hotkey for a command.
```
obsidian hotkey id=<command-id> [verbose]
```

## Themes & Snippets

### themes
List installed themes.
```
obsidian themes [versions]
```

### theme
Show active theme or get info.
```
obsidian theme [name=<name>]
```

### theme:set / theme:install / theme:uninstall
```
obsidian theme:set name=<name>
obsidian theme:install name=<name> [enable]
obsidian theme:uninstall name=<name>
```

### snippets / snippets:enabled
```
obsidian snippets
obsidian snippets:enabled
```

### snippet:enable / snippet:disable
```
obsidian snippet:enable name=<name>
obsidian snippet:disable name=<name>
```

## Tabs & Workspace

### tabs
List open tabs.
```
obsidian tabs [ids]
```

### tab:open
Open a new tab.
```
obsidian tab:open [group=<id>] [file=<path>] [view=<type>]
```

### workspace
Show workspace tree.
```
obsidian workspace [ids]
```

### recents
List recently opened files.
```
obsidian recents [total]
```

### random / random:read
Open or read a random note.
```
obsidian random [folder=<path>] [newtab]
obsidian random:read [folder=<path>]
```

## Outline & Word Count

### outline
Show headings for a file.
```
obsidian outline [file=<name>] [path=<path>] [format=tree|md|json] [total]
```

### wordcount
Count words and characters.
```
obsidian wordcount [file=<name>] [path=<path>] [words] [characters]
```

## Developer Commands

### eval
Execute JavaScript and return result.
```
obsidian eval code=<javascript>
```

### devtools
Toggle Electron dev tools.
```
obsidian devtools
```

### dev:dom
Query DOM elements.
```
obsidian dev:dom selector=<css> [total] [text] [inner] [all] [attr=<name>] [css=<prop>]
```

### dev:css
Inspect CSS with source locations.
```
obsidian dev:css selector=<css> [prop=<name>]
```

### dev:console
Show captured console messages.
```
obsidian dev:console [clear] [limit=<n>] [level=log|warn|error|info|debug]
```

### dev:errors
Show captured errors.
```
obsidian dev:errors [clear]
```

### dev:screenshot
Take a screenshot.
```
obsidian dev:screenshot [path=<filename>]
```

### dev:cdp
Run a Chrome DevTools Protocol command.
```
obsidian dev:cdp method=<CDP.method> [params=<json>]
```

### dev:debug
Attach/detach Chrome DevTools Protocol debugger.
```
obsidian dev:debug [on] [off]
```

### dev:mobile
Toggle mobile emulation.
```
obsidian dev:mobile [on] [off]
```

## System

### version
Show Obsidian version.
```
obsidian version
```

### restart
Restart the app.
```
obsidian restart
```
