# shellcheck shell=bash
if ! command -v tmux >/dev/null 2>&1; then
  printf '  SKIP  tmux spawn (tmux not installed)\n'
else
  _sess="mux-test-spawn-$$"
  tmux new-session -d -s "$_sess" -x 80 -y 24
  # Capture the session's ACTIVE window via list-windows (display-message returns
  # empty for a detached session, which would make the comparison below vacuous).
  _orig_win="$(tmux list-windows -t "=$_sess" -F '#{window_active} #{window_id}' | awk '$1==1{print $2}')"

  _env=(MUX_BACKEND=tmux
        TMUX="$(tmux display-message -p '#{socket_path},#{pid},0')"
        TMUX_PANE="$(tmux list-panes -t "=$_sess" -F '#{pane_id}' | head -1)")

  # Default spawn: prints a @id token, does NOT change the session's active window.
  _tab="$(env "${_env[@]}" bash "$MUX" spawn --workspace "$_sess" --title worker --cmd 'sleep 30' 2>/dev/null)"
  assert_equals "0" "$([[ "$_tab" == @* ]] && echo 0 || echo 1)" \
    "spawn: prints a @<id> tab token on stdout ($_tab)"

  _active_after="$(tmux list-windows -t "=$_sess" -F '#{window_active} #{window_id}' | awk '$1==1{print $2}')"
  assert_equals "0" "$([[ -n "$_orig_win" ]] && echo 0 || echo 1)" \
    "spawn: active window id is non-empty (guards the compare below against vacuity)"
  assert_equals "$_orig_win" "$_active_after" \
    "spawn: default (-d) leaves the session's active window unchanged"
  assert_equals "different" "$([[ "$_tab" != "$_active_after" ]] && echo different || echo same)" \
    "spawn: the spawned window is NOT the active window (direct -d check)"

  # The new window exists and is named.
  assert_equals "worker" \
    "$(tmux list-windows -t "=$_sess" -F '#{window_id} #{window_name}' | awk -v w="$_tab" '$1==w{print $2}')" \
    "spawn: new window is named 'worker'"

  # --json carries workspace + tab.
  _json="$(env "${_env[@]}" bash "$MUX" spawn --workspace "$_sess" --title worker2 --cmd 'sleep 30' --json 2>/dev/null)"
  assert_equals "$_sess" \
    "$(printf '%s' "$_json" | sed -n 's/.*"workspace":"\([^"]*\)".*/\1/p')" \
    "spawn: --json reports workspace=session"

  # Regression (caught by live demo): a SHORT command must NOT make the window
  # vanish. tmux destroys a window when its process exits, so spawn runs the
  # command inside a persistent shell. Verify the window survives a fast command
  # and its output stays readable.
  _ptab="$(env "${_env[@]}" bash "$MUX" spawn --workspace "$_sess" --title persist --cmd 'echo SPAWN_PERSIST_MARKER' 2>/dev/null)"
  for _i in $(seq 1 20); do
    env "${_env[@]}" bash "$MUX" read --workspace "$_sess" --tab "$_ptab" 2>/dev/null | grep -q SPAWN_PERSIST_MARKER && break
    sleep 0.25
  done
  assert_equals "0" \
    "$(tmux list-windows -t "=$_sess" -F '#{window_id}' | grep -q "$_ptab" && echo 0 || echo 1)" \
    "spawn: window with a short command persists (not destroyed on cmd exit)"
  assert_equals "0" \
    "$(env "${_env[@]}" bash "$MUX" read --workspace "$_sess" --tab "$_ptab" 2>/dev/null | grep -q SPAWN_PERSIST_MARKER && echo 0 || echo 1)" \
    "spawn: short-command output readable after the command finished"

  tmux kill-session -t "=$_sess" 2>/dev/null || true
fi
