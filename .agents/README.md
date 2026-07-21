# Agent resources

This directory is the canonical source for global agent resources that are shared across harnesses.

Edit files here, then run:

```bash
agents-publish
```

The publisher validates sources, writes target files atomically, and records generated files in `.publish-manifest.json` so stale generated files can be pruned safely. A user LaunchAgent (`~/Library/LaunchAgents/com.jeff.agents-publish.plist`) runs the publisher on login and whenever source directories change.

## Canonical sources

- `skills/`: Agent Skills standard skills. Pi reads this directory directly, and the publisher also renders Claude copies.
- `agents/`: Source agent prompts. The publisher renders Claude agents and Pi subagents from these files.
- `agent-prompts/`: Shared prompt fragments used by agents.
- `scripts/`: Shared helper scripts used by skills and agents.

## Generated targets

- `~/.claude/skills/`
- `~/.claude/agents/`
- `~/.claude/agent-prompts/`
- `~/.claude/scripts/`
- `~/.pi/agent/agents/generated/`

Do not edit generated target files directly. They will be overwritten by the next publish.

## Commands

```bash
agents-publish --check     # validate canonical sources
agents-publish --dry-run   # show publish counts without writing
agents-publish             # publish to Claude and Pi
```

## LaunchAgent

```bash
launchctl print gui/$(id -u)/com.jeff.agents-publish
launchctl kickstart -k gui/$(id -u)/com.jeff.agents-publish
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.jeff.agents-publish.plist
```

Logs live at:

- `~/.agents/.publish.launchd.log`
- `~/.agents/.publish.launchd.err`
