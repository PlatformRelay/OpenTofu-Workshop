#!/usr/bin/env bash
# Offline regression tests for scripts/release-tag-guard.sh (US-P-REL).
# Uses mocked `gh` only — no network, no real releases.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/release-tag-guard.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUB="$TMP/bin"
mkdir -p "$STUB"

FULL_SHA="abcdef0123456789abcdef0123456789abcdef01"
OTHER_SHA="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

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

# --- decide mode ---------------------------------------------------------------

out="$(assert_status "decide empty → allow" 0 "$SCRIPT" decide "$FULL_SHA" "")"
assert_eq "decide empty output" "allow" "$out"

out="$(assert_status "decide same SHA → idempotent" 0 "$SCRIPT" decide "$FULL_SHA" "$FULL_SHA")"
assert_eq "decide same output" "idempotent" "$out"

out="$(CI=true assert_status "decide CI prefix mismatch → refuse" 1 "$SCRIPT" decide "$FULL_SHA" "abcdef0")"
assert_eq "decide CI refuse output" "refuse" "$out"

out="$(assert_status "decide different → refuse" 1 "$SCRIPT" decide "$FULL_SHA" "$OTHER_SHA")"
assert_eq "decide different output" "refuse" "$out"

# --- check mode (mocked gh) ----------------------------------------------------

install_gh_stub() {
  local mode="$1"
  cat >"$STUB/gh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
args="\$*"
jq_expr="\${*: -1}"
mode="$mode"
case "\$mode" in
  404)
    echo "gh: Not Found (HTTP 404)" >&2
    exit 1
    ;;
  same)
    if [[ "\$args" == *"/git/ref/tags/"* ]]; then
      if [[ "\$jq_expr" == ".object.type" ]]; then
        printf '%s\n' 'commit'
      else
        printf '%s\n' '$FULL_SHA'
      fi
      exit 0
    fi
    if [[ "\$args" == *"/releases/tags/"* ]]; then
      echo "gh: Not Found (HTTP 404)" >&2
      exit 1
    fi
    ;;
  refuse)
    if [[ "\$args" == *"/git/ref/tags/"* ]]; then
      if [[ "\$jq_expr" == ".object.type" ]]; then
        printf '%s\n' 'commit'
      else
        printf '%s\n' '$OTHER_SHA'
      fi
      exit 0
    fi
    if [[ "\$args" == *"/releases/tags/"* ]]; then
      echo "gh: Not Found (HTTP 404)" >&2
      exit 1
    fi
    ;;
  rate)
    echo "gh: API rate limit exceeded (HTTP 403)" >&2
    exit 1
    ;;
esac
echo "unexpected gh invocation: \$args" >&2
exit 99
EOF
  chmod +x "$STUB/gh"
}

run_check() {
  local mode="$1"
  shift
  install_gh_stub "$mode"
  PATH="$STUB:$PATH" "$@"
}

install_gh_stub 404
out="$(assert_status "check missing tag → allow" 0 env PATH="$STUB:$PATH" "$SCRIPT" check --dry-run "v9.9.9" "$FULL_SHA")"
if [[ "$out" == *"allow"* ]]; then pass=$((pass + 1)); else echo "FAIL: check allow wording: $out" >&2; fail=$((fail + 1)); fi

install_gh_stub same
out="$(assert_status "check same tag → idempotent" 0 env PATH="$STUB:$PATH" "$SCRIPT" check --dry-run "v1.0.0" "$FULL_SHA")"
if [[ "$out" == *"idempotent"* ]]; then pass=$((pass + 1)); else echo "FAIL: check idempotent wording: $out" >&2; fail=$((fail + 1)); fi

install_gh_stub refuse
out="$(assert_status "check different tag → refuse" 1 env PATH="$STUB:$PATH" "$SCRIPT" check --dry-run "v1.0.0" "$FULL_SHA")"
if [[ "$out" == *"refuse"* ]]; then pass=$((pass + 1)); else echo "FAIL: check refuse wording: $out" >&2; fail=$((fail + 1)); fi

install_gh_stub rate
out="$(assert_status "check API error → unknown" 1 env PATH="$STUB:$PATH" "$SCRIPT" check --dry-run "v1.0.0" "$FULL_SHA")"
if [[ "$out" == *"unknown"* ]]; then pass=$((pass + 1)); else echo "FAIL: check unknown wording: $out" >&2; fail=$((fail + 1)); fi
if [[ "$out" != *"→ allow"* && "$out" != allow:* ]]; then pass=$((pass + 1)); else echo "FAIL: API error must not allow: $out" >&2; fail=$((fail + 1)); fi

# --- workflow wiring -------------------------------------------------------------

wf="$ROOT/.github/workflows/release.yml"
grep -q 'scripts/release-tag-guard.sh' "$wf" && pass=$((pass + 1)) || { echo "FAIL: release.yml missing tag guard" >&2; fail=$((fail + 1)); }
guard_line="$(grep -n 'scripts/release-tag-guard.sh' "$wf" | head -1 | cut -d: -f1)"
publish_line="$(grep -n 'action-gh-release' "$wf" | head -1 | cut -d: -f1)"
if [[ -n "$guard_line" && -n "$publish_line" && "$guard_line" -lt "$publish_line" ]]; then
  pass=$((pass + 1))
else
  echo "FAIL: tag guard must run before action-gh-release" >&2
  fail=$((fail + 1))
fi

if awk '
  /Refuse moved release tags/ { in_step=1 }
  in_step && /^[[:space:]]*- name:/ && !/Refuse moved release tags/ { in_step=0 }
  in_step { print }
' "$wf" | grep -q 'GH_TOKEN: \${{ github.token }}'; then
  pass=$((pass + 1))
else
  echo "FAIL: publish job must export GH_TOKEN for tag guard" >&2
  fail=$((fail + 1))
fi

echo "release-tag-guard-selftest: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
