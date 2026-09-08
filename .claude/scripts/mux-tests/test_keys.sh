# shellcheck shell=bash
assert_equals "C-c"    "$(mux_key_to_tmux ctrl+c)"  "key: ctrl+c -> C-c"
assert_equals "C-c"    "$(mux_key_to_tmux C-c)"     "key: C-c -> C-c (passthrough)"
assert_equals "Enter"  "$(mux_key_to_tmux enter)"   "key: enter -> Enter"
assert_equals "Enter"  "$(mux_key_to_tmux Enter)"   "key: Enter -> Enter"
assert_equals "Tab"    "$(mux_key_to_tmux tab)"     "key: tab -> Tab"
assert_equals "Escape" "$(mux_key_to_tmux escape)"  "key: escape -> Escape"
assert_equals "M-x"    "$(mux_key_to_tmux alt+x)"   "key: alt+x -> M-x"
assert_equals "C-d"    "$(mux_key_to_tmux control+d)" "key: control+d -> C-d"
