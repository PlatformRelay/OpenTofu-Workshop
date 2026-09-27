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

# US-D-QUIZ-BANK (audit TEST-4): quiz:validate/test:quiz existed for months
# wired into NOTHING — a broken bank or a dead validator shipped green. The
# gate now lives in the lint job; this contract stops it silently falling out.
# Comment-stripped and scoped to the lint job's own block, so neither prose in
# ci.yml nor another job's steps can satisfy the greps.

@test "ci.yml lint job runs the quiz validation plane" {
  local wf="$ROOT/.github/workflows/ci.yml"
  local exec_lines block
  exec_lines="$(grep -v '^[[:space:]]*#' "$wf")"
  block="$(awk '/^  lint:/{f=1; print; next} f && /^  [a-z-]+:$/{f=0} f' <<<"$exec_lines")"
  grep -qF 'pnpm quiz:validate' <<<"$block"
  grep -qF 'pnpm test:quiz' <<<"$block"
}

@test "release.yml serializes Release runs per ref (US-E-RELCONC)" {
  # v0.6.0 double-fired: one tag push raced two publish runs and one needed a
  # manual cancel (runs 32947408465/32947408182; audit RELSE-1). A top-level
  # concurrency group keyed on the ref queues the duplicate behind the first;
  # cancel-in-progress stays false so an in-flight publish is never killed
  # mid-asset. Asserted against COMMENT-STRIPPED yaml, same as the ci.yml
  # contracts above — prose must not be able to certify the behaviour.
  local wf="$ROOT/.github/workflows/release.yml"
  local exec_lines
  exec_lines="$(grep -v '^[[:space:]]*#' "$wf")"

  # Top-level (column-0) key, not a stanza nested inside a job.
  grep -qx 'concurrency:' <<<"$exec_lines"

  # Extract the block itself so a job-level lookalike elsewhere in the file
  # cannot satisfy the two greps below.
  local block
  block="$(awk '/^concurrency:/{f=1; print; next} f && /^[^ ]/{f=0} f' <<<"$exec_lines")"
  grep -qF 'group: release-${{ github.ref }}' <<<"$block"
  grep -qF 'cancel-in-progress: false' <<<"$block"
}

# US-E-GOVET (audit TEST-1): the go-vet matrix (every
# tracked Go module, discovered from the tree, including the OVH variant twin) and the
# variant's verify-ovh-unit lane are asserted semantically by
# scripts/ci-wiring.test.mjs, which parses ci.yml instead of grepping its text.

# claims-check.mjs shipped UNWIRED: no workflow, task or package script ran it,
# so the pointers it validates rotted twice while CI stayed green. Wiring it is
# only a gate if the wiring itself cannot be quietly removed.
#
# COMMENT-STRIPPED, for the reason this file already learned the hard way: the
# ci.yml step carries a prose comment naming claims-check.mjs, so a naive grep
# would be satisfied by documentation rather than by an executable step.
#
# SCOPE, stated so this is not read as more than it is: it defends against
# satisfaction-by-documentation only. A step disabled at the YAML level -- an
# `if: false` on the job, or `continue-on-error: true` on the step -- still
# passes. Catching those means parsing the workflow rather than grepping it,
# and a one-line job-level disable is what diff review is for.

@test "ci.yml runs the claims plane, and not merely in a comment" {
  local wf="$ROOT/.github/workflows/ci.yml"
  local exec_lines
  # Strip whole-line comments AND trailing ones. Whole-line stripping alone was
  # defeatable: delete the step and write `- run: pnpm test:quiz  # TODO
  # re-enable: - run: pnpm test:claims` and this test passed while CI ran
  # nothing. That is precisely the failure this test claims to prevent.
  exec_lines="$(grep -v '^[[:space:]]*#' "$wf" | sed 's/[[:space:]]#.*$//')"

  grep -qF 'run: pnpm test:claims' <<<"$exec_lines"

  # The script the package script points at must exist and be the real checker.
  grep -qF '"test:claims": "node scripts/claims-check.mjs"' "$ROOT/package.json"
  [ -f "$ROOT/scripts/claims-check.mjs" ]
}
