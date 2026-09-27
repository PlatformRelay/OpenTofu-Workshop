#!/usr/bin/env bash
# scripts/integration-tests.sh — the integration lane's `tofu test` loop.
#
# Shared by the CI verify-integration job and Taskfile verify:integration:tests
# (both need LocalStack on :4566 and the AWS_* endpoint env already set).
# Guarded by scripts/integration-discovery.test.mjs.
#
#   bash scripts/integration-tests.sh [--attempts N]
#
# For every examples/*, labs/day-1/*, labs/day-2/* root with
# tests/integration*.tftest.hcl:
#   - copy the root into a scratch tree (with modules/ linked beside it) and
#     run there, so a learner's own apply in the checkout — Lab 00's hello.txt
#     and my-first-tofu-bucket, the examples Labs 08/26 work in — is never
#     overwritten or destroyed by the test's apply/destroy;
#   - run the participant's plain `tofu init -input=false` (no -backend=false):
#     the PBKDF2-encrypted roots carry no committed passphrase, so init needs
#     TF_VAR_state_passphrase exactly as a learner's does (a CI value is set
#     below when the caller has none);
#   - run `tofu test -filter=<file>` once per discovered file and require
#     "N passed" with N >= 1: `tofu test` exits 0 with "0 passed, 0 failed"
#     when a filter matches nothing, which would be a silent false green.
# The lane fails if it discovers no integration roots at all.
#
# The scratch copy protects the learner's FILES. A resource with a fixed name
# that a learner already created in the same LocalStack (Lab 00's
# my-first-tofu-bucket) makes the test's apply fail with BucketAlreadyExists —
# loudly, and without adopting or destroying it. `task lab:down && task lab:up`
# gives the lane a clean emulator.
set -uo pipefail

attempts=1
while [ $# -gt 0 ]; do
  case "$1" in
    --attempts) attempts="${2:?--attempts needs a number}"; shift 2 ;;
    *) echo "usage: integration-tests.sh [--attempts N]" >&2; exit 2 ;;
  esac
done

err() { echo "integration-tests: $*" >&2; }

repo="$(pwd -P)"
# A throwaway value that satisfies the >= 16-char PBKDF2 validation; never a
# real secret, and a caller's own value wins.
if [ -z "${TF_VAR_state_passphrase:-}" ]; then
  export TF_VAR_state_passphrase='integration-lane-passphrase'
fi

roots=()
for d in examples/* labs/day-1/* labs/day-2/*; do
  [ -d "$d" ] || continue
  compgen -G "$d/tests/integration*.tftest.hcl" >/dev/null || continue
  roots+=("$d")
done
if [ "${#roots[@]}" -eq 0 ]; then
  err "no integration roots discovered (examples/*, labs/day-1/*, labs/day-2/* with tests/integration*.tftest.hcl) — refusing a vacuous pass"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# Roots reference shared modules as ../../modules etc.; mirror that layout.
[ -d "$repo/modules" ] && ln -s "$repo/modules" "$work/modules"

group() { [ -n "${GITHUB_ACTIONS:-}" ] && echo "::group::$*" || echo "== $* =="; }
endgroup() { [ -n "${GITHUB_ACTIONS:-}" ] && echo "::endgroup::"; return 0; }

# run_root DIR — one attempt: fresh copy, plain init, every file must pass >= 1 test.
run_root() {
  local d="$1" copy="$work/$1" rc=0 files=0 f rel out trc passed
  rm -rf "$copy"
  mkdir -p "$(dirname "$copy")"
  cp -R "$repo/$d" "$copy" || return 1
  # Drop the learner's local init/state so the copy starts clean.
  rm -rf "$copy/.terraform"
  rm -f "$copy"/*.tfstate "$copy"/*.tfstate.*
  (cd "$copy" && tofu init -input=false) || { err "$d: tofu init failed"; return 1; }
  for f in "$copy"/tests/integration*.tftest.hcl; do
    [ -e "$f" ] || continue
    files=$((files + 1))
    rel="tests/${f##*/}"
    out="$(cd "$copy" && tofu test -filter="$rel" -no-color 2>&1)"
    trc=$?
    printf '%s\n' "$out"
    passed="$(printf '%s\n' "$out" | grep -Eo '(Success|Failure)! [0-9]+ passed' | tail -n 1 | awk '{print $2}')"
    if [ "$trc" -ne 0 ]; then
      err "$d/$rel: tofu test failed (rc $trc)"
      rc=1
    elif [ -z "$passed" ] || [ "$passed" -eq 0 ]; then
      err "$d/$rel: ran no tests (${passed:-no} passed) — the filter matched nothing"
      rc=1
    fi
  done
  if [ "$files" -eq 0 ]; then
    err "$d: empty filter set"
    rc=1
  fi
  return "$rc"
}

for d in "${roots[@]}"; do
  ok=0
  for attempt in $(seq 1 "$attempts"); do
    group "$d (integration, attempt $attempt/$attempts)"
    if run_root "$d"; then ok=1; fi
    endgroup
    [ "$ok" -eq 1 ] && break
    [ -n "${GITHUB_ACTIONS:-}" ] && echo "::warning::$d integration tests failed (attempt $attempt/$attempts)"
    [ "$attempt" -lt "$attempts" ] && sleep 10
  done
  if [ "$ok" -ne 1 ]; then
    err "$d: integration tests failed"
    exit 1
  fi
done
echo "integration-tests: ${#roots[@]} root(s) passed"
