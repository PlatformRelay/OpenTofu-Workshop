#!/usr/bin/env bash
# scripts/verify-selftest.sh — regression protection for three ENFORCEMENT gates in
# scripts/verify.sh: (A) slide↔lab/pages drift enforcement (section 6), (B) deck tier
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
#     4. pages/ magic-move clean → exit 0 AND "…matches its block in index.md"
#        (fence metadata ```hcl {none|…}``` tolerated; pages/** scan ARMED)
#     5. pages/ LF drift → exit !=0 AND pages/…/index.md named
#     6. pages/ CRLF drift → exit !=0 AND pages/…/index.md named   (F1 on pages)
#   tier gate (section 7):
#     7. cross-deck tier mismatch → exit !=0 AND "tier drift: S05 …"   (deck↔deck)
#     8. hide-invariant violation → exit !=0 AND "hide invariant: S18 …" (3-day cut)
#   README navigation gate (section 8):
#     9. clean routes → exit 0 AND "README navigation contract"
#    10. deleted route → exit !=0 AND the route label + path
#    11. unknown task → exit !=0 AND the command name
#   Day-2/3 tool contract (section 9):
#    12. broken/absent tool → exit 0 AND an explicit affected-lab skip warning
#   formatting allowlist contract (section 2):
#    13. exact S13 messy fixture → exit 0 AND formatting gate remains armed
#    14. another unformatted .tf beside the fixture → exit !=0 AND path is named
#    15. any other unformatted .tf → exit !=0 AND offending path is named
#    16. unformatted .tf under .claude/worktrees/ → exit 0 (ignored; no false fail)
#    17. unformatted .tf under node_modules/ → exit 0 (ignored)
#    18. unformatted .tf under */.terraform/ → exit 0 (ignored)
#   day-2 lab tftest discovery (TEST-A2 / section 3–4 CODE_DIRS):
#    19. planted labs/day-2/*/tests/*.tftest.hcl → exit 0 AND "…: tofu test (plan/mock)"
#    20. broken lab unit assert → exit !=0 AND the lab path named (discovery ARMED)
#    21. lab with only *integration*.tftest.hcl → exit 0 AND deferred message (unit skip)
#   §5 smoke-check scope (US-F-R4):
#    22. prose mentioning modules/does-not-exist → exit 0 (NOT a shared-code ref)
#    23. missing path in HCL source = "…modules/…" → exit !=0 AND path named (ARMED)
#    24. missing examples/… via -chdir=/cd/DIR= → exit !=0 AND path named (ARMED)
#
# It NEVER mutates the tracked fixture or decks; all edits happen in the temp copy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FIXTURE_MD="labs/fixtures/drift-demo.md"
FIXTURE_TF="labs/fixtures/drift-demo/main.tf"
# Temp-only pages fixture (not tracked): proves section 6 also scans pages/**
# and tolerates magic-move fence metadata. Points at the same drift-demo .tf.
PAGES_FIXTURE_MD="pages/S99-drift-selftest/index.md"

