#!/usr/bin/env bash
# Regression: lab:terratest fails fast without Docker and points at host Go.
# Never starts containers; uses a PATH that intentionally omits docker.
#
# PATH isolation mirrors scripts/bootstrap-selftest.sh: link only needed
# utilities into a temp SYSBIN. Do NOT put /usr/bin on PATH — GHA
# ubuntu-latest ships docker at /usr/bin/docker, which would abort the
# docker-absent precondition before any fail-fast assertion runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
SYSBIN="$TMP/sysbin"
mkdir -p "$BIN" "$SYSBIN"

# Link only utilities the selftest + lab-terratest.sh exercise. Do not glob-link
# /usr/bin: GHA runners include docker and recursive/special entries (X11).
SYSBIN_UTILS=(
  awk bash cat cut dirname env false grep head mktemp sed sh sort tr true uname
)
link_sysbin() {
  local util="$1"
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

# Never link docker into SYSBIN even if present on the host.
[ -e "$SYSBIN/docker" ] && {
  echo 'SYSBIN must not expose docker (PATH isolation broken)' >&2
  exit 1
}
[ -e "$SYSBIN/X11" ] && {
  echo 'SYSBIN must not mirror special /usr/bin entries like X11 (selective link only)' >&2
  exit 1
}

# Regression (US-F-AUDIT-TEST1 / HEALTH-AUDIT TEST-1): simulate GHA where docker
# lives under a /usr/bin-like tree. Legacy PATH=$BIN:/usr/bin:/bin would find it
# and abort the precondition; selective SYSBIN must stay docker-free.
LEAKUSR="$TMP/leak-usrbin"
mkdir -p "$LEAKUSR"
cat >"$LEAKUSR/docker" <<'EOF'
#!/bin/sh
printf '%s\n' 'Docker version 27.0.0, build gha-leak'
EOF
chmod +x "$LEAKUSR/docker"

PATH="$BIN:$LEAKUSR:$SYSBIN" command -v docker >/dev/null 2>&1 || {
  echo 'regression harness: simulated /usr/bin/docker must be findable on leak PATH' >&2
  exit 1
}
PATH="$BIN:$SYSBIN" command -v docker >/dev/null 2>&1 && {
  echo "selftest precondition failed: docker still on PATH=$BIN:$SYSBIN" >&2
  exit 1
}

export CI=true

set +e
out="$(PATH="$BIN:$SYSBIN" bash "$ROOT/scripts/lab-terratest.sh" labs/fixtures/terratest-smoke 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || {
  echo "expected non-zero exit when docker is absent" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -qi 'docker' || {
  echo "expected message to mention docker" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -Eqi 'host Go|lab:terratest:host|BOOTSTRAP_WITH_GO|brew install go' || {
  echo "expected message to point at the host-Go alternative" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

echo "lab-terratest self-test PASSED — docker-absent fail-fast points at host Go (GHA-safe PATH)"
