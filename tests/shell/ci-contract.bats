#!/usr/bin/env bats
# CI wiring contract for the shell plane job.

load helpers

setup() {
  setup_mocks
}

@test "ci.yml defines shell job with shellcheck and bats" {
  local wf="$ROOT/.github/workflows/ci.yml"
  grep -q 'name: Shell scripts (shellcheck + bats)' "$wf"
  grep -q 'shellcheck' "$wf"
  grep -q 'bats tests/shell' "$wf"
}

@test "verify-unit still runs existing shell meta-tests" {
  local wf="$ROOT/.github/workflows/ci.yml"
  grep -q 'bootstrap-selftest.sh' "$wf"
  grep -q 'verify-selftest.sh' "$wf"
}
