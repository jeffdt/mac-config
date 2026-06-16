#!/bin/bash
# Claude Code status line script

input=$(cat)

# Extract values from JSON input
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

# Colors (Nord-ish palette)
w='\033[38;2;251;241;199m'    # warm white
g='\033[38;2;163;190;140m'    # Nord14 green
c='\033[38;2;136;192;208m'    # Nord8 cyan
d='\033[38;2;100;100;100m'    # dim gray
y='\033[38;2;235;203;139m'    # Nord13 yellow
red='\033[38;2;191;97;106m'   # Nord11 Aurora Red
r='\033[0m'                   # reset

# Get directory name (truncate if > 20 chars)
dir=$(basename "$cwd")
if [ ${#dir} -gt 20 ]; then
    dir="${dir:0:17}..."
fi

# Get git branch (truncate if > 20 chars)
branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
    if [ ${#branch} -gt 20 ]; then
        branch="${branch:0:17}..."
    fi
fi

# Get session name from transcript file
session_name=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    # First check for custom-title (user renamed via /rename)
    custom_title=$(grep '"type":"custom-title"' "$transcript_path" 2>/dev/null | tail -1 | jq -r '.customTitle // ""' 2>/dev/null)
    if [ -n "$custom_title" ]; then
        session_name="$custom_title"
    else
        # Fall back to auto-generated summary
        first_line=$(head -1 "$transcript_path" 2>/dev/null)
        if echo "$first_line" | jq -e '.type == "summary"' > /dev/null 2>&1; then
            session_name=$(echo "$first_line" | jq -r '.summary // ""')
        fi
    fi
fi

# Truncate session name if too long (max 30 chars)
if [ ${#session_name} -gt 30 ]; then
    session_name="${session_name:0:27}..."
fi

# Calculate total tokens used (cumulative)
in_tok=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
out_tok=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
total_tok=$((in_tok + out_tok))

# Format as "Xk toks"
if [ "$total_tok" -ge 1000 ]; then
    tok_display="$((total_tok / 1000))k"
else
    tok_display="$total_tok"
fi

# Build output
# Format: ⌂ dir · ⎇ branch · 4k │ Session Name
output=""

# Nerd Font icons
icon_dir=$(printf '\uf413')      # nf-oct-file_directory
icon_branch=$(printf '\ue725')   # nf-dev-git_branch
icon_tokens=$(printf '\ue26b')   # nf-fae-coins

# Directory with symbol
output="${w}${icon_dir} ${dir}${r}"

# Branch with symbol
if [ -n "$branch" ]; then
    output="${output} ${d}·${r} ${g}${icon_branch} ${branch}${r}"
fi

# Token count with coin symbol
output="${output} ${d}·${r} ${c}${icon_tokens} ${tok_display}${r}"

# Session name at the end (with clear delimiter)
if [ -n "$session_name" ]; then
    output="${output} ${d}│${r} ${y}${session_name}${r}"
fi

printf "%b\n" "$output"
