#!/usr/bin/env bash
# csa library: config accessors. Sourced by csa and tests/run-tests.sh.

set -u

# shellcheck disable=SC2034  # consumed by callers that source this file
export CSA_CONFIG="${CSA_CONFIG:-$HOME/.config/csa/config.yaml}"

list_services() {
  yq -r '.services | keys | .[]' "$CSA_CONFIG"
}

get_service_field() {
  local service=$1 field=$2
  yq -r ".services.\"${service}\".${field} // \"\"" "$CSA_CONFIG"
}
