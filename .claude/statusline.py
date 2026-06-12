#!/usr/bin/env python3
"""Claude Code status line script."""

import json
import os
import subprocess
import sys

# Read JSON input from stdin
data = json.load(sys.stdin)

# Colors (Nord-ish palette)
w = '\033[38;2;251;241;199m'    # warm white
g = '\033[38;2;163;190;140m'    # Nord14 green
c = '\033[38;2;136;192;208m'    # Nord8 cyan
d = '\033[38;2;100;100;100m'    # dim gray
red = '\033[38;2;191;97;106m'   # Nord11 Aurora Red
y = '\033[38;2;235;203;139m'    # Nord13 yellow
r = '\033[0m'                   # reset

# Nerd Font icons
icon_dir = '\uf413'      # nf-oct-file_directory
icon_branch = '\ue725'   # nf-dev-git_branch
icon_tokens = '\U000f188f'   # nf-md-hand_coin
icon_worktree = '\uf1bb'     # nf-fa-tree

# Get directory name, detecting worktrees under {repo}/.worktrees/
cwd = data.get('workspace', {}).get('current_dir', '')
dir_name = os.path.basename(cwd)

# Check if cwd is inside a .worktrees directory
# Pattern: {repo}/.worktrees/{name} or {repo}/.worktrees/{name}/{subdir}
parts_path = cwd.split(os.sep)
if '.worktrees' in parts_path:
    wt_idx = parts_path.index('.worktrees')
    repo_name = parts_path[wt_idx - 1] if wt_idx > 0 else ''
    wt_name = '/'.join(parts_path[wt_idx + 1:wt_idx + 2]) if wt_idx + 1 < len(parts_path) else ''
    if repo_name and wt_name:
        if len(wt_name) > 20:
            wt_name = wt_name[:17] + '...'
        dir_name = f'{repo_name} {y}{icon_worktree} {wt_name}{w}'

if len(dir_name) > 30 and '.worktrees' not in parts_path:
    dir_name = dir_name[:27] + '...'

# Get git branch (truncate if > 20 chars)
branch = ''
try:
    result = subprocess.run(
        ['git', '-C', cwd, 'branch', '--show-current'],
        capture_output=True, text=True, timeout=1
    )
    if result.returncode == 0:
        branch = result.stdout.strip()
        if len(branch) > 20:
            branch = branch[:17] + '...'
except Exception:
    pass

# Calculate current context window usage (accurate percentage)
ctx = data.get('context_window', {})
current_usage = ctx.get('current_usage', {})
context_size = ctx.get('context_window_size', 200000)

# Sum current usage tokens
in_tok = current_usage.get('input_tokens', 0) or 0
out_tok = current_usage.get('output_tokens', 0) or 0
cache_create = current_usage.get('cache_creation_input_tokens', 0) or 0
cache_read = current_usage.get('cache_read_input_tokens', 0) or 0
current_tokens = in_tok + out_tok + cache_create + cache_read

# Calculate percentage and determine color
if context_size > 0:
    pct = (current_tokens * 100) / context_size
else:
    pct = 0

# Color: red at 90%+, otherwise cyan
tok_color = red if pct >= 90 else c
tok_display = f'{pct:.1f}%'

# Build output
# Format:  dir ·  branch ·  4k
parts = []

# Directory with symbol
parts.append(f'{w}{icon_dir} {dir_name}{r}')

# Branch with symbol (if in git repo)
if branch:
    parts.append(f'{d}·{r}')
    parts.append(f'{g}{icon_branch} {branch}{r}')

# Context usage with icon (red at 90%+)
parts.append(f'{d}·{r}')
parts.append(f'{tok_color}{icon_tokens} {tok_display}{r}')

print(' '.join(parts))
