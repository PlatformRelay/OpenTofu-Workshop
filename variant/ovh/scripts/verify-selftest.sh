#!/usr/bin/env bash
# variant/ovh/scripts/verify-selftest.sh — regression protection for the OVH
# variant unit lane (variant/ovh/scripts/verify.sh).
#
# It copies the live variant verify.sh into a throwaway temp root (so the copy
# auto-isolates: verify.sh derives its repo root from its own location) and
# plants provider-free fixtures, then asserts each case BOTH exits as expected
# AND names the thing it caught. Provider-free by design: no `tofu init` here
# downloads a provider, so the self-test stays fast and offline.
#
#   clean                 → exit 0  AND  "OVH variant verify PASSED"
#   clean, git index mode → exit 0  (the `git ls-files` discovery branch)
#   pin drift             → exit !=0 AND "pin drift"
#   pin only in a comment → exit !=0 AND "pin drift"
#   validate broken       → exit !=0 AND the root named + ": validate"
#   unformatted           → exit !=0 AND "unformatted variant .tf"
#   no variant .tf        → exit !=0 AND "scanned nothing"
#   verbatim twin drift   → exit !=0 AND the drifted pair named
#   go.mod twin drift     → exit !=0 AND the drifted go.mod named
#   passphrase default    → exit !=0 AND "gives state_passphrase a default"
#   aws >= 6 constraint   → exit !=0 AND "must stay < 6.0"
#
# The second half self-tests variant/ovh/scripts/teardown.sh with a stub `tofu`
# on PATH and fake state files (no provider, no network, nothing destroyed).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SELFTEST_TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$SELFTEST_TMP_ROOT"' EXIT

FAILURES=0

build_root() {
  local root="$1"
  mkdir -p "$root/variant/ovh/scripts" \
    "$root/variant/ovh/bootstrap" \
    "$root/variant/ovh/labs/day-1/00-setup" \
    "$root/variant/ovh/labs/day-2/18-terratest-cost" \
    "$root/labs/day-1/00-setup" \
    "$root/labs/day-2/18-terratest-cost"
  cp "$REPO_ROOT/variant/ovh/scripts/verify.sh" "$root/variant/ovh/scripts/verify.sh"
  printf 'OVH_PROVIDER_VERSION=9.9.9\n' >"$root/versions.env"
  # Provider-free on purpose: the pin and invariant checks read HCL text, so
  # the fixture carries the same `ovh = { ... }` / `aws = { ... }` shapes inside
  # a `locals` block, where init needs no network. The real bootstrap root's
  # provider declaration is covered by the live `task ovh:verify`, not here.
  cat >"$root/variant/ovh/bootstrap/versions.tf" <<'HCL'
terraform {
  required_version = ">= 1.9"
}

locals {
  ovh = {
    source  = "ovh/ovh"
    version = "~> 9.9.9"
  }
}
HCL
  cat >"$root/variant/ovh/labs/day-1/00-setup/main.tf" <<'HCL'
terraform {
  required_version = ">= 1.9"
}

locals {
  aws = {
    source  = "hashicorp/aws"
    version = ">= 5.0, < 6.0"
  }
}

output "ok" {
  value = "yes"
}
HCL
  # Verbatim twin pairs (provider-free content; only equality matters).
  local f
  for f in hello.tf stretch.tf; do
    printf 'locals {\n  %s = "same"\n}\n' "${f%.tf}" >"$root/labs/day-1/00-setup/$f"
    cp "$root/labs/day-1/00-setup/$f" "$root/variant/ovh/labs/day-1/00-setup/$f"
  done
  printf 'example.com/dep v1.0.0 h1:abc=\n' >"$root/labs/day-2/18-terratest-cost/go.sum"
  cp "$root/labs/day-2/18-terratest-cost/go.sum" "$root/variant/ovh/labs/day-2/18-terratest-cost/go.sum"
  printf 'module example.com/base\n\ngo 1.25.0\n\nrequire example.com/dep v1.0.0\n' \
    >"$root/labs/day-2/18-terratest-cost/go.mod"
  printf 'module example.com/variant/twin\n\ngo 1.25.0\n\nrequire example.com/dep v1.0.0\n' \
    >"$root/variant/ovh/labs/day-2/18-terratest-cost/go.mod"
}

m_clean() { :; }

# The `git ls-files` discovery branch: a scratch index inside the fixture.
m_git_index() {
  ( cd "$1" && git init -q . && git add -A -f ) >/dev/null 2>&1
}

m_pin_drift() {
  sed -i.bak 's/~> 9.9.9/~> 8.8.8/' "$1/variant/ovh/bootstrap/versions.tf"
  rm -f "$1/variant/ovh/bootstrap/versions.tf.bak"
}

