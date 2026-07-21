#!/usr/bin/env bash
# Minimal pure-bash test runner for csa library functions.
# Usage: bash tests/run-tests.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib.sh disable=SC1091
source "$LIB_DIR/lib.sh"

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

# Source each test file
for f in "$SCRIPT_DIR"/test_*.sh; do
  [[ -f "$f" ]] || continue
  printf '\n== %s ==\n' "$(basename "$f")"
  # shellcheck disable=SC1090
  source "$f"
done

printf '\n%d tests run, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
exit "$TESTS_FAILED"
