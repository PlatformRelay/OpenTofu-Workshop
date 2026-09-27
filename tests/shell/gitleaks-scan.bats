#!/usr/bin/env bats
# Log-verdict contract for scripts/gitleaks-scan.sh (the CI secret-scan job).
#
# gitleaks v8 exits 0 and prints "no leaks found" even when git refused to
# read the repository (e.g. "detected dubious ownership" when the container
# runs as root over a runner-owned checkout). The wrapper must therefore judge
# the log, not the exit code alone. These cases need no docker: they feed the
# verdict function recorded gitleaks output.

load helpers

setup() {
  setup_mocks
  SCAN="$ROOT/scripts/gitleaks-scan.sh"
}

@test "check-log rejects a scan that could not read the repository" {
  cat >"$BATS_TEST_TMPDIR/log" <<'EOF'
8:19PM ERR [git] fatal: detected dubious ownership in repository at '/github/workspace'
8:19PM ERR [git] 	git config --global --add safe.directory /github/workspace
8:19PM ERR failed to scan Git repository error="stderr is not empty"
8:19PM INF scan completed in 5.78ms
8:19PM INF no leaks found
EOF
  run sh "$SCAN" check-log "$BATS_TEST_TMPDIR/log"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not read the repository"* ]]
}

@test "check-log rejects a log with no commits-scanned line" {
  printf '8:19PM INF scan completed in 1ms\n8:19PM INF no leaks found\n' >"$BATS_TEST_TMPDIR/log"
  run sh "$SCAN" check-log "$BATS_TEST_TMPDIR/log"
  [ "$status" -ne 0 ]
  [[ "$output" == *"commits scanned"* ]]
}

@test "check-log rejects zero commits scanned" {
  printf '8:19PM INF 0 commits scanned.\n8:19PM INF no leaks found\n' >"$BATS_TEST_TMPDIR/log"
  run sh "$SCAN" check-log "$BATS_TEST_TMPDIR/log"
  [ "$status" -ne 0 ]
}

@test "check-log accepts a real scan and reports the commit count" {
  cat >"$BATS_TEST_TMPDIR/log" <<'EOF'
8:19PM INF 488 commits scanned.
8:19PM INF scan completed in 1.58s
8:19PM INF no leaks found
EOF
  run sh "$SCAN" check-log "$BATS_TEST_TMPDIR/log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"488 commits scanned"* ]]
}

@test "check-log requires the expected commit count when one is given" {
  printf '8:19PM INF 1 commits scanned.\n8:19PM INF no leaks found\n' >"$BATS_TEST_TMPDIR/log"
  run sh "$SCAN" check-log "$BATS_TEST_TMPDIR/log" 488
  [ "$status" -ne 0 ]
  run sh "$SCAN" check-log "$BATS_TEST_TMPDIR/log" 1
  [ "$status" -eq 0 ]
}

@test "ci.yml runs the wrapper for both the history scan and the positive control" {
  local wf="$ROOT/.github/workflows/ci.yml"
  grep -q 'scripts/gitleaks-scan.sh history' "$wf"
  grep -q 'scripts/gitleaks-scan.sh control' "$wf"
}
