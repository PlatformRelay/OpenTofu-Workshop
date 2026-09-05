#!/usr/bin/env bash
# Regression tests for the Day-2/3 bootstrap contract. Runs only against fake
# commands in a temporary PATH; it never installs software or changes the host.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
SYSBIN="$TMP/sysbin"
mkdir -p "$BIN" "$SYSBIN"

# Link only utilities bootstrap exercises under PATH=$BIN:$SYSBIN. Do not glob-link
# /usr/bin: GHA ubuntu runners include recursive/special entries (e.g. X11 → X11)
# that ln -s cannot recreate (actions run 30211547949).
SYSBIN_UTILS=(
  awk bash cat cut dirname env false grep head mktemp sed sh sort tr true uname
  apt-get dnf pacman
)
link_sysbin() {
  local util="$1"
  case "$util" in go|gofmt) return 0 ;; esac
  for dir in /usr/bin /bin; do
    local src="$dir/$util"
    [ -f "$src" ] || continue
    [ -x "$src" ] || continue
    ln -sf "$src" "$SYSBIN/$util"
    return 0
  done
  return 1
}
for util in "${SYSBIN_UTILS[@]}"; do
  link_sysbin "$util" || true
done
PATH="$SYSBIN" command -v go >/dev/null 2>&1 && {
  echo 'SYSBIN must not expose go (PATH isolation broken)' >&2
  exit 1
}
[ -e "$SYSBIN/X11" ] && {
  echo 'SYSBIN must not mirror special /usr/bin entries like X11 (selective link only)' >&2
  exit 1
}

fake() {
  local name="$1" output="$2"
  printf '#!/bin/sh\nprintf "%%s\\n" %s\n' "$(printf '%s' "$output" | sed "s/'/'\\\\''/g; s/^/'/; s/$/'/")" >"$BIN/$name"
  chmod +x "$BIN/$name"
}

# Keep baseline prerequisites green so failures isolate the Day-2/3 tools.
fake tofu 'OpenTofu v1.12.3'
fake docker 'Docker version 27.0.0, build fake'
fake pnpm '11.9.0'
fake node 'v22.0.0'
fake task 'Task version: v3.40.0'
fake tflint 'TFLint version 0.58.1'
fake trivy 'Version: 0.64.1'
fake checkov '3.2.450'
fake conftest 'Conftest: 0.61.0'
fake terramate 'terramate version 0.13.0'

run_bootstrap() {
  PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=never \
    bash "$ROOT/setup/bootstrap.sh" 2>&1
}

ready_out="$(run_bootstrap)"
printf '%s\n' "$ready_out" | grep -Fqx '  ✓ tflint     0.58.1'
printf '%s\n' "$ready_out" | grep -Fqx '  ✓ trivy      0.64.1'
printf '%s\n' "$ready_out" | grep -Fqx '  ✓ checkov    3.2.450'
printf '%s\n' "$ready_out" | grep -Fqx '  ✓ conftest   0.61.0'
printf '%s\n' "$ready_out" | grep -Fqx '  ✓ terramate  0.13.0'
printf '%s\n' "$ready_out" | grep -Fqx '  ✓ Day-2/3 tools ready — tflint, Trivy, Checkov, Conftest, and Terramate.'

# A second run over the same PATH must be byte-identical and side-effect free.
second_out="$(run_bootstrap)"
[ "$ready_out" = "$second_out" ] || { echo 'repeated bootstrap output drifted' >&2; exit 1; }

rm "$BIN/checkov"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'missing Day-2/3 tool must exit non-zero' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'checkov.*missing'
printf '%s\n' "$out" | grep -q 'S14'
printf '%s\n' "$out" | grep -q 'Other tools were still checked'

