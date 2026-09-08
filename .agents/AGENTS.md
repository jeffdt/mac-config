# Working in this repo

This is the canonical source for global agent resources shared across harnesses (Claude Code, Pi). See `README.md` for the publish/generated-target model; this file is about conventions for editing sources here.

## Layout

- `skills/<name>/SKILL.md`: Agent Skills standard, frontmatter with `name`, `version` (bump on meaningful edits), `description`. Description drives skill-triggering, so write it as trigger phrases and conditions, not a summary.
- `workflows/<name>.md`: Canonical manual workflow aliases. Frontmatter declares the generated Claude command path and the core skill; the body contains portable sequencing instructions.
- `skills/<workflow-name>/SKILL.md`: Generated Codex wrapper for a workflow. Do not edit it; edit `workflows/<workflow-name>.md` and publish.
- YAML frontmatter: write freeform string values, especially `description`, as double-quoted scalars and escape embedded double quotes as `\"`. An unquoted `: ` starts a YAML mapping and prevents Pi from loading the skill.
- `agents/<name>.md`: source agent prompts, published as both Claude agents and Pi subagents.
- `agent-prompts/<agent>/*.md`: shared prompt fragments referenced by an agent (e.g. `agent-prompts/pr-review/`).
- `scripts/`: helper scripts used by skills and agents.

## Workflow

- After editing any source file, run `agents-publish --check` to validate, `--dry-run` to preview, then `agents-publish` to write generated targets.
- Never hand-edit generated targets (`~/.claude/skills/`, `~/.claude/commands/` entries owned by this publisher, `~/.claude/agents/`, `~/.claude/agent-prompts/`, `~/.claude/scripts/`, `~/.pi/agent/agents/generated/`); the next publish overwrites them.
- A LaunchAgent republishes automatically on login and on source changes, so a missed manual publish is usually self-healing, but run it manually when you need the change live immediately.
- Brainstorming specs go in `./specs/`, implementation plans in `./plans/` (both gitignored, not committed).
- This repo has no `.git` of its own. Commit source changes through the `config` shell alias (`git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`), which tracks files across the whole home directory. Stage exact paths only (e.g. `config add .agents/skills/foo/SKILL.md`) — never `-A` or `.` — since the same work-tree covers unrelated in-progress changes elsewhere in `$HOME`.

## Scope note

This file only orients sessions working inside this repo. It is not a publish source, `agents-publish` doesn't read or generate `AGENTS.md`/`CLAUDE.md` files, so nothing here propagates to other repos or to the global `~/.claude/CLAUDE.md`.
