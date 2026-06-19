# shellcheck shell=bash
if ! command -v tmux >/dev/null 2>&1; then
  printf '  SKIP  tmux send (tmux not installed)\n'
else
  _sess="mux-test-send-$$"
  tmux new-session -d -s "$_sess" -x 80 -y 24
  _win="$(tmux list-windows -t "=$_sess" -F '#{window_id}' | head -1)"
  _env=(MUX_BACKEND=tmux
        TMUX="$(tmux display-message -p '#{socket_path},#{pid},0')"
        TMUX_PANE="$(tmux list-panes -t "=$_sess" -F '#{pane_id}' | head -1)")

  _marker="$(mktemp -u /tmp/mux-send-XXXXXX)"
  env "${_env[@]}" bash "$MUX" send --workspace "$_sess" --tab "$_win" --cmd "touch $_marker" 2>/dev/null
  for _i in $(seq 1 20); do [[ -e "$_marker" ]] && break; sleep 0.25; done
  assert_equals "0" "$([[ -e "$_marker" ]] && echo 0 || echo 1)" \
    "send: --cmd executes (trailing Enter delivered)"
  rm -f "$_marker"

  tmux kill-session -t "=$_sess" 2>/dev/null || true
fi
