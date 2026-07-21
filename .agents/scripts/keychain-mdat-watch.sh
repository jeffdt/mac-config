#!/bin/bash
# Poll the Claude Code keychain entry's mdat (last-modified) every time
# launchd fires this. Used to diagnose whether the OAuth refresh loop is
# actually firing overnight when nobody is around to refresh it manually.
# See ~/.claude/projects/.../memory/claude-cli-auth-lapse.md for context.
set -uo pipefail

LOG="$HOME/.local/share/morning-digest/keychain-mdat.log"
mkdir -p "$(dirname "$LOG")"

ts=$(date +%Y-%m-%dT%H:%M:%S%z)
mdat_line=$(security find-generic-password \
              -s "Claude Code-credentials" \
              -a "$USER" 2>/dev/null \
            | grep '"mdat"' \
            || echo 'NO_MDAT_FOUND')

echo "$ts $mdat_line" >> "$LOG"
