#!/usr/bin/env bash
# Offline regression tests for scripts/release-notes-flags.sh (US-P-REL).
# Covers prerelease/body_path branching and release.yml wiring — no network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/release-notes-flags.sh"
BETA_LIMITATIONS="$ROOT/docs/beta-limitations.md"
WF="$ROOT/.github/workflows/release.yml"

# --- temp lifetime (US-F-GATEHYG) ---------------------------------------------
#
# One temp file for the whole run, owned by the exit path.
#
# What was actually wrong, measured rather than assumed: run_flags took its own
# `mktemp` per call and removed it inline. That inline `rm -f` is reached on
# every path bash actually walks here — including a FAILING
# release-notes-flags.sh — because `set -e` is NOT inherited by the `$( )`
# command-substitution subshells run_flags is always invoked from (probed on GNU
# bash 5.3.15: a `false` mid-function does not stop the function and the
# assignment still succeeds). So a green run and an ordinary red run both leak
# nothing, and the "leaks one file per invocation" reading of this code is
# wrong.
#
# The window that IS real is a signal. There was no trap, so a SIGTERM between
# the mktemp and the rm strands the file — measured at exactly one leaked file
# per interrupted run.
#
# How this script is reached, re-checked against ci.yml at each rebase because
# the answer has now changed twice. Since US-F-CIPARITY, verify-unit DISCOVERS
# `scripts/*-selftest.sh` by glob instead of hand-enumerating three scripts, so
# this file runs STANDALONE in CI *and* nested inside verify-selftest.sh, which
# still loops over release-tag-guard-selftest.sh and this one. Twice per job,
# so anything it leaks, it leaks twice. (An earlier draft of this comment
# asserted the glob existed before it did, and the correction asserted it did
# not exist just as it landed — hence: check ci.yml, do not remember it.)
#
# Corollary of discovery: any NEW scripts/*-selftest.sh is gated by CI the
# moment it lands, so it must be docker-free and offline.
#
# Hoisting to a single file plus a trap closes the signal window and deletes the
# per-call bookkeeping outright. EXIT also covers a `set -e` death at top level,
# where errexit IS in force.
GITHUB_OUTPUT_FILE="$(mktemp)"
notes_cleanup() { rm -f "$GITHUB_OUTPUT_FILE"; return 0; }
notes_rc=0
trap 'notes_rc=$?; notes_cleanup; exit "$notes_rc"' EXIT
trap 'notes_cleanup; trap - INT;  kill -INT  $$' INT
trap 'notes_cleanup; trap - TERM; kill -TERM $$' TERM

pass=0
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $label — expected '$expected', got '$actual'" >&2
    fail=$((fail + 1))
  fi
}

assert_status() {
  local label="$1" expected="$2"
  shift 2
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq "$expected" ]]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $label — expected exit $expected, got $rc (output: $out)" >&2
    fail=$((fail + 1))
  fi
  printf '%s' "$out"
}

run_flags() {
  local tag="$1"
  # Truncate rather than mint a new file: identical isolation between calls
  # (they are strictly sequential), one thing for the exit path to own.
  : >"$GITHUB_OUTPUT_FILE"
  export GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE"
  bash "$SCRIPT" "$tag"
  cat "$GITHUB_OUTPUT_FILE"
}

grep_field() {
  local blob="$1"
  local key="$2"
  printf '%s\n' "$blob" | awk -F= -v k="$key" '$1 == k { print substr($0, index($0, "=") + 1); exit }'
}

# --- decide outputs ------------------------------------------------------------

beta_out="$(run_flags "v0.2.0-beta.1")"
assert_eq "beta prerelease" "true" "$(grep_field "$beta_out" "prerelease")"
assert_eq "beta body_path" "docs/beta-limitations.md" "$(grep_field "$beta_out" "body_path")"

rc_out="$(run_flags "v1.0.0-rc.1")"
assert_eq "rc prerelease" "true" "$(grep_field "$rc_out" "prerelease")"
assert_eq "rc body_path" "docs/beta-limitations.md" "$(grep_field "$rc_out" "body_path")"

stable_out="$(run_flags "v1.0.0")"
assert_eq "stable prerelease" "false" "$(grep_field "$stable_out" "prerelease")"
assert_eq "stable body_path" "" "$(grep_field "$stable_out" "body_path")"

# --- guard rails ---------------------------------------------------------------

assert_status "missing tag exits usage" 2 bash "$SCRIPT"
assert_status "missing GITHUB_OUTPUT exits usage" 2 env -u GITHUB_OUTPUT bash "$SCRIPT" "v1.0.0"

# --- prepend source exists -----------------------------------------------------

if [[ -s "$BETA_LIMITATIONS" ]]; then
  pass=$((pass + 1))
else
  echo "FAIL: docs/beta-limitations.md must exist and be non-empty" >&2
  fail=$((fail + 1))
fi

if grep -q "Known limitations" "$BETA_LIMITATIONS"; then
  pass=$((pass + 1))
else
  echo "FAIL: docs/beta-limitations.md missing expected heading" >&2
  fail=$((fail + 1))
fi

# --- workflow wiring -----------------------------------------------------------

grep -q 'scripts/release-notes-flags.sh' "$WF" && pass=$((pass + 1)) || {
  echo "FAIL: release.yml must call release-notes-flags.sh" >&2
  fail=$((fail + 1))
}

grep -q 'body_path: \${{ needs.build.outputs.body_path }}' "$WF" && pass=$((pass + 1)) || {
  echo "FAIL: release.yml publish job must consume body_path output" >&2
  fail=$((fail + 1))
}

grep -q 'prerelease: \${{ needs.build.outputs.prerelease }}' "$WF" && pass=$((pass + 1)) || {
  echo "FAIL: release.yml publish job must consume prerelease output" >&2
  fail=$((fail + 1))
}

# P2: offline bundle uses relative asset paths for filesystem open-after-unzip.
grep -q -- '--base \./' "$WF" && pass=$((pass + 1)) || {
  echo "FAIL: release.yml must build offline decks with --base ./" >&2
  fail=$((fail + 1))
}

grep -q 'opentofu-workshop-site-\*\.zip' "$WF" && pass=$((pass + 1)) || {
  echo "FAIL: release.yml must stage opentofu-workshop-site-*.zip artifact" >&2
  fail=$((fail + 1))
}

echo "release-notes-flags-selftest: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
