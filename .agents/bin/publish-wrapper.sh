#!/bin/bash
set -euo pipefail

NODE="$HOME/.local/share/fnm/node-versions/v24.11.1/installation/bin/node"
if [ ! -x "$NODE" ]; then
  NODE="$(command -v node)"
fi

exec "$NODE" "$HOME/.agents/bin/publish.mjs" "$@"
