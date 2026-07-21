#!/usr/bin/env bash
# Pure-bash test runner for the mux dispatcher.
# Usage: bash scripts/mux-tests/run-tests.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUX="$(cd "$SCRIPT_DIR/.." && pwd)/mux"
export MUX

TESTS_RUN=0
TESTS_FAILED=0

# shellcheck disable=SC2329  # Invoked indirectly from sourced test_*.sh files.
assert_equals() {
  local expected=$1 actual=$2 desc=${3:-unnamed}
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$expected" == "$actual" ]]; then
    printf '  PASS  %s\n' "$desc"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL  %s\n        expected: %q\n        actual:   %q\n' \
      "$desc" "$expected" "$actual"
  fi
}

# Sourcing mux must NOT run dispatch (guarded by the BASH_SOURCE check in mux).
# shellcheck disable=SC1090
source "$MUX"
# mux sets `set -euo pipefail`; sourcing leaks those into this runner. Reset to a
# test-friendly mode so a function returning nonzero doesn't abort the suite.
set +e +u +o pipefail

for f in "$SCRIPT_DIR"/test_*.sh; do
  [[ -f "$f" ]] || continue
  printf '\n== %s ==\n' "$(basename "$f")"
  # shellcheck disable=SC1090
  source "$f"
done

printf '\n%d tests run, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
exit "$TESTS_FAILED"
