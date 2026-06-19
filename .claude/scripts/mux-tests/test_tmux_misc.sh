# shellcheck shell=bash
if ! command -v tmux >/dev/null 2>&1; then
  printf '  SKIP  tmux misc (tmux not installed)\n'
else
  _sess="mux-test-misc-$$"
  tmux new-session -d -s "$_sess" -x 80 -y 24
  _win="$(tmux list-windows -t "=$_sess" -F '#{window_id}' | head -1)"
  _env=(MUX_BACKEND=tmux
        TMUX="$(tmux display-message -p '#{socket_path},#{pid},0')"
        TMUX_PANE="$(tmux list-panes -t "=$_sess" -F '#{pane_id}' | head -1)")

  env "${_env[@]}" bash "$MUX" rename --workspace "$_sess" --tab "$_win" --title renamed 2>/dev/null
  assert_equals "renamed" \
    "$(tmux list-windows -t "=$_sess" -F '#{window_id} #{window_name}' | awk -v w="$_win" '$1==w{print $2}')" \
    "rename: window-name updated"

  assert_equals "$_sess" \
    "$(env "${_env[@]}" bash "$MUX" resolve workspace "$_sess" 2>/dev/null)" \
    "resolve workspace: existing session -> name"

  assert_equals "0" \
    "$(env "${_env[@]}" bash "$MUX" list tabs --workspace "$_sess" 2>/dev/null | grep -q "$_win" && echo 0 || echo 1)" \
    "list tabs: includes the window id"

  _w2="$(tmux new-window -d -t "=${_sess}:" -P -F '#{window_id}')"
  env "${_env[@]}" bash "$MUX" close --workspace "$_sess" --tab "$_w2" 2>/dev/null
  assert_equals "1" \
    "$(tmux list-windows -t "=$_sess" -F '#{window_id}' | grep -q "$_w2" && echo 0 || echo 1)" \
    "close: window removed"

  tmux kill-session -t "=$_sess" 2>/dev/null || true
fi
