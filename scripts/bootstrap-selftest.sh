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
  awk bash cat chmod cut dirname env false grep head mktemp sed sh sort tr true uname
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

# Day-2/3 tools are advisory — a missing one must exit 0 with
# the affected-lab advisory, never block a Day-1 learner.
rm "$BIN/checkov"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -eq 0 ] || { echo 'missing Day-2/3 tool must exit 0 (advisory)' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'checkov.*missing'
printf '%s\n' "$out" | grep -q 'S14'
printf '%s\n' "$out" | grep -q 'Other tools were still checked'
printf '%s\n' "$out" | grep -q 'READY — Day-1 required tools'

# command -v alone is insufficient: a corrupt executable is unavailable. The
# loop must still probe and report every later tool — and stay advisory.
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
[ "$status" -eq 0 ] || { echo 'broken Day-2/3 version probe must exit 0 (advisory)' >&2; exit 1; }
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
[ "$status" -eq 0 ] || { echo 'plausible output with non-zero status must exit 0 (advisory)' >&2; exit 1; }
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
[ "$status" -eq 0 ] || { echo 'empty successful Day-2/3 probe must exit 0 (advisory)' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'trivy.*unusable'
printf '%s\n' "$out" | grep -q 'terramate.*0.13.0'

# Day-1 LocalStack route (tier 2). Labs 00, 08 and 10 (and the optional parts of
# 04/05) need LocalStack. Docker being INSTALLED is not enough — `docker
# --version` succeeds with the daemon down — so the route is ready only when
# `docker info` answers, or kubectl has a current context whose API answers
# (the `task lab:up:k8s` route). Otherwise: exit 0 with a prominent warning
# naming the labs (never "nothing blocks Day 1"), and rc 3 under STRICT.
docker_daemon_down() {
  cat >"$BIN/docker" <<'EOS'
#!/bin/sh
case "$1" in
  info) echo 'Cannot connect to the Docker daemon at unix:///var/run/docker.sock.' >&2; exit 1 ;;
esac
printf '%s\n' 'Docker version 27.0.0, build fake'
EOS
  chmod +x "$BIN/docker"
}
fake_kubectl() { # $1 = context ('' = none), $2 = API rc
  cat >"$BIN/kubectl" <<EOS
#!/bin/sh
case "\$*" in
  *current-context*) [ -n '$1' ] || exit 1; echo '$1' ;;
  *readyz*) exit $2 ;;
esac
EOS
  chmod +x "$BIN/kubectl"
}
assert_route_warning() { # $1 = output, $2 = case label
  printf '%s\n' "$1" | grep -q 'LocalStack route NOT READY' ||
    { echo "$2: missing the LocalStack route warning" >&2; printf '%s\n' "$1" >&2; exit 1; }
  for lab in 'Lab 00' 'Lab 08' 'Lab 10'; do
    printf '%s\n' "$1" | grep -q "$lab" || { echo "$2: warning must name $lab" >&2; exit 1; }
  done
  if printf '%s\n' "$1" | grep -qi 'nothing above blocks day 1'; then
    echo "$2: must not claim Day 1 is unblocked" >&2
    exit 1
  fi
}
run_strict() {
  PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=never BOOTSTRAP_STRICT=1 \
    bash "$ROOT/setup/bootstrap.sh" 2>&1
}

