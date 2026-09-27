#!/usr/bin/env bash
# variant/ovh/scripts/verify.sh — the OVH variant unit lane.
#
# Offline by design (no Docker, no OVH access, no secrets):
#   1. OVH provider pin drift — variant/ovh/bootstrap/versions.tf must restate
#      OVH_PROVIDER_VERSION from versions.env (the repo's pin SSoT).
#   2. tofu fmt -check over every tracked variant .tf.
#   3. per discovered root (any dir under variant/ovh/ holding .tf):
#      tofu init -backend=false + tofu validate.
#   4. tofu test (plan/mock) for each unit *.tftest.hcl; *integration*.tftest.hcl
#      is deferred to the real-OVH lane (not wired in CI).
#   5. base <-> twin drift: files a twin copies verbatim stay byte-identical to
#      their base, the twin go.mod equals the base one except its module line,
#      and two design invariants hold (no committed state_passphrase default;
#      every hashicorp/aws constraint in the variant stays < 6.0).
#
# "Scanned nothing" is a failure, never a pass: an empty .tf list or root list
# means discovery broke, not that the variant is clean.
#
# The base scripts/verify.sh deliberately does not scan variant/ (its discovery
# globs are labs|modules|examples), which is what keeps the base gates inert;
# this is the variant's own equivalent. Base `tofu fmt -check` and shellcheck
# ARE index-wide and cover the variant too — that is expected, not a surprise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

FAILURES=0
CHECKS=0
ok()   { printf '  [OK]   %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; }
info() { printf '  [ .. ] %s\n' "$*"; }
fail() { bad "$*"; FAILURES=$((FAILURES + 1)); }
pass() { ok "$*"; CHECKS=$((CHECKS + 1)); }

# ovh_pin <file> — print the right-hand side of the first `version = ...`
# assignment inside an `ovh = { ... }` block (quotes kept, trailing comment
# dropped). Anchored to the assignment on purpose: a `~> X` that only appears
# in a comment, or outside the ovh block, must not satisfy the pin check.
ovh_pin() {
  awk '
    /^[[:space:]]*ovh[[:space:]]*=[[:space:]]*\{/ { inblk = 1; next }
    inblk && /^[[:space:]]*\}/ { inblk = 0 }
    inblk && /^[[:space:]]*version[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); print; exit
    }
  ' "$1" 2>/dev/null
}

