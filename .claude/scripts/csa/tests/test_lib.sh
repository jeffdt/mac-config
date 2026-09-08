# shellcheck shell=bash
# Sourced by tests/run-tests.sh; SCRIPT_DIR comes from there.
# shellcheck disable=SC2034  # CSA_CONFIG is consumed by lib.sh functions.
FIXTURE_DIR="$SCRIPT_DIR/fixtures"

CSA_CONFIG="$FIXTURE_DIR/config.yaml"

assert_equals \
  "app
k-repo
fender" \
  "$(list_services)" \
  "list_services"

assert_equals \
  "echo app-dev" \
  "$(get_service_field app command)" \
  "get_service_field: app command"

assert_equals \
  "http://localhost:9002/" \
  "$(get_service_field k-repo ready_url)" \
  "get_service_field: k-repo ready_url"

assert_equals \
  "/tmp/test/fender" \
  "$(get_service_field fender root)" \
  "get_service_field: fender root"
