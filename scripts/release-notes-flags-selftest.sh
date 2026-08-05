#!/usr/bin/env bash
# Offline regression tests for scripts/release-notes-flags.sh (US-P-REL).
# Covers prerelease/body_path branching and release.yml wiring — no network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/release-notes-flags.sh"
BETA_LIMITATIONS="$ROOT/docs/beta-limitations.md"
WF="$ROOT/.github/workflows/release.yml"

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
  local out_file
  out_file="$(mktemp)"
  export GITHUB_OUTPUT="$out_file"
  bash "$SCRIPT" "$tag"
  cat "$out_file"
  rm -f "$out_file"
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
