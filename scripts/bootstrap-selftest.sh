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

out="$(run_bootstrap)"
for tool in tflint trivy checkov conftest terramate; do
  printf '%s\n' "$out" | grep -q "$tool" || { echo "missing version report for $tool" >&2; exit 1; }
done
printf '%s\n' "$out" | grep -q 'Day-2/3 tools ready'

rm "$BIN/checkov"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'missing Day-2/3 tool must exit non-zero' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'checkov.*missing'
printf '%s\n' "$out" | grep -q 'S14'
printf '%s\n' "$out" | grep -q 'Other tools were still checked'

# Explicit install mode exercises failure continuation with a fake Homebrew.
fake uname 'Darwin'
cat >"$BIN/brew" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$BOOTSTRAP_TEST_BREW_LOG"
exit 1
EOF
chmod +x "$BIN/brew"
rm -f "$BIN/tflint"
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

echo 'bootstrap self-test PASSED — present, missing, and install-failure paths'