# The pin literal is present, but only in a comment: must not satisfy the check.
m_pin_in_comment() {
  printf 'terraform {\n  required_version = ">= 1.9"\n}\n\n# ovh provider pin: version = "~> 9.9.9"\n' \
    >"$1/variant/ovh/bootstrap/versions.tf"
}

m_validate_broken() {
  printf 'terraform {\n  required_version = ">= 1.9"\n}\n\noutput "bad" {\n  value = missing_resource.id\n}\n' \
    >"$1/variant/ovh/labs/day-1/00-setup/main.tf"
}

m_unformatted() {
  printf 'terraform {\nrequired_version = ">= 1.9"\n}\n' \
    >"$1/variant/ovh/labs/day-1/00-setup/main.tf"
}

# Every variant .tf gone: discovery finds nothing, which must not read as clean.
m_no_tf() {
  find "$1/variant/ovh" -name '*.tf' -delete
}

m_verbatim_drift() {
  printf 'locals {\n  stretch = "drifted"\n}\n' >"$1/variant/ovh/labs/day-1/00-setup/stretch.tf"
}

m_gomod_drift() {
  printf 'module example.com/variant/twin\n\ngo 1.25.0\n\nrequire example.com/dep v0.9.0\n' \
    >"$1/variant/ovh/labs/day-2/18-terratest-cost/go.mod"
}

m_passphrase_default() {
  cat >"$1/variant/ovh/labs/day-1/00-setup/vars.tf" <<'HCL'
variable "state_passphrase" {
  type      = string
  sensitive = true
  default   = "demo-state-passphrase-change-me"

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "too short"
  }
}
HCL
}

m_aws_v6() {
  sed -i.bak 's/>= 5.0, < 6.0/>= 5.0/' "$1/variant/ovh/labs/day-1/00-setup/main.tf"
  rm -f "$1/variant/ovh/labs/day-1/00-setup/main.tf.bak"
}

run_case() {
  local label="$1" expect="$2" needle="$3" mutate="$4"
  local tmp out rc
  tmp="$(mktemp -d "$SELFTEST_TMP_ROOT/case.XXXXXXXX")"
  build_root "$tmp"
  "$mutate" "$tmp"
  set +e
  out="$(bash "$tmp/variant/ovh/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  if [ "$expect" = "pass" ]; then
    if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF -- "$needle"; then
      printf '  [OK]   %s\n' "$label"
    else
      printf '  [FAIL] %s (rc=%s, expected exit 0 + %s)\n' "$label" "$rc" "$needle"
      printf '%s\n' "$out" | sed 's/^/      /'
      FAILURES=$((FAILURES + 1))
    fi
  else
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF -- "$needle"; then
      printf '  [OK]   %s\n' "$label"
    else
      printf '  [FAIL] %s (rc=%s, expected non-zero + %s)\n' "$label" "$rc" "$needle"
      printf '%s\n' "$out" | sed 's/^/      /'
      FAILURES=$((FAILURES + 1))
    fi
  fi
  rm -rf "$tmp"
}

printf '\n== variant/ovh/scripts/verify.sh self-test ==\n'
run_case "variant verify: clean fixtures pass" pass \
  "OVH variant verify PASSED" m_clean
run_case "variant verify: clean fixtures pass via the git index branch" pass \
  "discovery: git index" m_git_index
run_case "variant verify: provider pin drift armed" fail \
  "pin drift" m_pin_drift
run_case "variant verify: pin only in a comment does not satisfy the check" fail \
  "pin drift" m_pin_in_comment
run_case "variant verify: broken validate named" fail \
  "00-setup: validate" m_validate_broken
run_case "variant verify: unformatted .tf named" fail \
  "unformatted variant .tf" m_unformatted
run_case "variant verify: scanning nothing fails" fail \
  "scanned nothing" m_no_tf
run_case "variant verify: verbatim twin drift names the pair" fail \
  "variant/ovh/labs/day-1/00-setup/stretch.tf is no longer byte-identical to labs/day-1/00-setup/stretch.tf" m_verbatim_drift
run_case "variant verify: go.mod twin drift named" fail \
  "variant/ovh/labs/day-2/18-terratest-cost/go.mod differs from labs/day-2/18-terratest-cost/go.mod" m_gomod_drift
run_case "variant verify: state_passphrase default rejected" fail \
  "gives state_passphrase a default" m_passphrase_default
run_case "variant verify: aws constraint without < 6.0 rejected" fail \
  "must stay < 6.0" m_aws_v6

