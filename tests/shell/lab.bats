#!/usr/bin/env bats
# REL-4 / US-P-SHELLCI — lab runner workdir resolution and panic-reset destroy leg.

load helpers

setup() {
  setup_mocks
  chmod +x "$ROOT"/tests/shell/stubs/* 2>/dev/null || true
}

@test "lab_workdir_for resolves sibling workdir (ADR 0009)" {
  run bash -c '
    cd "$ROOT"
    # shellcheck source=setup/lib.sh disable=SC1091
    . setup/lib.sh
    lab_workdir_for labs/day-1/05-state-encryption.md
  '
  [ "$status" -eq 0 ]
  [ "$output" = "labs/day-1/05-state-encryption" ]
}

@test "REL-4: lab workdir is not examples/ basename mapping" {
  run bash -c '
    cd "$ROOT"
    # shellcheck source=setup/lib.sh disable=SC1091
    . setup/lib.sh
    lab_workdir_for labs/day-1/05-state-encryption.md
  '
  [ "$status" -eq 0 ]
  [ "$output" != "examples/05-state-encryption" ]
  ! echo "$output" | grep -q '^examples/'
}

@test "lab_workdir_for maps capstone lab to examples/capstone" {
  run bash -c '
    cd "$ROOT"
    # shellcheck source=setup/lib.sh disable=SC1091
    . setup/lib.sh
    lab_workdir_for labs/day-3/26-capstone.md
  '
  [ "$status" -eq 0 ]
  [ "$output" = "examples/capstone" ]
}

@test "lab_workdir_for returns non-zero when no workdir exists" {
  run bash -c '
    cd "$ROOT"
    # shellcheck source=setup/lib.sh disable=SC1091
    . setup/lib.sh
    lab_workdir_for labs/day-1/11-taco-landscape.md
  '
  [ "$status" -eq 1 ]
}

@test "lab_panic_reset destroys in the resolved workdir and stops LocalStack" {
  run bash -c '
    cd "$ROOT"
    export MOCK_LOG PATH
    # shellcheck source=setup/lib.sh disable=SC1091
    . setup/lib.sh
    lab_panic_reset labs/day-1/05-state-encryption
  '
  [ "$status" -eq 0 ]
  grep -q 'tofu-chdir labs/day-1/05-state-encryption destroy' "$MOCK_LOG"
  grep -q 'task lab:down' "$MOCK_LOG"
}

@test "lab.sh panic reset wires lab_workdir_for into lab_panic_reset (REL-4 paper gate)" {
  : >"$MOCK_LOG"
  run bash -c '
    cd "$ROOT"
    export MOCK_LOG PATH ROOT
    export WORKSHOP_FORCE_INTERACTIVE=1
    export LAB_SH_LAB_CHOICE=labs/day-1/05-state-encryption.md
    export LAB_SH_SKIP_UP=1
    unset CI
    printf "y\n" | bash setup/lab.sh >/dev/null
  '
  [ "$status" -eq 0 ]
  grep -q 'lab_workdir_for' "$ROOT/setup/lab.sh"
  grep -q 'lab_panic_reset "$ACTIVE_WORKDIR"' "$ROOT/setup/lab.sh"
  grep -q 'tofu-chdir labs/day-1/05-state-encryption destroy' "$MOCK_LOG"
  ! grep -q 'examples/05-state-encryption' "$MOCK_LOG"
}
