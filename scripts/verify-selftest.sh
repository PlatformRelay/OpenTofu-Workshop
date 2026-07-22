#!/usr/bin/env bash
# scripts/verify-selftest.sh — regression protection for three ENFORCEMENT gates in
# scripts/verify.sh: (A) slide↔lab drift enforcement (section 6), (B) deck tier
# consistency + hide invariant (section 7), and (C) the README navigation
# contract (section 8), plus the Day-2/3 skip contract (section 9). These gates are positive-only in the
# tracked tree (matching fixture / consistent decks), so silently deleting or
# weakening any of them would leave the build green and nobody would notice. This
# meta-test proves each check actually FAILS when it should.
#
# How it works: it copies the LIVE verify.sh + setup/lib.sh + the drift-demo
# fixture (and, for the tier cases, the two content decks) into a throwaway temp
# root. Because verify.sh derives REPO_ROOT from its own location and `cd`s there,
# the copy auto-isolates to the temp dir — no modules/examples, so tofu
# validate/test are no-ops and it runs sub-second. Copying at runtime (not
# vendoring a snapshot) means removing/weakening the enforcement in the real
# verify.sh turns THIS test red — that is the regression protection.
#
# Cases, each asserting BOTH exit code AND message (exit code alone is ambiguous —
# a clean pass could be a silent "no annotated blocks / no headers" no-op, and a
# non-zero could be an env break rather than a real violation):
#   drift gate (section 6):
#     1. clean      → exit 0  AND  "no drift: …main.tf matches"   (enforcement ARMED)
#     2. LF drift   → exit !=0 AND  "✗ drift: …main.tf"           (catches drift)
#     3. CRLF drift → exit !=0 AND  "✗ drift: …main.tf"           (locks in F1)
#   tier gate (section 7):
#     4. cross-deck tier mismatch → exit !=0 AND "tier drift: S05 …"   (deck↔deck)
#     5. hide-invariant violation → exit !=0 AND "hide invariant: S18 …" (3-day cut)
#   README navigation gate (section 8):
#     6. clean routes → exit 0 AND "README navigation contract"
#     7. deleted route → exit !=0 AND the route label + path
#     8. unknown task → exit !=0 AND the command name
#   Day-2/3 tool contract (section 9):
#     9. broken/absent tool → exit 0 AND an explicit affected-lab skip warning
#   formatting allowlist contract (section 2):
#    10. exact S13 messy fixture → exit 0 AND formatting gate remains armed
#    11. another unformatted .tf beside the fixture → exit !=0 AND path is named
#    12. any other unformatted .tf → exit !=0 AND offending path is named
#
# It NEVER mutates the tracked fixture or decks; all edits happen in the temp copy.
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

printf '\n### verify.sh enforcement self-test (drift + tier + README navigation) ###\n'

# Build an isolated temp repo root with only what verify.sh needs. Includes the
# two content decks so section 7 (tier consistency) has inputs; verify.sh reads
# them by literal path relative to REPO_ROOT.
build_root() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/setup" "$root/labs/fixtures/drift-demo" \
    "$root/labs/day-1/00-setup" "$root/labs/day-2/13-static-analysis/messy" \
    "$root/docs/decisions"
  cp "$REPO_ROOT/scripts/verify.sh" "$root/scripts/verify.sh"
  cp "$REPO_ROOT/setup/lib.sh"      "$root/setup/lib.sh"
  cp "$REPO_ROOT/$FIXTURE_MD"       "$root/$FIXTURE_MD"
  cp "$REPO_ROOT/$FIXTURE_TF"       "$root/$FIXTURE_TF"
  cp "$REPO_ROOT/slides.md"         "$root/slides.md"
  cp "$REPO_ROOT/slides-3day.md"    "$root/slides-3day.md"
  cp "$REPO_ROOT/slides-templates.md" "$root/slides-templates.md"
  cp "$REPO_ROOT/README.md"         "$root/README.md"
  cp "$REPO_ROOT/AGENT.md"          "$root/AGENT.md"
  cp "$REPO_ROOT/Taskfile.yaml"     "$root/Taskfile.yaml"
  cp "$REPO_ROOT/labs/day-1/00-setup.md" "$root/labs/day-1/00-setup.md"
  cp "$REPO_ROOT/labs/day-1/00-setup/hello.tf" "$root/labs/day-1/00-setup/hello.tf"
  cp "$REPO_ROOT/labs/day-1/00-setup/bucket.tf" "$root/labs/day-1/00-setup/bucket.tf"
  cp "$REPO_ROOT/labs/day-2/13-static-analysis/messy/main.tf" \
    "$root/labs/day-2/13-static-analysis/messy/main.tf"
  cp "$REPO_ROOT/setup/localstack.md" "$root/setup/localstack.md"
  cp "$REPO_ROOT/docs/decisions/README.md" "$root/docs/decisions/README.md"
  mkdir -p "$root/test-bin"
  for tool in tflint trivy checkov conftest terramate; do
    printf '#!/bin/sh\nexit 127\n' >"$root/test-bin/$tool"
    chmod +x "$root/test-bin/$tool"
  done
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
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
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

