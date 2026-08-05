# shellcheck shell=bash
# Shared bats helpers: mock PATH, MOCK_LOG, and repo root for shell-plane tests.

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

setup_mocks() {
  ROOT="$(repo_root)"
  export ROOT

  MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  : >"$MOCK_LOG"
  export MOCK_LOG

  PATH="$ROOT/tests/shell/stubs:$PATH"
  export PATH

  export CI=true
  export HAS_GUM=0
  export INTERACTIVE=0
}