# aws_pins <file> — print one `file<TAB>constraint` line per `aws = { ... }`
# block whose source is hashicorp/aws.
aws_pins() {
  awk -v f="$1" '
    /^[[:space:]]*aws[[:space:]]*=[[:space:]]*\{/ { inblk = 1; src = ""; ver = ""; next }
    inblk && /^[[:space:]]*source[[:space:]]*=/ { src = $0 }
    inblk && /^[[:space:]]*version[[:space:]]*=/ {
      ver = $0; sub(/^[^=]*=[[:space:]]*/, "", ver); sub(/[[:space:]]*#.*$/, "", ver)
    }
    inblk && /^[[:space:]]*\}/ {
      inblk = 0
      if (src ~ /"hashicorp\/aws"/) print f "\t" ver
    }
  ' "$1" 2>/dev/null
}

# passphrase_default <file> — print the file name when a
# `variable "state_passphrase"` block carries a top-level `default`.
passphrase_default() {
  awk -v f="$1" '
    /^[[:space:]]*variable[[:space:]]+"state_passphrase"[[:space:]]*\{/ { inblk = 1; depth = 0 }
    inblk {
      line = $0; sub(/#.*$/, "", line)
      if (depth == 1 && line ~ /^[[:space:]]*default[[:space:]]*=/) { print f; exit }
      o = gsub(/\{/, "{", line); c = gsub(/\}/, "}", line)
      depth += o - c
      if (depth <= 0) inblk = 0
    }
  ' "$1" 2>/dev/null
}

printf '\n== OVH variant unit lane ==\n'

if ! command -v tofu >/dev/null 2>&1; then
  fail "tofu not found on PATH (install: brew install opentofu)"
  printf '\nOVH variant verify FAILED — tofu is required.\n'
  exit 1
fi

# --- 1. OVH provider pin drift ----------------------------------------------
printf '\n-- OVH provider pin --\n'
if [ ! -f "$REPO_ROOT/versions.env" ]; then
  fail "versions.env is missing"
else
  # shellcheck source=/dev/null
  . "$REPO_ROOT/versions.env"
  if [ -z "${OVH_PROVIDER_VERSION:-}" ]; then
    fail "versions.env does not define OVH_PROVIDER_VERSION"
  elif [ "$(ovh_pin "$REPO_ROOT/variant/ovh/bootstrap/versions.tf")" != "\"~> ${OVH_PROVIDER_VERSION}\"" ]; then
    fail "pin drift: variant/ovh/bootstrap/versions.tf does not restate OVH_PROVIDER_VERSION=${OVH_PROVIDER_VERSION} as the ovh block's version = \"~> ${OVH_PROVIDER_VERSION}\""
  else
    pass "OVH provider pin: bootstrap/versions.tf restates ${OVH_PROVIDER_VERSION}"
  fi
fi

# --- collect tracked variant .tf --------------------------------------------
FMT_FILES=()
if command -v git >/dev/null 2>&1 && [ -e "$REPO_ROOT/.git" ]; then
  while IFS= read -r tf; do
    [ -n "$tf" ] || continue
    [ -f "$tf" ] || continue
    FMT_FILES+=("$tf")
  # `:(glob)` is load-bearing: without it git's non-pathname wildmatch makes
  # `**` degenerate to `*`, which cannot match ZERO path segments — so a future
  # root at variant/ovh/foo.tf would be listed by find but not by git, and its
  # .tf would silently drop out of both fmt and root discovery. The base
  # repo's §10 documents the same lesson.
  done < <(git ls-files ':(glob)variant/ovh/**/*.tf')
  info "discovery: git index (tracked variant .tf only)"
else
  info "discovery: find (no git index)"
  while IFS= read -r -d '' tf; do
    FMT_FILES+=("${tf#./}")
  done < <(find variant/ovh -type f -name '*.tf' ! -path '*/.terraform/*' -print0)
fi

# --- 2. fmt -----------------------------------------------------------------
printf '\n-- fmt --\n'
if [ "${#FMT_FILES[@]}" -eq 0 ]; then
  fail "scanned nothing: no variant .tf files discovered under variant/ovh — discovery is broken"
elif tofu fmt -check "${FMT_FILES[@]}" >/dev/null 2>&1; then
  pass "all variant .tf files are canonically formatted"
else
  fail "unformatted variant .tf files found — run 'tofu fmt' on them"
  tofu fmt -check "${FMT_FILES[@]}" 2>/dev/null || true
fi

# --- discover roots (unique dirs holding .tf) -------------------------------
ROOTS=()
declare -A SEEN=()
for tf in "${FMT_FILES[@]}"; do
  d="${tf%/*}"
  [ -n "${SEEN[$d]+set}" ] && continue
  SEEN["$d"]=1
  ROOTS+=("$d")
done

# --- 3 & 4. validate + unit test --------------------------------------------
printf '\n-- validate & test --\n'
if [ "${#ROOTS[@]}" -eq 0 ]; then
  fail "scanned nothing: no variant roots discovered — nothing was validated or tested"
else
  for d in "${ROOTS[@]}"; do
    info "-> $d"
    if ! tofu -chdir="$d" init -backend=false -input=false >/dev/null 2>&1; then
      fail "$d: init failed"
      tofu -chdir="$d" init -backend=false -input=false 2>&1 | tail -n 15 || true
      continue
    fi
    if tofu -chdir="$d" validate -no-color >/dev/null 2>&1; then
      pass "$d: validate"
    else
      fail "$d: validate"
      tofu -chdir="$d" validate -no-color 2>&1 | tail -n 20 || true
      continue
    fi

    tests=()
    for t in "$d"/*.tftest.hcl "$d"/tests/*.tftest.hcl; do
      [ -e "$t" ] || continue
      case "$t" in *integration*.tftest.hcl) continue ;; esac
      tests+=("-filter=${t#"$d"/}")
    done
    if [ "${#tests[@]}" -gt 0 ]; then
      if tofu -chdir="$d" test "${tests[@]}" >/dev/null 2>&1; then
        pass "$d: tofu test (mock/plan)"
      else
        fail "$d: tofu test"
        tofu -chdir="$d" test "${tests[@]}" 2>&1 | tail -n 30 || true
      fi
    else
      info "$d: no unit *.tftest.hcl — skipping tofu test"
    fi
  done
fi

# --- 5. base <-> twin drift ------------------------------------------------
# Data-driven on purpose: add a pair here when a twin starts copying a base file.
# `base|twin`, paths relative to the repo root.
VERBATIM_PAIRS=(
  "labs/day-1/00-setup/hello.tf|variant/ovh/labs/day-1/00-setup/hello.tf"
  "labs/day-1/00-setup/stretch.tf|variant/ovh/labs/day-1/00-setup/stretch.tf"
  "labs/day-2/18-terratest-cost/go.sum|variant/ovh/labs/day-2/18-terratest-cost/go.sum"
)
# go.mod pairs: identical except the `module` line (the twin's module path
# names its own directory).
GOMOD_PAIRS=(
  "labs/day-2/18-terratest-cost/go.mod|variant/ovh/labs/day-2/18-terratest-cost/go.mod"
)

printf '\n-- base <-> twin drift --\n'
for pair in "${VERBATIM_PAIRS[@]}"; do
  b="${pair%%|*}"; t="${pair##*|}"
  if [ ! -f "$b" ] || [ ! -f "$t" ]; then
    fail "twin drift: pair $b <-> $t — a side is missing"
  elif cmp -s "$b" "$t"; then
    pass "twin verbatim: $t == $b"
  else
    fail "twin drift: $t is no longer byte-identical to $b — re-copy it, or drop the pair if the twin now deliberately differs"
  fi
done
for pair in "${GOMOD_PAIRS[@]}"; do
  b="${pair%%|*}"; t="${pair##*|}"
  if [ ! -f "$b" ] || [ ! -f "$t" ]; then
    fail "twin drift: pair $b <-> $t — a side is missing"
  elif diff -q <(grep -v '^module ' "$b") <(grep -v '^module ' "$t") >/dev/null; then
    pass "twin go.mod: $t == $b (module line aside)"
  else
    fail "twin drift: $t differs from $b beyond the module line — bump the twin with the base"
    diff <(grep -v '^module ' "$b") <(grep -v '^module ' "$t") | sed 's/^/      /' || true
  fi
done

printf '\n-- variant invariants --\n'
pp_defaults=""
aws_lines=""
for tf in ${FMT_FILES[@]+"${FMT_FILES[@]}"}; do
  pp_defaults+="$(passphrase_default "$tf")"$'\n'
  aws_lines+="$(aws_pins "$tf")"$'\n'
done
pp_defaults="$(printf '%s' "$pp_defaults" | grep -v '^$' || true)"
aws_lines="$(printf '%s' "$aws_lines" | grep -v '^$' || true)"
if [ -n "$pp_defaults" ]; then
  while IFS= read -r f; do
    fail "invariant: $f gives state_passphrase a default — a committed passphrase is no secret; supply TF_VAR_state_passphrase"
  done <<<"$pp_defaults"
else
  pass "invariant: no state_passphrase default in the variant"
fi
if [ -z "$aws_lines" ]; then
  fail "invariant: scanned nothing — no hashicorp/aws constraint found in the variant"
else
  aws_bad=0
  while IFS=$'\t' read -r f ver; do
    case "$ver" in
      *"< 6.0"*) ;;
      *)
        fail "invariant: $f constrains hashicorp/aws to $ver — the variant must stay < 6.0 (the family the base labs verified)"
        aws_bad=1
        ;;
    esac
  done <<<"$aws_lines"
  if [ "$aws_bad" -eq 0 ]; then
    pass "invariant: every hashicorp/aws constraint in the variant stays < 6.0 ($(printf '%s\n' "$aws_lines" | grep -c .) block(s))"
  fi
fi

printf '\n== OVH variant verify summary ==\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '  [OK]   OVH variant verify PASSED — %d check(s) OK, 0 failures.\n' "$CHECKS"
  exit 0
fi
printf '  [FAIL] OVH variant verify FAILED — %d failure(s).\n' "$FAILURES"
exit 1
