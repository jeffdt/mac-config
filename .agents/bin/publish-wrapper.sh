#!/bin/bash
set -euo pipefail

# launchd runs this with a minimal PATH, so add the usual Node install locations.
export PATH="$HOME/.local/share/fnm/aliases/default/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

NODE="$HOME/.local/share/fnm/node-versions/v24.11.1/installation/bin/node"
if [ ! -x "$NODE" ]; then
  NODE="$(command -v node)"
fi

exec "$NODE" "$HOME/.agents/bin/publish.mjs" "$@"
