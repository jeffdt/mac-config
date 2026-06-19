# shellcheck shell=bash
_tmpbin=$(mktemp -d)
cat > "$_tmpbin/cmx" <<'EOF'
#!/usr/bin/env bash
printf 'CMX_CALLED:'; printf ' %q' "$@"; printf '\n'
EOF
chmod +x "$_tmpbin/cmx"

assert_equals \
  "CMX_CALLED: send --workspace caller --tab surface:2 --cmd make\ test" \
  "$(PATH="$_tmpbin:$PATH" MUX_BACKEND=cmux TMUX='' CMUX_WORKSPACE_ID='' \
      bash "$MUX" send --workspace caller --tab surface:2 --cmd 'make test')" \
  "delegate: cmux backend execs cmx with verbatim argv"

assert_equals \
  "CMX_CALLED: status" \
  "$(PATH="$_tmpbin:$PATH" TMUX='' CMUX_WORKSPACE_ID='workspace:1' \
      bash "$MUX" status)" \
  "delegate: \$CMUX_WORKSPACE_ID routes to cmx"

rm -rf "$_tmpbin"
