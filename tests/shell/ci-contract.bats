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

# US-F-CIPARITY replaced verify-unit's hand-written self-test list with glob
# DISCOVERY, so ci.yml no longer NAMES bootstrap-selftest.sh or
# verify-selftest.sh. The enumerated contract that used to live here grepped for
# exactly those literals, and went red the moment discovery landed.
#
# The intent it encoded — "CI still runs the shell meta-tests" — is unchanged.
# But under discovery that intent lives in the MECHANISM, so the mechanism is
# what these two tests assert: ci.yml globs, an empty glob is fatal, and the
# meta-tests still match the pattern being globbed.
#
# Both assert against COMMENT-STRIPPED ci.yml. The previous version of this test
# satisfied its `verify-selftest.sh` grep from a prose comment in the workflow —
# armed in appearance, satisfied by documentation in fact. Strip the comments
# first so no amount of prose can certify a behaviour.

@test "verify-unit discovers the shell meta-tests instead of enumerating them" {
  local wf="$ROOT/.github/workflows/ci.yml"
  local exec_lines
  exec_lines="$(grep -v '^[[:space:]]*#' "$wf")"

  # The discovery glob itself.
  grep -qF 'selftests=(scripts/*-selftest.sh)' <<<"$exec_lines"

  # Discovery is only a gate if matching NOTHING is fatal. Without this guard an
  # empty glob would let the unit lane report green having certified nothing.
  grep -qF 'self-test discovery matched no' <<<"$exec_lines"

  # verify.sh still runs, and AFTER the discovery loop: verify-selftest.sh must
  # precede verify.sh (see the release-self-test note in
  # scripts/verify-selftest.sh), which holds only because the loop comes first.
  grep -qF 'bash scripts/verify.sh' <<<"$exec_lines"

  local glob_line verify_line
  glob_line="$(grep -nF 'selftests=(scripts/*-selftest.sh)' <<<"$exec_lines" | head -1 | cut -d: -f1)"
  verify_line="$(grep -nF 'bash scripts/verify.sh' <<<"$exec_lines" | head -1 | cut -d: -f1)"
  [ "$glob_line" -lt "$verify_line" ]
}

@test "the shell meta-tests are still reachable by CI's discovery glob" {
  # Discovery means CI cannot name these, so naming them HERE is what stops a
  # rename out of the globbed pattern from silently dropping them from CI —
  # which is the regression the enumerated version of this test used to catch.
  [ -f "$ROOT/scripts/bootstrap-selftest.sh" ]
  [ -f "$ROOT/scripts/verify-selftest.sh" ]

  local matched
  matched="$(cd "$ROOT" && printf '%s\n' scripts/*-selftest.sh)"
  grep -qx 'scripts/bootstrap-selftest\.sh' <<<"$matched"
  grep -qx 'scripts/verify-selftest\.sh' <<<"$matched"
}
