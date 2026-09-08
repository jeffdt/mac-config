# shellcheck shell=bash
if ! command -v tmux >/dev/null 2>&1; then
  printf '  SKIP  tmux paste (tmux not installed)\n'
else
  _sess="mux-test-paste-$$"
  tmux new-session -d -s "$_sess" -x 80 -y 24
  _win="$(tmux list-windows -t "=$_sess" -F '#{window_id}' | head -1)"
  _env=(MUX_BACKEND=tmux
        TMUX="$(tmux display-message -p '#{socket_path},#{pid},0')"
        TMUX_PANE="$(tmux list-panes -t "=$_sess" -F '#{pane_id}' | head -1)")

  # Two-line payload, NO trailing newline on the last line — mirrors a
  # piped-in debrief. The embedded newline between the lines should submit
  # the first line on its own; the trailing line must stay unsubmitted
  # until something sends a real Enter.
  _m1="$(mktemp -u /tmp/mux-paste-m1-XXXXXX)"
  _m2="$(mktemp -u /tmp/mux-paste-m2-XXXXXX)"
  printf 'touch %s\ntouch %s' "$_m1" "$_m2" \
    | env "${_env[@]}" bash "$MUX" paste --workspace "$_sess" --tab "$_win" 2>/dev/null

  for _i in $(seq 1 20); do [[ -e "$_m1" ]] && break; sleep 0.25; done
  assert_equals "0" "$([[ -e "$_m1" ]] && echo 0 || echo 1)" \
    "paste: embedded newline submits the first line on its own"
  assert_equals "1" "$([[ -e "$_m2" ]] && echo 0 || echo 1)" \
    "paste: trailing line without --enter stays unsubmitted"

  # Now submit the pending line with a real Enter and confirm it runs.
  env "${_env[@]}" bash "$MUX" send-key --workspace "$_sess" --tab "$_win" --key enter 2>/dev/null
  for _i in $(seq 1 20); do [[ -e "$_m2" ]] && break; sleep 0.25; done
  assert_equals "0" "$([[ -e "$_m2" ]] && echo 0 || echo 1)" \
    "paste: a separate Enter afterward submits the trailing line"
  rm -f "$_m1" "$_m2"

  # --enter should do that trailing Enter itself, in one call.
  _m3="$(mktemp -u /tmp/mux-paste-m3-XXXXXX)"
  printf 'touch %s' "$_m3" \
    | env "${_env[@]}" bash "$MUX" paste --workspace "$_sess" --tab "$_win" --enter 2>/dev/null
  for _i in $(seq 1 20); do [[ -e "$_m3" ]] && break; sleep 0.25; done
  assert_equals "0" "$([[ -e "$_m3" ]] && echo 0 || echo 1)" \
    "paste: --enter submits a single line with no embedded newline"
  rm -f "$_m3"

  # -d on paste-buffer must have deleted the scratch buffer after each paste.
  assert_equals "0" \
    "$(tmux list-buffers 2>/dev/null | grep -qE '^mux-paste-' && echo 1 || echo 0)" \
    "paste: scratch buffer is deleted after use"

  tmux kill-session -t "=$_sess" 2>/dev/null || true
fi
