#!/usr/bin/env python3
"""Claude Code status line script."""

import json
import os
import subprocess
import sys
import time

PR_CACHE = os.path.expanduser("~/.claude/cache/statusline-pr.json")
PR_TTL_SECONDS = 120


def refresh_pr_cache(repo_root, branch):
    """Look up the single open (draft or ready) PR for a branch and cache its URL."""
    result = subprocess.run(
        ["gh", "pr", "list", "--head", branch, "--state", "open",
         "--json", "number,url", "--limit", "2"],
        cwd=repo_root, capture_output=True, text=True, timeout=10,
    )
    if result.returncode != 0:
        return
    prs = json.loads(result.stdout)
    try:
        with open(PR_CACHE) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}
    cache[f"{repo_root}:{branch}"] = {
        "pr": prs[0] if len(prs) == 1 else None,
        "at": time.time(),
    }
    tmp = f"{PR_CACHE}.{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(cache, f)
    os.replace(tmp, PR_CACHE)


def cached_pr(repo_root, branch):
    """Return the cached PR for a branch, kicking off a background refresh when stale.

    gh takes ~0.5s, too slow for the statusline (the gateway wrapper kills it at 2s),
    so the lookup always runs detached and the next render picks up the result.
    """
    try:
        with open(PR_CACHE) as f:
            entry = json.load(f).get(f"{repo_root}:{branch}")
    except (OSError, ValueError):
        entry = None
    if not entry or time.time() - entry["at"] > PR_TTL_SECONDS:
        subprocess.Popen(
            [sys.executable, __file__, "--refresh-pr", repo_root, branch],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, start_new_session=True,
        )
    return entry["pr"] if entry else None


if len(sys.argv) == 4 and sys.argv[1] == "--refresh-pr":
    refresh_pr_cache(sys.argv[2], sys.argv[3])
    sys.exit(0)

# Optional work-only module (gitignored) that surfaces gateway-routed models
try:
    from statusline_routing import routed_model_id
except ImportError:
    routed_model_id = None

# Read JSON input from stdin
data = json.load(sys.stdin)

# Colors (Tomorrow Night palette, matches tmux/starship)
w = "\033[38;2;251;241;199m"  # white
g = "\033[38;2;181;189;104m"  # green
c = "\033[38;2;138;190;183m"  # cyan
d = "\033[38;2;100;100;100m"  # dim gray
red = "\033[38;2;204;102;102m"  # red
y = "\033[38;2;240;198;116m"  # yellow
r = "\033[0m"  # reset

# Base ANSI colors for the model segment, so it tracks the terminal theme
ansi_red = "\033[31m"
ansi_yellow = "\033[33m"
ansi_blue = "\033[34m"
ansi_magenta = "\033[35m"

# Matched as substrings against the model id and display name, first hit wins
MODEL_COLORS = (
    ("opus", ansi_red),
    ("sonnet", ansi_magenta),
    ("haiku", ansi_yellow),
    ("fable", ansi_blue),
)

# Nerd Font icons
icon_dir = "\uf413"  # nf-oct-file_directory
icon_branch = "⌥"  # nf-dev-git_branch
icon_tokens = "\U000f188f"  # nf-md-hand_coin
icon_worktree = "\uf1bb"  # nf-fa-tree
icon_model = "\U000f1719"  # nf-md-robot_outline

# Get directory name, detecting worktrees under {repo}/.worktrees/
cwd = data.get("workspace", {}).get("current_dir", "")
dir_name = os.path.basename(cwd)

# Check if cwd is inside a .worktrees directory
# Pattern: {repo}/.worktrees/{name} or {repo}/.worktrees/{name}/{subdir}
parts_path = cwd.split(os.sep)
if ".worktrees" in parts_path:
    wt_idx = parts_path.index(".worktrees")
    repo_name = parts_path[wt_idx - 1] if wt_idx > 0 else ""
    wt_name = (
        "/".join(parts_path[wt_idx + 1 : wt_idx + 2])
        if wt_idx + 1 < len(parts_path)
        else ""
    )
    if repo_name and wt_name:
        if len(wt_name) > 20:
            wt_name = wt_name[:17] + "..."
        dir_name = f"{repo_name} {y}{icon_worktree} {wt_name}{w}"

if len(dir_name) > 30 and ".worktrees" not in parts_path:
    dir_name = dir_name[:27] + "..."

# Get git branch (truncate if > 20 chars)
branch = ""
pr = None
try:
    result = subprocess.run(
        ["git", "-C", cwd, "rev-parse", "--show-toplevel", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
        timeout=1,
    )
    if result.returncode == 0:
        repo_root, full_branch = result.stdout.split()
        if full_branch != "HEAD":
            pr = cached_pr(repo_root, full_branch)
        branch = full_branch if full_branch != "HEAD" else ""
        if len(branch) > 20:
            branch = branch[:17] + "..."
except Exception:
    pass

# Calculate current context window usage (accurate percentage)
ctx = data.get("context_window", {})
pct = ctx.get("used_percentage") or 0

# Color: red at 90%+, otherwise cyan
tok_color = red if pct >= 90 else c
tok_display = f"{pct:.0f}%"

# Build output
# Format:  dir ·  branch ·  4k
parts = []

# Directory with symbol
parts.append(f"{w}{icon_dir} {dir_name}{r}")

# Branch with symbol (if in git repo)
if branch:
    parts.append(f"{d}·{r}")
    parts.append(f"{g}{icon_branch} {branch}{r}")

# Open PR for the branch, as a clickable OSC 8 link
if pr:
    link = f"\033]8;;{pr['url']}\033\\#{pr['number']}\033]8;;\033\\"
    parts.append(f"{d}·{r}")
    parts.append(f"{c}PR {link}{r}")

# Context usage with icon (red at 90%+)
parts.append(f"{d}·{r}")
parts.append(f"{tok_color}{icon_tokens} {tok_display}{r}")

# Model and reasoning effort level, colored per model family
model = data.get("model", {})
model_name = model.get("display_name", "")
routed = routed_model_id(data.get("transcript_path", "")) if routed_model_id else ""
if routed and routed != model.get("id", ""):
    model = {"id": routed}
    model_name = routed.removeprefix("claude-")
effort = data.get("effort", {}).get("level", "")
if model_name:
    haystack = f"{model.get('id', '')} {model_name}".lower()
    model_color = next(
        (color for key, color in MODEL_COLORS if key in haystack), ansi_red
    )
    model_display = f"{model_name} {effort}".rstrip()
    parts.append(f"{d}·{r}")
    parts.append(f"{model_color}{icon_model} {model_display}{r}")

# The gateway wrapper appends its quota segment to our last non-blank line. A
# reset-only second line counts as non-blank, which pushes that segment off line one.
print(" ".join(parts))
print(r)
