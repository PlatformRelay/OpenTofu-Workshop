#!/usr/bin/env bash
# scripts/verify-selftest.sh — regression protection for the slide↔lab drift
# ENFORCEMENT in scripts/verify.sh (section 6). The main fixture is positive-only
# (a matching block), so deleting the enforcement would leave the build green and
# nobody would notice. This meta-test proves the check actually FAILS on drift.
#
# How it works: it copies the LIVE verify.sh + setup/lib.sh + the drift-demo
# fixture into a throwaway temp root. Because verify.sh derives REPO_ROOT from its
# own location and `cd`s there, the copy auto-isolates to the temp dir — no
# modules/examples, so tofu validate/test are no-ops and it runs sub-second.
# Copying at runtime (not vendoring a snapshot) means removing section 6 from the
# real verify.sh turns THIS test red — that is the regression protection.
#
# Three cases, each asserting BOTH exit code AND message (exit code alone is
# ambiguous — a clean pass could be a silent "no annotated blocks" no-op, and a
# non-zero could be an env break rather than real drift):
#   1. clean      → exit 0  AND  "no drift: …main.tf matches"   (enforcement ARMED)
#   2. LF drift   → exit !=0 AND  "✗ drift: …main.tf"           (catches drift)
#   3. CRLF drift → exit !=0 AND  "✗ drift: …main.tf"           (locks in F1)
#
# It NEVER mutates the tracked fixture; all edits happen inside the temp copy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FIXTURE_MD="labs/fixtures/drift-demo.md"
FIXTURE_TF="labs/fixtures/drift-demo/main.tf"

pass_n=0
fail_n=0
note() { printf '  [selftest] %s\n' "$*"; }
ok()   { printf '  [ OK ] %s\n' "$*"; pass_n=$((pass_n + 1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; fail_n=$((fail_n + 1)); }

command -v tofu >/dev/null 2>&1 || { echo "selftest: tofu required" >&2; exit 1; }

printf '\n### verify.sh drift-enforcement self-test ###\n'

# Build an isolated temp repo root with only what verify.sh needs.
build_root() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/setup" "$root/labs/fixtures/drift-demo"
  cp "$REPO_ROOT/scripts/verify.sh" "$root/scripts/verify.sh"
  cp "$REPO_ROOT/setup/lib.sh"      "$root/setup/lib.sh"
  cp "$REPO_ROOT/$FIXTURE_MD"       "$root/$FIXTURE_MD"
  cp "$REPO_ROOT/$FIXTURE_TF"       "$root/$FIXTURE_TF"
}

# run_case <label> <expect: pass|fail> <needle> <mutator-fn>
run_case() {
  local label="$1" expect="$2" needle="$3" mutate="$4"
  local tmp out rc
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  build_root "$tmp"
  "$mutate" "$tmp"
  set +e
  out="$(bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e

  if [ "$expect" = "pass" ]; then
    if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "$needle"; then
      ok "$label — exit 0 and enforcement armed ('$needle')"
    else
      bad "$label — expected exit 0 + '$needle'; got exit $rc"
      printf '%s\n' "$out" | grep -E 'drift|annotated' | sed 's/^/        /' || true
    fi
  else
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$needle"; then
      ok "$label — exit $rc (non-zero) and drift named ('$needle')"
    else
      bad "$label — expected non-zero + '$needle'; got exit $rc"
      printf '%s\n' "$out" | grep -E 'drift|annotated' | sed 's/^/        /' || true
    fi
  fi
}

# --- mutators (operate on the temp copy only) --------------------------------
m_clean() { :; }   # leave the copy pristine → block matches source

m_drift_lf() {     # change the source only → block no longer matches
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_LF/' "$root/$FIXTURE_TF"
}

m_drift_crlf() {   # drift the source AND author the .md as CRLF (F1 regression)
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_CRLF/' "$root/$FIXTURE_TF"
  perl -pi -e 's/\n/\r\n/' "$root/$FIXTURE_MD"
}

run_case "clean fixture"        pass "no drift: labs/fixtures/drift-demo/main.tf matches" m_clean
run_case "LF-authored drift"    fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_lf
run_case "CRLF-authored drift"  fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_crlf

printf '\n'
if [ "$fail_n" -eq 0 ]; then
  printf '  drift self-test PASSED — %d/%d cases OK.\n' "$pass_n" "$pass_n"
  exit 0
else
  printf '  drift self-test FAILED — %d case(s) failed, %d OK.\n' "$fail_n" "$pass_n"
  exit 1
fi
