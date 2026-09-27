#!/bin/sh
# gitleaks wrapper for the CI secret-scan job. POSIX sh: it runs INSIDE the
# digest-pinned gitleaks CLI image (alpine; sh, git and gitleaks only).
#
#   gitleaks-scan.sh history <repo-dir>    scan every commit of <repo-dir>
#   gitleaks-scan.sh control               plant a fake AWS key in a scratch
#                                          repo and require gitleaks to catch it
#   gitleaks-scan.sh check-log <log> [min] judge a gitleaks log (used by both)
#
# Why a wrapper: gitleaks v8 exits 0 and prints "no leaks found" when git
# refused to read the repository at all. In a container action the scan runs
# as root over a runner-owned checkout, git answers "detected dubious
# ownership", gitleaks logs "failed to scan Git repository", and the job goes
# green having scanned nothing. So the verdict comes from the log, and the
# control proves the same image + flags still detect a planted secret.
set -u

die() {
  echo "gitleaks-scan: $*" >&2
  exit 1
}

# check_log LOG [MIN]: the log must show a real scan — no git read failure and
# an "N commits scanned." line with N >= MIN (default 1).
check_log() {
  log=$1
  min=${2:-1}
  [ -r "$log" ] || die "no log at $log"
  if grep -q 'failed to scan' "$log"; then
    die "gitleaks could not read the repository (see the log above); a scan that scanned nothing is not a pass"
  fi
  n=$(sed -n 's/.* \([0-9][0-9]*\) commits scanned\..*/\1/p' "$log" | tail -n 1)
  [ -n "$n" ] || die "no 'N commits scanned.' line in the gitleaks log; refusing to trust the result"
  [ "$n" -ge "$min" ] || die "gitleaks scanned $n commits, expected at least $min"
  echo "gitleaks-scan: $n commits scanned"
}

# run_detect SRC LOG: gitleaks over SRC's git history, trusting SRC as a
# safe.directory for this process only (no global git config is written).
run_detect() {
  src=$1
  log=$2
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$src" \
    gitleaks detect --source "$src" --redact --verbose --no-color >"$log" 2>&1
  rc=$?
  cat "$log"
  return "$rc"
}

scan_history() {
  src=${1:?usage: gitleaks-scan.sh history <repo-dir>}
  log=$(mktemp)
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$src"
  shallow=$(git -C "$src" rev-parse --is-shallow-repository) ||
    die "git cannot read $src"
  [ "$shallow" = false ] ||
    die "$src is a shallow clone; check out with fetch-depth: 0 so every commit is scanned"
  total=$(git -C "$src" rev-list --all --count)
  unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
  run_detect "$src" "$log" || die "gitleaks reported leaks (or failed); see the log above"
  check_log "$log" 1
  echo "gitleaks-scan: repository has $total commits reachable from any ref"
}

scan_control() {
  repo=$(mktemp -d)
  log=$(mktemp)
  # Built at runtime so no key-shaped literal is ever committed to this repo.
  suffix=$(tr -dc 'A-Z2-7' </dev/urandom | head -c 16)
  [ ${#suffix} -eq 16 ] || die "could not generate the planted key"
  git init -q "$repo" || die "git init failed"
  printf 'aws_access_key_id = AKIA%s\n' "$suffix" >"$repo/credentials.env"
  git -C "$repo" add credentials.env &&
    git -C "$repo" -c user.name=control -c user.email=control@example.invalid \
      commit -q -m 'planted secret (positive control)' ||
    die "could not commit the planted secret"
  if run_detect "$repo" "$log"; then
    die "positive control FAILED: gitleaks exited 0 on a repository with a planted AWS key"
  fi
  grep -q 'RuleID:[[:space:]]*aws-access-token' "$log" ||
    die "positive control FAILED: gitleaks exited non-zero but did not report the planted aws-access-token"
  check_log "$log" 1
  echo "gitleaks-scan: positive control OK (planted key detected)"
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case $cmd in
  history) scan_history "$@" ;;
  control) scan_control ;;
  check-log) check_log "$@" ;;
  *) die "usage: gitleaks-scan.sh history <repo-dir> | control | check-log <log> [min]" ;;
esac
