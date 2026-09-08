# shellcheck shell=bash
if ! command -v tmux >/dev/null 2>&1; then
  printf '  SKIP  tmux read (tmux not installed)\n'
else
  _sess="mux-test-read-$$"
  tmux new-session -d -s "$_sess" -x 80 -y 24
  _win="$(tmux list-windows -t "=$_sess" -F '#{window_id}' | head -1)"
  _env=(MUX_BACKEND=tmux
        TMUX="$(tmux display-message -p '#{socket_path},#{pid},0')"
        TMUX_PANE="$(tmux list-panes -t "=$_sess" -F '#{pane_id}' | head -1)")

  tmux send-keys -t "=${_sess}:${_win}" -l "echo MUX_READ_MARKER_123"; tmux send-keys -t "=${_sess}:${_win}" Enter
  for _i in $(seq 1 20); do
    env "${_env[@]}" bash "$MUX" read --workspace "$_sess" --tab "$_win" 2>/dev/null | grep -q MUX_READ_MARKER_123 && break
    sleep 0.25
  done
  assert_equals "0" \
    "$(env "${_env[@]}" bash "$MUX" read --workspace "$_sess" --tab "$_win" 2>/dev/null | grep -q MUX_READ_MARKER_123 && echo 0 || echo 1)" \
    "read: captures pane output containing the marker"

  assert_equals "0" \
    "$(env "${_env[@]}" bash "$MUX" wait-for --workspace "$_sess" --tab "$_win" --pattern MUX_READ_MARKER_123 --timeout 5 >/dev/null 2>&1; echo $?)" \
    "wait-for: returns 0 on matching pattern"

  tmux kill-session -t "=$_sess" 2>/dev/null || true
fi
