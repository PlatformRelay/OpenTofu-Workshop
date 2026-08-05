#!/usr/bin/env bash
# scripts/lab-terratest.sh — run Go tests for a Terratest workdir in the pinned
# container lane (default) against LocalStack on the compose network.
#
# Usage:
#   bash scripts/lab-terratest.sh [DIR]
#   MODE=host bash scripts/lab-terratest.sh [DIR]
#
# DIR defaults to labs/fixtures/terratest-smoke (toolchain smoke fixture).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${1:-labs/fixtures/terratest-smoke}"
MODE="${MODE:-container}"
COMPOSE_ENV_FILE="${COMPOSE_ENV_FILE:-$ROOT/versions.env}"
COMPOSE=(docker compose -f "$ROOT/docker-compose.yml" --env-file "$COMPOSE_ENV_FILE")

# Resolve DIR relative to repo root when not absolute.
case "$DIR" in
  /*) ;;
  *) DIR="$ROOT/$DIR" ;;
esac

if [ ! -d "$DIR" ]; then
  echo "ERROR: Terratest workdir not found: $DIR" >&2
  exit 1
fi

rel_dir="${DIR#"$ROOT"/}"
if [ "$rel_dir" = "$DIR" ]; then
  # Absolute path outside the repo — container mounts only the repo root.
  echo "ERROR: DIR must be inside the workshop repo (got: $DIR)" >&2
  exit 1
fi

run_host() {
  if ! command -v go >/dev/null 2>&1; then
    echo "ERROR: Go is required for the host Terratest lane." >&2
    echo "  Install/verify: BOOTSTRAP_WITH_GO=1 bash setup/bootstrap.sh" >&2
    echo "  Or: brew install go   (then: task lab:terratest:host DIR=$rel_dir)" >&2
    exit 1
  fi
  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
  export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
  echo "Running host Go tests in $rel_dir (AWS_ENDPOINT_URL=$AWS_ENDPOINT_URL) ..."
  ( cd "$DIR" && go test -v -count=1 ./... )
}

run_container() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is required for the container Terratest lane." >&2
    echo "  Install Docker, then re-run: task lab:terratest DIR=$rel_dir" >&2
    echo "  Host-Go alternative (no Docker): BOOTSTRAP_WITH_GO=1 bash setup/bootstrap.sh" >&2
    echo "  then: task lab:up && task lab:terratest:host DIR=$rel_dir" >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is installed but the daemon is not reachable." >&2
    echo "  Start Docker, then re-run: task lab:terratest DIR=$rel_dir" >&2
    echo "  Host-Go alternative: BOOTSTRAP_WITH_GO=1 bash setup/bootstrap.sh" >&2
    echo "  then: task lab:up && task lab:terratest:host DIR=$rel_dir" >&2
    exit 1
  fi

  echo "Running Terratest container lane for $rel_dir (LocalStack on compose network) ..."
  # --profile enables the terratest service (kept off lab:up). depends_on
  # brings LocalStack up when needed. -T keeps non-interactive shells happy.
  # Preflight: Docker Desktop on macOS often cannot bind-mount /tmp (or other
  # non-shared paths); an empty mount looks like a missing go.mod.
  if ! "${COMPOSE[@]}" --profile terratest \
    run --rm -T --no-deps \
    terratest \
    test -f "/workspace/$rel_dir/go.mod"; then
    echo "ERROR: container cannot see $rel_dir/go.mod — Docker bind-mount of the repo failed." >&2
    echo "  Repo path: $ROOT" >&2
    echo "  On Docker Desktop (macOS), ensure this path is under File sharing" >&2
    echo "  (Settings → Resources → File sharing), or clone/work under your home directory." >&2
    echo "  Host-Go alternative: BOOTSTRAP_WITH_GO=1 bash setup/bootstrap.sh" >&2
    echo "  then: task lab:up && task lab:terratest:host DIR=$rel_dir" >&2
    exit 1
  fi
  "${COMPOSE[@]}" --profile terratest \
    run --rm -T \
    terratest \
    go test -C "/workspace/$rel_dir" -v -count=1 ./...
}

case "$MODE" in
  host|native) run_host ;;
  container|docker|"") run_container ;;
  *)
    echo "ERROR: unknown MODE='$MODE' (expected container|host)" >&2
    exit 1
    ;;
esac
