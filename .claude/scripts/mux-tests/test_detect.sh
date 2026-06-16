# shellcheck shell=bash
# Sourced by run-tests.sh. Tests mux_detect_backend in isolation.

assert_equals "tmux" \
  "$(TMUX='/tmp/x,1,0' CMUX_WORKSPACE_ID='' MUX_BACKEND='' mux_detect_backend)" \
  "detect: \$TMUX present -> tmux"

assert_equals "cmux" \
  "$(TMUX='' CMUX_WORKSPACE_ID='workspace:3' MUX_BACKEND='' mux_detect_backend)" \
  "detect: \$CMUX_WORKSPACE_ID present -> cmux"

assert_equals "tmux" \
  "$(TMUX='/tmp/x,1,0' CMUX_WORKSPACE_ID='workspace:3' MUX_BACKEND='' mux_detect_backend)" \
  "detect: both present -> tmux wins (nesting)"

assert_equals "cmux" \
  "$(TMUX='/tmp/x,1,0' CMUX_WORKSPACE_ID='' MUX_BACKEND='cmux' mux_detect_backend)" \
  "detect: MUX_BACKEND overrides \$TMUX"

assert_equals "1" \
  "$(TMUX='' CMUX_WORKSPACE_ID='' MUX_BACKEND='' bash -c 'source "$MUX"; set +e; mux_detect_backend >/dev/null; echo $?' 2>/dev/null | tail -1)" \
  "detect: neither -> exit 1"
