# shellcheck shell=bash
# Integration: requires a tmux server. Creates a throwaway session, asserts
# resolution, cleans up. Skips cleanly if tmux is unavailable.
if ! command -v tmux >/dev/null 2>&1; then
  printf '  SKIP  tmux helpers (tmux not installed)\n'
else
  _sess="mux-test-helpers-$$"
  tmux new-session -d -s "$_sess" -x 80 -y 24 2>/dev/null

  # A bare name resolves to itself when the session exists.
  assert_equals "$_sess" \
    "$(mux_tmux_resolve_ws "$_sess")" \
    "resolve_ws: existing session name -> itself"

  # 'focused' resolves to some attached or most-recent session (non-empty).
  _focused="$(mux_tmux_resolve_ws focused 2>/dev/null || true)"
  assert_equals "0" "$([[ -n "$_focused" ]] && echo 0 || echo 1)" \
    "resolve_ws: focused returns non-empty"

  tmux kill-session -t "$_sess" 2>/dev/null || true
fi