# command -v alone is insufficient: a corrupt executable is unavailable. The
# loop must still probe and report every later tool.
fake checkov '3.2.450'
cat >"$BIN/tflint" <<'EOF'
#!/bin/sh
exit 7
EOF
chmod +x "$BIN/tflint"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'broken version probe must exit non-zero' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'tflint.*unusable'
printf '%s\n' "$out" | grep -q 'version probe failed'
printf '%s\n' "$out" | grep -q 'tflint.*affects S13'
printf '%s\n' "$out" | grep -q 'terramate.*0.13.0'

# Plausible stdout must not mask a failing probe status.
cat >"$BIN/tflint" <<'EOF'
#!/bin/sh
echo 'TFLint version 0.58.1'
exit 7
EOF
chmod +x "$BIN/tflint"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'plausible output with non-zero status must exit non-zero' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'tflint.*unusable'
printf '%s\n' "$out" | grep -q 'terramate.*0.13.0'

# A successful command with empty stdout is equally unusable.
fake tflint 'TFLint version 0.58.1'
cat >"$BIN/trivy" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$BIN/trivy"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'empty successful version probe must exit non-zero' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'trivy.*unusable'
printf '%s\n' "$out" | grep -q 'terramate.*0.13.0'

# REL-1: a REQUIRED tool whose version probe fails must be named — never a
# wordless mid-report exit 1 under set -euo pipefail. Restore trivy first so
# the failing pnpm probe is the ONLY defect: the final exit code must come
# from the required-tool re-check, not a leftover Day-2/3 breakage.
fake trivy 'Version: 0.64.1'
cat >"$BIN/pnpm" <<'EOF'
#!/bin/sh
exit 7
EOF
chmod +x "$BIN/pnpm"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'failing required version probe must exit non-zero' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'pnpm.*unusable'
printf '%s\n' "$out" | grep -q 'version probe failed'
# The report must run to completion: later sections and the final verdict.
printf '%s\n' "$out" | grep -q 'terramate.*0.13.0'
printf '%s\n' "$out" | grep -q 'NOT READY'
fake pnpm '11.9.0'

# Explicit install mode exercises failure continuation with a fake Homebrew.
fake uname 'Darwin'
cat >"$BIN/brew" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$BOOTSTRAP_TEST_BREW_LOG"
exit 1
EOF
chmod +x "$BIN/brew"
rm -f "$BIN/tflint" "$BIN/checkov"
: >"$TMP/brew.log"
set +e
out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=always \
  BOOTSTRAP_TEST_BREW_LOG="$TMP/brew.log" bash "$ROOT/setup/bootstrap.sh" 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'failed installer must leave bootstrap non-zero' >&2; exit 1; }
grep -q '^install tflint$' "$TMP/brew.log"
grep -q '^install checkov$' "$TMP/brew.log"
printf '%s\n' "$out" | grep -q 'Install of tflint failed'
printf '%s\n' "$out" | grep -q 'Install of checkov failed'

# Restore a clean PATH for the optional host-Go lane (US-0-GOTT).
fake tflint 'TFLint version 0.58.1'
fake checkov '3.2.450'
fake trivy 'Version: 0.64.1'
rm -f "$BIN/brew" "$BIN/uname"

# Default path must stay Go-free (container-first).
default_go_out="$(run_bootstrap)"
printf '%s\n' "$default_go_out" | grep -q 'Host Go skipped'
printf '%s\n' "$default_go_out" | grep -q 'task lab:terratest'

# BOOTSTRAP_WITH_GO=1 with Go present → verify + ready.
fake go 'go version go1.27.1 darwin/arm64'
# tool_version uses `go version` and awk '{print $3}' → need the script to call go correctly.
# Our fake prints a single line; go version format is "go version go1.27.1 …"
cat >"$BIN/go" <<'EOF'
#!/bin/sh
printf '%s\n' 'go version go1.27.1 darwin/arm64'
EOF
chmod +x "$BIN/go"
set +e
with_go_out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=never \
  BOOTSTRAP_WITH_GO=1 bash "$ROOT/setup/bootstrap.sh" 2>&1)"