pass_n=0
fail_n=0
note() { printf '  [selftest] %s\n' "$*"; }
ok()   { printf '  [ OK ] %s\n' "$*"; pass_n=$((pass_n + 1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; fail_n=$((fail_n + 1)); }

command -v tofu >/dev/null 2>&1 || { echo "selftest: tofu required" >&2; exit 1; }

printf '\n### verify.sh enforcement self-test (drift + tier + README navigation) ###\n'

# Plant a pages/** annotated HCL block with a magic-move fence. Body must stay
# byte-identical to FIXTURE_TF (minus trailing newline handling in verify.sh).
plant_pages_fixture() {
  local root="$1"
  mkdir -p "$(dirname "$root/$PAGES_FIXTURE_MD")"
  {
    printf '%s\n' '# Temp pages drift fixture (self-test only)'
    printf '%s\n' ''
    printf '%s\n' "<!-- source: $FIXTURE_TF -->"
    # Magic-move metadata MUST be tolerated on the fence line (US-X-DRIFT2).
    printf '%s\n' '```hcl {none|1-3|all}'
    # FIXTURE_TF already ends with a trailing newline — do not add another.
    cat "$root/$FIXTURE_TF"
    printf '%s\n' '```'
  } >"$root/$PAGES_FIXTURE_MD"
}

# Build an isolated temp repo root with only what verify.sh needs. Includes the
# two content decks so section 7 (tier consistency) has inputs; verify.sh reads
# them by literal path relative to REPO_ROOT.
build_root() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/setup" "$root/labs/fixtures/drift-demo" \
    "$root/labs/day-1/00-setup" "$root/labs/day-2/13-static-analysis/messy" \
    "$root/docs/decisions" "$root/pages/S99-drift-selftest"
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
  plant_pages_fixture "$root"
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

m_pages_clean() { :; }   # pages fixture already planted matching + magic-move fence

m_pages_drift_lf() {     # drift ONLY the pages block body — labs fixture stays clean
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_PAGES_LF/' "$root/$PAGES_FIXTURE_MD"
}

m_pages_drift_crlf() {   # pages body drift + CRLF-authored pages md (F1 on pages/)
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_PAGES_CRLF/' "$root/$PAGES_FIXTURE_MD"
  perl -pi -e 's/\n/\r\n/' "$root/$PAGES_FIXTURE_MD"
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

# Plant deliberately unformatted .tf under paths that must NOT poison fmt -check
# (agent worktrees, package installs, provider caches).
m_unformatted_under_claude_worktree() {
  local root="$1"
  mkdir -p "$root/.claude/worktrees/fake-lane/labs/day-2/13-static-analysis/messy"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/.claude/worktrees/fake-lane/labs/day-2/13-static-analysis/messy/main.tf"
}

m_unformatted_under_node_modules() {
  local root="$1"
  mkdir -p "$root/node_modules/some-pkg"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/node_modules/some-pkg/main.tf"
}

m_unformatted_under_dot_terraform() {
  local root="$1"
  mkdir -p "$root/modules/example/.terraform/providers"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/modules/example/.terraform/providers/cached.tf"
}

# Minimal provider-free day-2 lab with a plan-only unit suite — proves CODE_DIRS
# discovery includes labs/day-2/** that ship *.tftest.hcl (TEST-A2).
LAB_TFTTEST_DIR="labs/day-2/99-lab-tftest-selftest"
plant_lab_unit_tftest() {
  local root="$1"
  mkdir -p "$root/$LAB_TFTTEST_DIR/tests"
  cat >"$root/$LAB_TFTTEST_DIR/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.8"
}

locals {
  marker = "lab-unit-ok"
}

output "marker" {
  value = local.marker
}
EOF
  cat >"$root/$LAB_TFTTEST_DIR/tests/unit.tftest.hcl" <<'EOF'
run "lab_unit_plan" {
  command = plan

  assert {
    condition     = output.marker == "lab-unit-ok"
    error_message = "expected lab-unit-ok"
  }
}
EOF
}

m_lab_tftest_clean() {
  plant_lab_unit_tftest "$1"
}

m_lab_tftest_fail() {
  local root="$1"
  plant_lab_unit_tftest "$root"
  perl -pi -e 's/lab-unit-ok/lab-unit-BROKEN/' \
    "$root/$LAB_TFTTEST_DIR/tests/unit.tftest.hcl"
}

m_lab_integration_only() {
  local root="$1"
  mkdir -p "$root/$LAB_TFTTEST_DIR/tests"
  # Provider-free stub: init must still parse the integration suite (tofu
  # validates assert expressions at init), so the condition references config.
  cat >"$root/$LAB_TFTTEST_DIR/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.8"
}

locals {
  marker = "integration-only"
}

output "marker" {
  value = local.marker
}
EOF
  # Apply-style name only — unit lane must skip without requiring LocalStack.
  cat >"$root/$LAB_TFTTEST_DIR/tests/integration.tftest.hcl" <<'EOF'
run "would_need_localstack" {
  command = apply

  assert {
    condition     = output.marker == "integration-only"
    error_message = "unreachable in unit lane"
  }
}
EOF
}

# §5: illustrative prose must not invent a hard-fail shared-code ref (US-F-R4).
m_smoke_prose_fake_module() {
  local root="$1"
  mkdir -p "$root/labs/day-1"
  cat >>"$root/labs/day-1/00-setup.md" <<'EOF'

## Illustrative (self-test only)

See `modules/does-not-exist` — teaching prose, not a `source =` dependency.
EOF
}

# §5: a real HCL source = "…modules/…" path that is missing on disk must still fail.
m_smoke_hcl_missing_source() {
  local root="$1"
  mkdir -p "$root/labs/day-1"
  cat >>"$root/labs/day-1/00-setup.md" <<'EOF'

## Broken shared ref (self-test only)

```hcl
module "ghost" {
  source = "./modules/does-not-exist"
}
```
EOF
}

# §5: shell entrypoints (-chdir=/cd/DIR=) citing a missing shared root must fail.
m_smoke_chdir_missing_example() {
  local root="$1"
  mkdir -p "$root/labs/day-1"
  cat >>"$root/labs/day-1/00-setup.md" <<'EOF'

## Broken shell entrypoint (self-test only)

cd examples/does-not-exist
tofu -chdir=examples/does-not-exist init -backend=false
task lab:apply DIR=examples/does-not-exist
EOF
}

run_case "clean fixture"        pass "no drift: labs/fixtures/drift-demo/main.tf matches" m_clean
run_case "LF-authored drift"    fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_lf
run_case "CRLF-authored drift"  fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_crlf
run_case "pages magic-move clean" pass "no drift: labs/fixtures/drift-demo/main.tf matches its block in index.md" m_pages_clean
run_case "pages LF-authored drift" fail "drift: block in pages/S99-drift-selftest/index.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_pages_drift_lf
run_case "pages CRLF-authored drift" fail "drift: block in pages/S99-drift-selftest/index.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_pages_drift_crlf
run_case "cross-deck tier mismatch (S05)" fail "tier drift: S05 is 'recommended' in slides.md but 'core' in slides-3day.md" m_tier_mismatch
run_case "hide-invariant violation (S18)" fail "hide invariant: S18 is 'optional' but hide='false' in slides-3day.md" m_hide_violation
run_case "README navigation contract" pass "README navigation contract" m_clean
run_case "deleted README route" fail "README route 'Lab 00' is missing: labs/day-1/00-setup.md" m_missing_lab_route
run_case "unknown README task" fail "README task command does not exist: task dev:ghost" m_unknown_readme_task
run_case "missing Day-2/3 tool skips" pass "tflint unavailable — skipping tool-dependent checks for S13 static analysis" m_clean
run_case "exact S13 messy fixture allowlisted" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_clean
run_case "adjacent S13 file is not allowlisted" fail "labs/day-2/13-static-analysis/messy/adjacent.tf" m_unformatted_beside_fixture
run_case "unformatted file outside allowlist" fail "modules/unformatted-regression/main.tf" m_unformatted_outside_allowlist
run_case "unformatted under .claude/worktrees ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_unformatted_under_claude_worktree
run_case "unformatted under node_modules ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_unformatted_under_node_modules
run_case "unformatted under .terraform ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_unformatted_under_dot_terraform
run_case "day-2 lab unit tftest gated" pass "labs/day-2/99-lab-tftest-selftest: tofu test (plan/mock)" m_lab_tftest_clean
run_case "day-2 lab unit tftest failure armed" fail "labs/day-2/99-lab-tftest-selftest: tofu test" m_lab_tftest_fail
run_case "day-2 lab integration tftest deferred" pass "labs/day-2/99-lab-tftest-selftest: only integration test(s) — deferred to task verify:integration / CI verify-integration" m_lab_integration_only
run_case "§5 prose fake module ref ignored" pass "no modules/|examples/ references in labs (all HCL is scratch/inline) — nothing to drift-check yet" m_smoke_prose_fake_module
run_case "§5 HCL source missing module armed" fail "lab ref missing on disk: modules/does-not-exist" m_smoke_hcl_missing_source
run_case "§5 chdir/cd/DIR missing example armed" fail "lab ref missing on disk: examples/does-not-exist" m_smoke_chdir_missing_example

printf '\n'
if [ "$fail_n" -eq 0 ]; then
  printf '  enforcement self-test PASSED — %d/%d cases OK.\n' "$pass_n" "$pass_n"
  exit 0
else
  printf '  enforcement self-test FAILED — %d case(s) failed, %d OK.\n' "$fail_n" "$pass_n"
  exit 1
fi
