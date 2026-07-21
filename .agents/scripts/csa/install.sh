#!/usr/bin/env bash
# Install csa: symlink into ~/.local/bin and bootstrap ~/.config/csa.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.config/csa"

src="$SCRIPT_DIR/csa"
dst="$HOME/.local/bin/csa"
if [[ -L "$dst" || -e "$dst" ]]; then
  echo "already present: $dst"
else
  ln -s "$src" "$dst"
  echo "linked: $dst -> $src"
fi

if [[ ! -f "$HOME/.config/csa/config.yaml" ]]; then
  cp "$SCRIPT_DIR/config.yaml.example" "$HOME/.config/csa/config.yaml"
  echo "bootstrapped: $HOME/.config/csa/config.yaml (edit with real values)"
else
  echo "already present: $HOME/.config/csa/config.yaml"
fi

echo
echo "done. ensure ~/.local/bin is on PATH."
