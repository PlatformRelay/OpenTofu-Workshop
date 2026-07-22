#!/usr/bin/env bash
# Regression tests for the Day-2/3 bootstrap contract. Runs only against fake
# commands in a temporary PATH; it never installs software or changes the host.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"

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
  PATH="$BIN:/usr/bin:/bin" CI=true BOOTSTRAP_AUTO_INSTALL=never \
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
out="$(PATH="$BIN:/usr/bin:/bin" CI=true BOOTSTRAP_AUTO_INSTALL=always \
  BOOTSTRAP_TEST_BREW_LOG="$TMP/brew.log" bash "$ROOT/setup/bootstrap.sh" 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'failed installer must leave bootstrap non-zero' >&2; exit 1; }
grep -q '^install tflint$' "$TMP/brew.log"
grep -q '^install checkov$' "$TMP/brew.log"
printf '%s\n' "$out" | grep -q 'Install of tflint failed'
printf '%s\n' "$out" | grep -q 'Install of checkov failed'

echo 'bootstrap self-test PASSED — versions, idempotence, missing, corrupt, and install-failure paths'
