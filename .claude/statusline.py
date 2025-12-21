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
y = '\033[38;2;235;203;139m'    # Nord13 yellow
red = '\033[38;2;191;97;106m'   # Nord11 Aurora Red
r = '\033[0m'                   # reset

# Nerd Font icons
icon_dir = '\uf413'      # nf-oct-file_directory
icon_branch = '\ue725'   # nf-dev-git_branch
icon_tokens = '\U000f188f'   # nf-md-hand_coin

# Get directory name (truncate if > 20 chars)
cwd = data.get('workspace', {}).get('current_dir', '')
dir_name = os.path.basename(cwd)
if len(dir_name) > 20:
    dir_name = dir_name[:17] + '...'

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

# Get session name from transcript file
session_name = ''
transcript_path = data.get('transcript_path', '')
if transcript_path and os.path.isfile(transcript_path):
    try:
        with open(transcript_path, 'r') as f:
            # Check for custom-title (user renamed via /rename)
            custom_title = None
            for line in f:
                if '"type":"custom-title"' in line:
                    try:
                        obj = json.loads(line)
                        if obj.get('type') == 'custom-title':
                            custom_title = obj.get('customTitle', '')
                    except json.JSONDecodeError:
                        pass

            if custom_title:
                session_name = custom_title
            else:
                # Fall back to auto-generated summary (first line)
                f.seek(0)
                first_line = f.readline()
                try:
                    obj = json.loads(first_line)
                    if obj.get('type') == 'summary':
                        session_name = obj.get('summary', '')
                except json.JSONDecodeError:
                    pass
    except Exception:
        pass

# Truncate session name if too long (max 30 chars)
if len(session_name) > 30:
    session_name = session_name[:27] + '...'

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
# Format:  dir ·  branch ·  4k │ Session Name
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

# Session name at the end (with clear delimiter)
if session_name:
    parts.append(f'{d}│{r}')
    parts.append(f'{y}{session_name}{r}')

print(' '.join(parts))
