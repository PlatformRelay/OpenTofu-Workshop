#!/usr/bin/env bash
# scripts/verify.sh — the "tested workshop" gate.
#
# Unit lane (no Docker needed):
#   1. deps preflight (tofu present, version)
#   2. tofu fmt -check -recursive
#   3. per module/example that has *.tf: tofu init -backend=false + validate
#   4. per module/example that has *.tftest.hcl: tofu test (plan/mock lanes)
#   5. slide ↔ lab drift smoke check (fenced ```hcl blocks in labs → real files)
#
# Everything degrades to "nothing to check yet → pass" while the content dirs
# are empty, so this is safe to wire into CI from day one.
#
# Exit non-zero on any failure. Prints a clear pass/fail summary.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Reuse styling helpers if available; otherwise define minimal fallbacks.
if [ -f "$REPO_ROOT/setup/lib.sh" ]; then
  # shellcheck source=setup/lib.sh
  . "$REPO_ROOT/setup/lib.sh"
else
  have() { command -v "$1" >/dev/null 2>&1; }
  ok()   { printf '  [OK]   %s\n' "$*"; }
  bad()  { printf '  [FAIL] %s\n' "$*"; }
  warn() { printf '  [warn] %s\n' "$*"; }
  info() { printf '  [ .. ] %s\n' "$*"; }
  heading() { printf '\n== %s ==\n' "$*"; }
  title() { printf '\n### %s ###\n' "$*"; }
fi

FAILURES=0
CHECKS=0
fail() { bad "$*"; FAILURES=$((FAILURES + 1)); }
pass() { ok "$*"; CHECKS=$((CHECKS + 1)); }

title "OpenTofu Workshop · verify (unit lane)"

# ---------------------------------------------------------------------------
# 1. Deps preflight
# ---------------------------------------------------------------------------
heading "Preflight"
if have tofu; then
  TOFU_VER="$(tofu version 2>/dev/null | head -n1 | awk '{print $2}')"
  if min_version "${TOFU_VER#v}" "1.8"; then
    pass "tofu ${TOFU_VER} (>= 1.8)"
  else
    fail "tofu ${TOFU_VER} is below the required 1.8"
  fi
else
  fail "tofu not found on PATH (install: brew install opentofu)"
  heading "Summary"
  bad "verify FAILED — tofu is required. $FAILURES failure(s)."
  exit 1
fi

