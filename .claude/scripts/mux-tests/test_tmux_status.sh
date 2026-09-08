# shellcheck shell=bash
if ! command -v tmux >/dev/null 2>&1; then
  printf '  SKIP  tmux status (tmux not installed)\n'
else
  _sess="mux-test-status-$$"
  tmux new-session -d -s "$_sess" -x 80 -y 24

  # Run mux as a subprocess with TMUX faked to the running server, MUX_BACKEND forcing tmux.
  _out="$(MUX_BACKEND=tmux TMUX="$(tmux display-message -p '#{socket_path},#{pid},0')" \
          TMUX_PANE="$(tmux list-panes -t "=$_sess" -F '#{pane_id}' | head -1)" \
          bash "$MUX" status --json 2>/dev/null)"
  assert_equals "tmux" \
    "$(printf '%s' "$_out" | sed -n 's/.*"backend":"\([^"]*\)".*/\1/p')" \
    "status: --json reports backend=tmux"

  tmux kill-session -t "=$_sess" 2>/dev/null || true
fi