# --- teardown.sh ------------------------------------------------------------
# A stub `tofu` records every call to $TOFU_LOG and fails `destroy` for the
# root named in $STUB_FAIL_ROOT. Fake roots are just directories holding a
# terraform.tfstate, which is all teardown.sh keys on.
build_teardown_root() {
  local root="$1" r
  mkdir -p "$root/variant/ovh/scripts" "$root/setup" "$root/bin"
  cp "$REPO_ROOT/variant/ovh/scripts/teardown.sh" "$root/variant/ovh/scripts/teardown.sh"
  cp "$REPO_ROOT/setup/lib.sh" "$root/setup/lib.sh"
  for r in variant/ovh/labs/day-1/00-setup \
    variant/ovh/labs/day-1/10-differentiators/import \
    variant/ovh/examples/capstone-ovh \
    variant/ovh/bootstrap; do
    mkdir -p "$root/$r"
    printf '{}\n' >"$root/$r/terraform.tfstate"
  done
  cat >"$root/bin/tofu" <<'STUB'
#!/usr/bin/env bash
chdir=""
for a in "$@"; do
  case "$a" in -chdir=*) chdir="${a#-chdir=}" ;; esac
done
printf '%s\n' "$*" >>"$TOFU_LOG"
case " $* " in
  *" destroy "*)
    if [ -n "${STUB_FAIL_ROOT:-}" ] && [ "$chdir" = "$STUB_FAIL_ROOT" ]; then
      echo "stub: destroy failed in $chdir" >&2
      exit 1
    fi
    ;;
esac
exit 0
STUB
  chmod +x "$root/bin/tofu"
}

# td_case <label> <expect pass|fail> <fail-root or ""> <extra args> <check fn>
td_case() {
  local label="$1" expect="$2" fail_root="$3" args="$4" check="$5"
  local tmp out rc log
  tmp="$(mktemp -d "$SELFTEST_TMP_ROOT/td.XXXXXXXX")"
  build_teardown_root "$tmp"
  log="$tmp/tofu.log"
  : >"$log"
  set +e
  # shellcheck disable=SC2086 # $args is a deliberate word list of flags
  out="$(PATH="$tmp/bin:$PATH" TOFU_LOG="$log" STUB_FAIL_ROOT="$fail_root" CI=true \
    bash "$tmp/variant/ovh/scripts/teardown.sh" --auto-approve $args 2>&1)"
  rc=$?
  set -e
  local ok_rc=1
  if [ "$expect" = "pass" ] && [ "$rc" -eq 0 ]; then ok_rc=0; fi
  if [ "$expect" = "fail" ] && [ "$rc" -ne 0 ]; then ok_rc=0; fi
  if [ "$ok_rc" -eq 0 ] && "$check" "$log" "$out"; then
    printf '  [OK]   %s\n' "$label"
  else
    printf '  [FAIL] %s (rc=%s, expected %s)\n' "$label" "$rc" "$expect"
    printf '%s\n' "$out" | sed 's/^/      /'
    printf '      tofu calls:\n'
    sed 's/^/        /' "$log"
    FAILURES=$((FAILURES + 1))
  fi
  rm -rf "$tmp"
}

destroyed() { grep -q -- "-chdir=$2 destroy" "$1"; }

# Success: every non-import root destroyed, bootstrap LAST, all with
# -input=false; the import root is kept by default.
c_success() {
  local log="$1" out="$2"
  destroyed "$log" variant/ovh/labs/day-1/00-setup \
    && destroyed "$log" variant/ovh/examples/capstone-ovh \
    && destroyed "$log" variant/ovh/bootstrap \
    && ! destroyed "$log" variant/ovh/labs/day-1/10-differentiators/import \
    && [ "$(grep ' destroy ' "$log" | tail -n 1)" = "-chdir=variant/ovh/bootstrap destroy -auto-approve -input=false -no-color" ] \
    && ! grep ' destroy ' "$log" | grep -vq -- '-input=false' \
    && printf '%s' "$out" | grep -qF "state rm aws_s3_bucket.adopted"
}

# One earlier failure: bootstrap is NOT destroyed, the summary names the failure.
c_one_failure() {
  local log="$1" out="$2"
  destroyed "$log" variant/ovh/labs/day-1/00-setup \
    && ! destroyed "$log" variant/ovh/bootstrap \
    && printf '%s' "$out" | grep -qF "failed: variant/ovh/examples/capstone-ovh" \
    && printf '%s' "$out" | grep -qF "variant/ovh/bootstrap: NOT destroyed"
}

# Opt-in: --include-imported destroys the import root too.
c_include_imported() {
  destroyed "$1" variant/ovh/labs/day-1/10-differentiators/import
}

printf '\n== variant/ovh/scripts/teardown.sh self-test ==\n'
td_case "teardown: success path destroys all, bootstrap last, keeps import/" pass "" "" c_success
td_case "teardown: a failed root exits non-zero and spares bootstrap" fail \
  "variant/ovh/examples/capstone-ovh" "" c_one_failure
td_case "teardown: --include-imported opts the import root in" pass "" "--include-imported" c_include_imported

printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '  [OK]   variant verify self-test PASSED\n'
  exit 0
fi
printf '  [FAIL] variant verify self-test FAILED — %d case(s)\n' "$FAILURES"
exit 1