# Collect module/example dirs that actually contain Terraform/OpenTofu code.
# nullglob makes empty globs vanish instead of expanding to a literal '*'.
shopt -s nullglob
CODE_DIRS=()
for base in modules examples; do
  for d in "$base"/*/; do
    [ -d "$d" ] || continue
    # any .tf at the top of the dir counts as a config
    tf=("$d"*.tf)
    [ "${#tf[@]}" -gt 0 ] && CODE_DIRS+=("${d%/}")
  done
done
shopt -u nullglob

# ---------------------------------------------------------------------------
# 2. fmt -check (repo-wide; harmless on an empty tree)
# ---------------------------------------------------------------------------
heading "Formatting (tofu fmt -check -recursive)"
if tofu fmt -check -recursive >/dev/null 2>&1; then
  pass "all .tf files are canonically formatted"
else
  fail "unformatted files found — run 'task lab:fmt' (tofu fmt -recursive)"
  info "offending files:"
  tofu fmt -check -recursive 2>/dev/null | sed 's/^/    /' || true
fi

# ---------------------------------------------------------------------------
# 3 & 4. validate + test per code dir
# ---------------------------------------------------------------------------
heading "Validate & test"
if [ "${#CODE_DIRS[@]}" -eq 0 ]; then
  warn "no modules/* or examples/* with .tf files yet — nothing to validate."
  info "This is expected before lab content is authored. (pass)"
else
  for d in "${CODE_DIRS[@]}"; do
    info "→ $d"
    # init without a backend so validate has its providers, no remote state.
    if tofu -chdir="$d" init -backend=false -input=false >/dev/null 2>&1; then
      if tofu -chdir="$d" validate -no-color >/dev/null 2>&1; then
        pass "$d: validate"
      else
        fail "$d: validate"
        tofu -chdir="$d" validate -no-color 2>&1 | sed 's/^/    /' || true
      fi
    else
      fail "$d: init failed (cannot validate)"
    fi

    # tofu test if the dir (or its tests/ subdir) ships *.tftest.hcl.
    # UNIT LANE ONLY: integration files (…integration….tftest.hcl) need
    # LocalStack/Docker and belong to `task verify:integration` — exclude them
    # here and run each remaining file explicitly with -filter.
    shopt -s nullglob
    tests=("$d"/*.tftest.hcl "$d"/tests/*.tftest.hcl)
    shopt -u nullglob
    unit_filters=()
    skipped_integration=0
    for t in "${tests[@]}"; do
      case "$t" in
        *integration*.tftest.hcl) skipped_integration=$((skipped_integration + 1)) ;;
        *) unit_filters+=("-filter=${t#"$d"/}") ;;  # path relative to -chdir
      esac
    done
    if [ "${#unit_filters[@]}" -gt 0 ]; then
      if tofu -chdir="$d" test "${unit_filters[@]}" >/dev/null 2>&1; then
        pass "$d: tofu test (plan/mock)"
      else
        fail "$d: tofu test"
        tofu -chdir="$d" test "${unit_filters[@]}" 2>&1 | sed 's/^/    /' | tail -n 30 || true
      fi
    elif [ "${#tests[@]}" -gt 0 ]; then
      info "$d: only integration test(s) — deferred to verify:integration"
    else
      info "$d: no *.tftest.hcl — skipping tofu test"
    fi
    [ "$skipped_integration" -gt 0 ] && info "$d: skipped ${skipped_integration} integration file(s) (unit lane)"
  done
fi

# ---------------------------------------------------------------------------
# 5. Slide ↔ lab drift smoke check
#    Labs mix two kinds of HCL:
#      (a) learner-scratch snippets (files the learner creates, e.g. bucket.tf)
#          and inline teaching blocks — these are NOT expected to exist in-repo.
#      (b) references to SHARED repo code under modules/ or examples/ — these
#          MUST exist on disk, or a slide has drifted from runnable source.
#    We assert (b) and merely report (a), so the check is real but never fails
#    on legitimate scratch/inline HCL.
# ---------------------------------------------------------------------------
heading "Slide ↔ lab drift smoke check"
shopt -s nullglob globstar
LAB_FILES=(labs/**/*.md)
shopt -u nullglob globstar
if [ "${#LAB_FILES[@]}" -eq 0 ]; then
  warn "no lab Markdown under labs/ yet — drift check is a no-op. (pass)"
  info "TODO: once labs exist, assert each modules/|examples/ path they cite exists."
else
  HCL_BLOCKS=0
  MISSING_REFS=0
  CHECKED_REFS=0
  for f in "${LAB_FILES[@]}"; do
    n="$(grep -c '^```hcl' "$f" 2>/dev/null || true)"
    HCL_BLOCKS=$((HCL_BLOCKS + ${n:-0}))
    # Extract every modules/... or examples/... path the lab references and
    # assert it exists (strip trailing punctuation/backticks the grep may grab).
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      ref="${ref%%[\`\"\')]*}"
      CHECKED_REFS=$((CHECKED_REFS + 1))
      if [ -e "$ref" ]; then
        pass "lab ref exists: $ref  ($(basename "$f"))"
      else
        fail "lab ref missing on disk: $ref  (cited in $f)"
        MISSING_REFS=$((MISSING_REFS + 1))
      fi
    done < <(grep -roE '(modules|examples)/[A-Za-z0-9_./-]+' "$f" 2>/dev/null | sort -u)
  done
  info "scanned ${#LAB_FILES[@]} lab file(s): ${HCL_BLOCKS} \`\`\`hcl block(s), ${CHECKED_REFS} shared-code reference(s)"
  if [ "$CHECKED_REFS" -eq 0 ]; then
    info "no modules/|examples/ references in labs (all HCL is scratch/inline) — nothing to drift-check yet"
  elif [ "$MISSING_REFS" -eq 0 ]; then
    pass "all shared-code references cited by labs exist on disk"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
heading "Summary"
if [ "$FAILURES" -eq 0 ]; then
  ok "verify PASSED — $CHECKS check(s) OK, 0 failures."
  exit 0
else
  bad "verify FAILED — $FAILURES failure(s) across $((CHECKS + FAILURES)) check(s)."
  exit 1
fi
