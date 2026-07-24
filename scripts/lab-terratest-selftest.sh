#!/usr/bin/env bash
# Regression: lab:terratest fails fast without Docker and points at host Go.
# Never starts containers; uses a PATH that intentionally omits docker.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"

# Minimal PATH: shell utilities only — no docker, no go-task.
export PATH="$BIN:/usr/bin:/bin"
export CI=true

# Provide a no-op `command` is already in /usr/bin; ensure docker is absent.
if command -v docker >/dev/null 2>&1; then
  # Hide docker by shadowing it with a missing-marker — prefer removing via PATH.
  # On some hosts docker lives outside /usr/bin; create a stub that proves we
  # check for a *working* docker by making our own PATH win first with a trap.
  :
fi
# Force-absent: a wrapper named docker that is never created; strip common
# locations by using only /usr/bin:/bin and asserting docker is gone.
if command -v docker >/dev/null 2>&1; then
  echo "selftest precondition failed: docker still on PATH=$PATH" >&2
  exit 1
fi

set +e
out="$(bash "$ROOT/scripts/lab-terratest.sh" labs/fixtures/terratest-smoke 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || {
  echo "expected non-zero exit when docker is absent" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -qi 'docker' || {
  echo "expected message to mention docker" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -Eqi 'host Go|lab:terratest:host|BOOTSTRAP_WITH_GO|brew install go' || {
  echo "expected message to point at the host-Go alternative" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

echo "lab-terratest self-test PASSED — docker-absent fail-fast points at host Go"
