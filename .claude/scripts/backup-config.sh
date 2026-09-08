#!/bin/bash
set -euo pipefail

# PreToolUse hook: backs up Claude config files before Write/Edit operations.
# Protected files:
#   - ~/.claude.json
#   - ~/.claude/settings.json
#   - Any .claude/settings.local.json
# Backup format: {filename}.backup.YYYYMMDD-HHMMSS (same directory)

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Resolve to absolute path for reliable matching
resolved_path=$(realpath "$file_path" 2>/dev/null || echo "$file_path")

HOME_DIR="$HOME"
PROTECTED_PATTERNS=(
  "${HOME_DIR}/.claude.json"
  "${HOME_DIR}/.claude/settings.json"
)

is_protected=false

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$resolved_path" == "$pattern" ]]; then
    is_protected=true
    break
  fi
done

# Also match any .claude/settings.local.json
if [[ "$resolved_path" == */.claude/settings.local.json ]]; then
  is_protected=true
fi

if [[ "$is_protected" == true && -f "$resolved_path" ]]; then
  timestamp=$(date +"%Y%m%d-%H%M%S")
  backup_path="${resolved_path}.backup.${timestamp}"
  cp "$resolved_path" "$backup_path"
  echo "{\"systemMessage\": \"Config backup created: ${backup_path}\"}"
fi

exit 0