# Docker daemon reachable → the Docker route is ready, no warning. Restore the
# trivy the previous case broke so STRICT below isolates the route tier.
fake trivy 'Version: 0.64.1'
out="$(run_bootstrap)"
printf '%s\n' "$out" | grep -q 'LocalStack route: Docker' ||
  { echo 'reachable Docker daemon must report the Docker route' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'LocalStack route NOT READY' &&
  { echo 'reachable Docker daemon must not warn' >&2; exit 1; }

# Docker installed but daemon down, no kubectl → warn (rc 0); STRICT → rc 3.
docker_daemon_down
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -eq 0 ] || { echo 'daemon down must stay advisory by default (rc 0)' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'daemon not reachable' ||
  { echo 'daemon down must be reported as such, not as ready' >&2; exit 1; }
assert_route_warning "$out" 'daemon down'
set +e
run_strict >/dev/null
status=$?
set -e
[ "$status" -eq 3 ] || { echo "daemon down under STRICT must exit 3 (got $status)" >&2; exit 1; }

# Docker absent, kubectl with a reachable current context → the k8s route is
# ready; STRICT passes because nothing else is missing.
rm -f "$BIN/docker"
fake_kubectl kind-opentofu 0
set +e
out="$(run_strict)"
status=$?
set -e
[ "$status" -eq 0 ] || { echo "k8s route ready must pass STRICT (got $status)" >&2; printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'LocalStack route: Kubernetes (context kind-opentofu)' ||
  { echo 'k8s route must name the context' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'docker.*missing' ||
  { echo 'missing Docker is still listed' >&2; exit 1; }

# kubectl present but no current context → not a route.
fake_kubectl '' 0
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -eq 0 ] || { echo 'no route must stay advisory by default (rc 0)' >&2; exit 1; }
assert_route_warning "$out" 'kubectl without context'
printf '%s\n' "$out" | grep -q 'lab:up:k8s' || { echo 'must point at the k8s route' >&2; exit 1; }

# A context whose API does not answer is not a route either.
fake_kubectl kind-gone 1
set +e
out="$(run_bootstrap)"
set -e
assert_route_warning "$out" 'kubectl context unreachable'
printf '%s\n' "$out" | grep -q "kind-gone" || { echo 'must name the unreachable context' >&2; exit 1; }
set +e
run_strict >/dev/null
status=$?
set -e
[ "$status" -eq 3 ] || { echo "unreachable context under STRICT must exit 3 (got $status)" >&2; exit 1; }
rm -f "$BIN/kubectl"

# Docker absent and no kubectl → warn, never fail by default.
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -eq 0 ] || { echo 'missing Docker must exit 0 (advisory, not required)' >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'docker.*missing'
assert_route_warning "$out" 'no docker, no kubectl'
fake docker 'Docker version 27.0.0, build fake'

# Required + Docker missing together: the install-hint list must keep every
# tool a separate word (gluing the last required tool to Docker silently drops
# Docker's install hint).
rm -f "$BIN/tofu" "$BIN/docker"
set +e
out="$(run_bootstrap)"
status=$?
set -e
[ "$status" -ne 0 ] || { echo 'missing required tofu must exit non-zero' >&2; exit 1; }
printf '%s\n' "$out" | grep -q '· tofu'
printf '%s\n' "$out" | grep -q '· docker'
printf '%s\n' "$out" | grep -q 'tofudocker' && { echo 'install-hint list glued tofu+docker' >&2; exit 1; }
fake tofu 'OpenTofu v1.12.3'
fake docker 'Docker version 27.0.0, build fake'

# BOOTSTRAP_STRICT=1 (`task preflight:strict`, the facilitator readiness check)
# turns the advisory tiers into a distinct rc 3 while the default stays 0 for a
# Day-1 learner.
rm -f "$BIN/checkov"
set +e
PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=never BOOTSTRAP_STRICT=1 \
  bash "$ROOT/setup/bootstrap.sh" >/dev/null 2>&1
strict_status=$?
set -e
[ "$strict_status" -eq 3 ] || { echo 'BOOTSTRAP_STRICT=1 with Day-2/3 gaps must exit 3' >&2; exit 1; }
fake checkov '3.2.450'

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
[ "$status" -eq 0 ] || { echo 'failed Day-2/3 installer must leave bootstrap at 0 (advisory)' >&2; exit 1; }
grep -q '^install tflint$' "$TMP/brew.log"
grep -q '^install checkov$' "$TMP/brew.log"
printf '%s\n' "$out" | grep -q 'Install of tflint failed'
printf '%s\n' "$out" | grep -q 'Install of checkov failed'

# Bootstrap must run without pnpm and install it itself. This
# asserts the mechanism the Taskfile ordering relies on — the installed shim is
# visible to a fresh shell — while the ordering itself is asserted in
# scripts/taskfile-contract.test.mjs (task is not installed in CI's verify-unit
# job).
fake tflint 'TFLint version 0.58.1'
fake checkov '3.2.450'
fake uname 'Darwin'
cat >"$BIN/corepack" <<'EOF'
#!/bin/sh
# emulate: corepack enable && corepack prepare pnpm@latest --activate
printf '#!/bin/sh\nprintf "11.9.0\\n"\n' >"$BOOTSTRAP_TEST_BIN/pnpm"
chmod +x "$BOOTSTRAP_TEST_BIN/pnpm"
EOF
chmod +x "$BIN/corepack"
cat >"$BIN/brew" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$BIN/brew"
rm -f "$BIN/pnpm"
set +e
out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=always \
  BOOTSTRAP_TEST_BIN="$BIN" bash "$ROOT/setup/bootstrap.sh" 2>&1)"
status=$?
set -e
[ "$status" -eq 0 ] || {
  echo 'bootstrap must install pnpm and exit 0' >&2
  printf '%s\n' "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'pnpm.*missing'
[ -x "$BIN/pnpm" ] || { echo 'bootstrap did not install pnpm' >&2; exit 1; }
PATH="$BIN:$SYSBIN" sh -c 'command -v pnpm >/dev/null' || {
  echo 'installed pnpm shim not visible to a fresh shell' >&2
  exit 1
}
rm -f "$BIN/corepack" "$BIN/brew" "$BIN/uname"
fake pnpm '11.9.0'

# A tool auto-installed during setup must be re-probed — the advisory/STRICT
# gate must not fire on the stale pre-install scan state.
fake uname 'Darwin'
cat >"$BIN/brew" <<'EOF'
#!/bin/sh
printf '#!/bin/sh\nprintf "Docker version 27.0.0, build fake\\n"\n' >"$BOOTSTRAP_TEST_BIN/docker"
chmod +x "$BOOTSTRAP_TEST_BIN/docker"
exit 0
EOF
chmod +x "$BIN/brew"
rm -f "$BIN/docker"
set +e
out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=always BOOTSTRAP_STRICT=1 \
  BOOTSTRAP_TEST_BIN="$BIN" bash "$ROOT/setup/bootstrap.sh" 2>&1)"
status=$?
set -e
[ "$status" -eq 0 ] || {
  echo 'auto-installed Docker must clear the advisory (rc 0, not STRICT rc 3)' >&2
  printf '%s\n' "$out" >&2
  exit 1
}
if printf '%s\n' "$out" | grep -q 'LocalStack route NOT READY'; then
  echo 'auto-installed Docker still reported missing' >&2
  exit 1
fi

# ...and the re-probe must use the daemon check, not the binary: a freshly
# installed Docker Desktop that is not running yet leaves the route NOT READY.
cat >"$BIN/brew" <<'EOF'
#!/bin/sh
cat >"$BOOTSTRAP_TEST_BIN/docker" <<'EOD'
#!/bin/sh
[ "$1" = info ] && exit 1
printf 'Docker version 27.0.0, build fake\n'
EOD
chmod +x "$BOOTSTRAP_TEST_BIN/docker"
exit 0
EOF
chmod +x "$BIN/brew"
rm -f "$BIN/docker"
set +e
out="$(PATH="$BIN:$SYSBIN" CI=true BOOTSTRAP_AUTO_INSTALL=always BOOTSTRAP_STRICT=1 \
  BOOTSTRAP_TEST_BIN="$BIN" bash "$ROOT/setup/bootstrap.sh" 2>&1)"
status=$?
set -e
[ "$status" -eq 3 ] || {
  echo "installed-but-stopped Docker must keep STRICT at rc 3 (got $status)" >&2
  printf '%s\n' "$out" >&2
  exit 1
}
assert_route_warning "$out" 'installed but stopped Docker'
fake docker 'Docker version 27.0.0, build fake'
rm -f "$BIN/brew" "$BIN/uname"

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

# The Taskfile ordering contract (setup must run bootstrap
# before pnpm install) is asserted semantically in
# scripts/taskfile-contract.test.mjs — parse the dependency graph rather than
# grepping the source, which a reformat can defeat.

echo 'bootstrap self-test PASSED — versions, idempotence, missing, corrupt, failing-required-probe, advisory Day-2/3, LocalStack route (docker daemon / k8s context / none), STRICT, pnpm-install, install-failure, and optional Go paths'
