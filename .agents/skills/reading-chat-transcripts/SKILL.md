---
name: reading-chat-transcripts
description: "Use when you need to locate and read ANOTHER session's transcript (Claude Code or pi) to verify or recover what it actually did: a coordinator checking a spawned/closed execution session's real output, auditing a subagent's reported result against its transcript, or recovering something a closed session said that wasn't captured anywhere else (e.g. \"what did that pi session actually verify post-merge\"). Triggers include \"check the transcript for session X\", \"what did that other session do\", \"find the pi/claude session for this worktree\", \"did the subagent actually run that command\", or any request to cross-check a report against the raw conversation log. Not for reading your OWN current conversation; only for another session's history on disk."
---

# Reading Chat Transcripts

Locate and read another session's on-disk transcript (Claude Code or pi) to verify what it actually said or did, rather than trusting a summary secondhand. This matters most when a coordinator spawned a session that closed before reporting fully, or when a subagent's claimed result needs an independent check against the real log.

Storage layouts drift across runtime versions; the paths below are current as of mid-2026 but **list the directory to confirm structure before trusting it**, don't hardcode blind.

## Where transcripts live

**Claude Code:**
```
~/.claude/projects/<cwd-with-slashes-as-hyphens>/<session-uuid>.jsonl
```
e.g. `/Users/jeff/Klaviyo/projects/pi` becomes `~/.claude/projects/-Users-jeff-Klaviyo-projects-pi/`.

**pi:**
```
~/.pi/agent/sessions/--<cwd-encoded-with-double-dash-delims>--/<ISO-timestamp>_<uuid>.jsonl
```
Nested per-run files (subagent delegate calls) sit under:
```
.../--<cwd>--/<ISO-timestamp>_<uuid>/<hash>/run-N/session.jsonl
```
A global index of subagent runs (task text, status, duration, no full content) lives at `~/.pi/agent/run-history.jsonl`, one JSON object per line.

The pi session dir name encodes the worktree path, so when the cwd alone is ambiguous (multiple worktrees of the same repo), match on the worktree/branch suffix baked into the dir name, e.g. `--Users-jeff.diteodoro-Klaviyo-Repos-infrastructure-deployment.jeffdt-data-residency-amplify-success-qw-role--`.

## Finding the right file

```bash
# Newest session for a cwd/repo (both runtimes):
ls -dt ~/.claude/projects/*<repo-or-path-fragment>*/ | head -1
ls -dt ~/.pi/agent/sessions/*<repo-or-path-fragment>*/ | head -1

# Newest transcript file inside it:
ls -t ~/.claude/projects/<matched-dir>/*.jsonl | head -1
ls -t ~/.pi/agent/sessions/<matched-dir>/*.jsonl | head -1   # top-level session
find ~/.pi/agent/sessions/<matched-dir> -name session.jsonl  # nested subagent runs
```

If you know the branch or worktree name but not the exact cwd, grep the dir names for it; that's usually faster than reasoning about path-encoding rules.

## Reading safely

Transcripts are JSONL: one event per line, and lines can be enormous (tool results, full file contents, etc). **Never `cat`, `Read`, or otherwise dump a whole transcript into context**; filter first. Roles/event shapes vary between runtimes and even between versions of the same runtime:

- Claude Code: each line has `type`, and turn events have `message: {role, content}`. `content` is either a plain string or a list of blocks like `{"type": "text", "text": "..."}` (also `"thinking"`, `"tool_use"`, `"tool_result"`).
- pi: each line has `type`, `id`, `parentId`, and for turns a `message: {role, content, ...}`. `content` is a list of blocks (`"text"`, `"thinking"`, `"toolCall"`, ...); top-level session metadata lines (`type: "session"`, permission-mode changes, snapshots) have no `message` at all.

A keyword-filtered extraction handles both shapes. Adapt the keyword and path, but keep the "only print matching assistant text" behavior:

```python
import json, sys

path = sys.argv[1]
keyword = sys.argv[2].lower()

with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg = obj.get("message")
        if not isinstance(msg, dict) or msg.get("role") != "assistant":
            continue

        content = msg.get("content")
        blocks = content if isinstance(content, list) else [{"type": "text", "text": content}]

        for block in blocks:
            if not isinstance(block, dict) or block.get("type") != "text":
                continue
            text = block.get("text", "")
            if keyword in text.lower():
                print(text)
                print("---")
```

Run it with `python3 extract.py <transcript.jsonl> "<keyword>"`. For a first pass over an unfamiliar transcript, `grep -c '"role":"assistant"' <file>` or `grep -o '"type":"[a-z_]*"' <file> | sort -u` is a cheap way to see what event types exist before writing a filter.

## Caveats

- **Layouts change across runtime versions.** Always `ls` the directory structure to confirm before relying on a hardcoded path; this skill records what worked as of mid-2026, not a permanent contract.
- **Reading a full transcript into context is a hazard**, not just slow: lines can be single tool results tens of thousands of tokens long. Always extract with grep or a keyword filter, never load the raw file.
- **The nested pi run dirs are per-delegate-call**, not per top-level session. If the top-level `.jsonl` doesn't have what you need, it's likely in a `run-N/session.jsonl` under a subagent's hash dir, not missing entirely.
