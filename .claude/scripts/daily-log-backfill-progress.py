#!/usr/bin/env python3
"""
Filter for `claude -p --output-format stream-json --verbose` output.

Reads JSON-line events from stdin. Writes every raw line verbatim to the
logfile passed as argv[1]. Prints a friendly per-event progress summary to
stdout for terminal consumption.

Usage:
  claude -p ... --verbose --output-format stream-json | progress.py LOGFILE
"""
from __future__ import annotations

import json
import os
import signal
import sys
import time

signal.signal(signal.SIGPIPE, signal.SIG_DFL)


MAX_DESC = 90
MAX_TEXT = 120


def truncate(s: str, n: int) -> str:
    s = (s or "").replace("\n", " ").strip()
    if len(s) > n:
        return s[: n - 1] + "…"
    return s


def short_id(toolu_id: str) -> str:
    if not toolu_id:
        return "????"
    return toolu_id.split("_")[-1][-4:]


def render(evt: dict) -> str | None:
    """Return a single human-friendly line for this event, or None to skip."""
    ts = time.strftime("%H:%M:%S")
    etype = evt.get("type")
    parent_id = evt.get("parent_tool_use_id")
    tag = "  sub" if parent_id else "main"

    if etype == "system":
        subtype = evt.get("subtype")
        if subtype == "init":
            model = evt.get("model", "?")
            return f"[{ts}] [{tag}] init: model={model}"
        return None  # skip hook_started, hook_response

    if etype == "assistant":
        msg = evt.get("message", {})
        lines = []
        for block in msg.get("content", []):
            btype = block.get("type")
            if btype == "tool_use":
                name = block.get("name", "?")
                inp = block.get("input") or {}
                if name == "Write":
                    fp = inp.get("file_path", "")
                    base = os.path.basename(fp)
                    lines.append(f"[{ts}] [{tag}] write: {base}")
                elif name == "Edit":
                    fp = inp.get("file_path", "")
                    base = os.path.basename(fp)
                    lines.append(f"[{ts}] [{tag}] edit: {base}")
                elif name == "Task":
                    sub = inp.get("subagent_type", "?")
                    desc = truncate(inp.get("description", ""), 60)
                    lines.append(f"[{ts}] [{tag}] spawn: {sub} ({desc})")
                elif name == "Bash":
                    desc = truncate(inp.get("description") or inp.get("command", ""), MAX_DESC)
                    lines.append(f"[{ts}] [{tag}] bash: {desc}")
                elif name == "TodoWrite":
                    todos = inp.get("todos", [])
                    lines.append(f"[{ts}] [{tag}] todos: {len(todos)} items")
                elif name.startswith("mcp__"):
                    short = name.split("__", 2)[-1]
                    lines.append(f"[{ts}] [{tag}] mcp: {short}")
                else:
                    desc = truncate(
                        inp.get("description") or inp.get("file_path") or inp.get("prompt") or "",
                        MAX_DESC,
                    )
                    suffix = f" ({desc})" if desc else ""
                    lines.append(f"[{ts}] [{tag}] tool: {name}{suffix}")
            elif btype == "text":
                text = (block.get("text") or "").strip()
                if text:
                    lines.append(f"[{ts}] [{tag}] say: {truncate(text, MAX_TEXT)}")
            # skip 'thinking' blocks
        return "\n".join(lines) if lines else None

    if etype == "user":
        msg = evt.get("message", {})
        for block in msg.get("content", []):
            if block.get("type") != "tool_result":
                continue
            result = block.get("content", "")
            if isinstance(result, list):
                result = " ".join(
                    b.get("text", "") for b in result if isinstance(b, dict) and b.get("type") == "text"
                )
            if not isinstance(result, str):
                continue
            is_error = block.get("is_error") or "Error" in result[:200] or "error:" in result[:200].lower()
            if is_error:
                return f"[{ts}] [{tag}] !err: {truncate(result, MAX_TEXT)}"
        return None

    if etype == "result":
        subtype = evt.get("subtype", "")
        is_error = evt.get("is_error", False)
        duration_ms = evt.get("duration_ms", 0)
        secs = duration_ms / 1000 if duration_ms else 0
        if is_error:
            return f"[{ts}] [main] FAILED ({subtype}, {secs:.0f}s)"
        return f"[{ts}] [main] done ({secs:.0f}s)"

    return None


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: daily-log-backfill-progress.py LOGFILE", file=sys.stderr)
        return 2
    logpath = sys.argv[1]

    with open(logpath, "a", encoding="utf-8") as logf:
        for line in sys.stdin:
            logf.write(line)
            logf.flush()

            stripped = line.strip()
            if not stripped:
                continue
            try:
                evt = json.loads(stripped)
            except json.JSONDecodeError:
                # Non-JSON line (maybe a stderr message) — surface it raw.
                print(f"[{time.strftime('%H:%M:%S')}] [raw] {truncate(stripped, MAX_TEXT)}", flush=True)
                continue

            out = render(evt)
            if out:
                print(out, flush=True)

    return 0


if __name__ == "__main__":
    sys.exit(main())