with_go_status=$?
set -e
[ "$with_go_status" -eq 0 ] || {
  echo 'BOOTSTRAP_WITH_GO=1 with Go present must exit 0' >&2
  printf '%s\n' "$with_go_out" >&2
  exit 1
}
printf '%s\n' "$with_go_out" | grep -q 'Host Go ready'
printf '%s\n' "$with_go_out" | grep -q 'lab:terratest:host'

# A host Go BELOW MIN_GO must red, not pass. Without this the floor is
# decorative: a 1.23 host bootstraps clean and then hard-fails Lab 18's
# `task lab:terratest:host` on `go.mod requires go >= 1.25.0`.
cat >"$BIN/go" <<'EOF'
#!/bin/sh
printf '%s\n' 'go version go1.23.6 linux/amd64'
EOF
chmod +x "$BIN/go"
set +e
old_go_out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=never \
  BOOTSTRAP_WITH_GO=1 bash "$ROOT/setup/bootstrap.sh" 2>&1)"
old_go_status=$?
set -e
[ "$old_go_status" -ne 0 ] || {
  echo 'host Go below MIN_GO must exit non-zero' >&2
  printf '%s\n' "$old_go_out" >&2
  exit 1
}
printf '%s\n' "$old_go_out" | grep -q 'needs >='
printf '%s\n' "$old_go_out" | grep -q 'Below minimum Go version'

# REL-1 (--with-go lane): a failing go version probe must be named too.
cat >"$BIN/go" <<'EOF'
#!/bin/sh
exit 7
EOF
chmod +x "$BIN/go"
set +e
broken_go_out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=never \
  BOOTSTRAP_WITH_GO=1 bash "$ROOT/setup/bootstrap.sh" 2>&1)"
broken_go_status=$?
set -e
[ "$broken_go_status" -ne 0 ] || {
  echo 'failing go version probe must exit non-zero' >&2
  exit 1
}
printf '%s\n' "$broken_go_out" | grep -q 'go.*unusable'
printf '%s\n' "$broken_go_out" | grep -q 'version probe failed'
printf '%s\n' "$broken_go_out" | grep -q 'NOT READY'

# BOOTSTRAP_WITH_GO=1 without Go → non-zero and install hint.
# Regression harness: GHA-style host go on legacy PATH (actions run 30149989911).
LEAKBIN="$TMP/leak-go"
mkdir -p "$LEAKBIN"
cat >"$LEAKBIN/go" <<'EOF'
#!/bin/sh
printf '%s\n' 'go version go1.27.1 linux/amd64'
EOF
chmod +x "$LEAKBIN/go"
rm -f "$BIN/go"
set +e
leak_out="$(PATH="$BIN:$LEAKBIN:/usr/bin:/bin" CI=true BOOTSTRAP_AUTO_INSTALL=never \
  BOOTSTRAP_WITH_GO=1 bash "$ROOT/setup/bootstrap.sh" 2>&1)"
leak_status=$?
set -e
[ "$leak_status" -eq 0 ] || {
  echo 'regression harness: simulated host go on legacy PATH must exit 0 (leak repro)' >&2
  exit 1
}
printf '%s\n' "$leak_out" | grep -q 'Host Go ready'

set +e
missing_go_out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=never \
  BOOTSTRAP_WITH_GO=1 bash "$ROOT/setup/bootstrap.sh" 2>&1)"
missing_go_status=$?
set -e
[ "$missing_go_status" -ne 0 ] || {
  echo 'BOOTSTRAP_WITH_GO=1 without Go must exit non-zero' >&2
  exit 1
}
printf '%s\n' "$missing_go_out" | grep -q 'go.*missing'
printf '%s\n' "$missing_go_out" | grep -q 'Missing optional host Go'

echo 'bootstrap self-test PASSED — versions, idempotence, missing, corrupt, failing-required-probe, install-failure, and optional Go paths'