m_tier_mismatch() {  # section 7 (a): make S05's tier differ between the two decks
  local root="$1"    # mutate the SUPERSET deck only → deck↔deck identity breaks
  perl -pi -e 's/^# S05 · State encryption · core · Day 1$/# S05 · State encryption · recommended · Day 1/' \
    "$root/slides.md"
}

m_hide_violation() { # section 7 (b): optional section left visible in the 3-day cut
  local root="$1"    # S18 is optional → its hide flag must be true; force false
  perl -0pi -e 's/(# S18 · [^\n]*\n(?:src:[^\n]*\n)?hide: )true/${1}false/' \
    "$root/slides-3day.md"
}

m_missing_lab_route() {
  local root="$1"
  rm "$root/labs/day-1/00-setup.md"
}

m_unknown_readme_task() {
  local root="$1"
  perl -pi -e 's/task dev:3day/task dev:ghost/' "$root/README.md"
}

m_unformatted_outside_allowlist() {
  local root="$1"
  mkdir -p "$root/modules/unformatted-regression"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/modules/unformatted-regression/main.tf"
}

m_unformatted_beside_fixture() {
  local root="$1"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/labs/day-2/13-static-analysis/messy/adjacent.tf"
}

run_case "clean fixture"        pass "no drift: labs/fixtures/drift-demo/main.tf matches" m_clean
run_case "LF-authored drift"    fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_lf
run_case "CRLF-authored drift"  fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_crlf
run_case "cross-deck tier mismatch (S05)" fail "tier drift: S05 is 'recommended' in slides.md but 'core' in slides-3day.md" m_tier_mismatch
run_case "hide-invariant violation (S18)" fail "hide invariant: S18 is 'optional' but hide='false' in slides-3day.md" m_hide_violation
run_case "README navigation contract" pass "README navigation contract" m_clean
run_case "deleted README route" fail "README route 'Lab 00' is missing: labs/day-1/00-setup.md" m_missing_lab_route
run_case "unknown README task" fail "README task command does not exist: task dev:ghost" m_unknown_readme_task
run_case "missing Day-2/3 tool skips" pass "tflint unavailable — skipping tool-dependent checks for S13 static analysis" m_clean
run_case "exact S13 messy fixture allowlisted" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_clean
run_case "adjacent S13 file is not allowlisted" fail "labs/day-2/13-static-analysis/messy/adjacent.tf" m_unformatted_beside_fixture
run_case "unformatted file outside allowlist" fail "modules/unformatted-regression/main.tf" m_unformatted_outside_allowlist

printf '\n'
if [ "$fail_n" -eq 0 ]; then
  printf '  enforcement self-test PASSED — %d/%d cases OK.\n' "$pass_n" "$pass_n"
  exit 0
else
  printf '  enforcement self-test FAILED — %d case(s) failed, %d OK.\n' "$fail_n" "$pass_n"
  exit 1
fi
