#!/usr/bin/env bash
# scripts/verify.sh — the "tested workshop" gate.
#
# Unit lane (no Docker needed):
#   0. single-run guard: this gate is STATEFUL in the worktree (section 3 runs
#      `tofu init` in place in every lab workdir), so a mkdir-based .verify.lock
#      refuses a second concurrent run in the same checkout rather than letting
#      the two corrupt each other's provider cache
#   1. deps preflight (tofu present, version)
#   2. tofu fmt -check over git-tracked *.tf (minus the S13 messy fixture);
#      falls back to a filesystem walk when the root is not a git work tree
#   3. per module/example/day-2-lab-with-tests, and per day-1/day-3 lab workdir
#      holding *.tf (recursively — day-3 roots are nested under stacks/):
#      tofu init -backend=false + validate
#   4. per module/example/day-2-lab that has *.tftest.hcl: tofu test (plan/mock lanes;
#      *integration*.tftest.hcl deferred to task verify:integration / CI verify-integration)
#   5. slide ↔ lab drift smoke check (source=/chdir=/cd/DIR= → modules|examples exist)
#   6. slide ↔ lab/pages drift ENFORCEMENT (annotated ```hcl blocks diffed vs source;
#      pages/** fences may carry magic-move metadata like ```hcl {none|…})
#   10. toolchain pin drift (versions.env consumers — US-P-PINS)
#   11. version-floor skew (TOFU_FLOOR consumers + per-artifact ceiling —
#       US-D-VERSION-FLOOR)
#   12. tracked-prose pointer hygiene (no pointers into the gitignored
#       planning dir outside the recorded allowlist — ADR 0016)
#
# Everything degrades to "nothing to check yet → pass" while the content dirs
# are empty, so this is safe to wire into CI from day one.
#
# Exit non-zero on any failure. Prints a clear pass/fail summary.
set -euo pipefail

# THE DETECTOR MUST NOT BE A MUTATOR.
#
# `tofu fmt -check` is read-only only while TF_CLI_ARGS and TF_CLI_ARGS_fmt are
# unset. OpenTofu splices those in BEFORE user argv, so a value containing a
# POSITIONAL argument — `-recursive .` is the natural one for someone who wants
# recursive formatting by default — lands ahead of this script's `-check`. The
# positional terminates flag parsing, `-check` is demoted to a path, and tofu
# recursively REWRITES `.`, which after the `cd` below is the entire checkout.
# The error about the unparseable path arrives afterwards, once the files are
# already gone.
#
# Reproduced on this host against labs/day-2/13-static-analysis/messy/main.tf,
# the one file in the repo that is unformatted ON PURPOSE and that this very
# gate allowlists:
#
#   plain:                      rc=3, sha 13f0af5a…  (unchanged, read-only)
#   TF_CLI_ARGS_fmt='-recursive .': rc=2, sha d0b767a2…  (REWRITTEN)
#   TF_CLI_ARGS='-recursive .':     rc=2, sha d0b767a2…  (REWRITTEN)
#
# So the read-only half of this gate's design destroys the teaching fixture it
# exists to protect, and nothing in the repo has to be wrong for it to happen —
# an exported shell variable, a direnv .envrc, or a CI `env:` block is enough.
# This is the shape of the 2026-08-19 fixture destruction arriving by a new
# route, which is why it is neutralised here in verify.sh rather than in `task
# verify`: CI's verify-unit runs `bash scripts/verify.sh` directly, and so does
# every lane's gate matrix.
#
# Scoped to these two variables ONLY. A blanket `TF_*` purge would break the
# repo's legitimate uses — TF_VAR_state_passphrase in the capstone lab, TF_LOG
# when someone is debugging — and swapping a destructive bug for a mystifying
# one is not a fix. Self-tested: "fmt detector — TF_CLI_ARGS/TF_CLI_ARGS_fmt
# cannot turn 'tofu fmt -check' into a rewrite of the tree".
unset TF_CLI_ARGS TF_CLI_ARGS_fmt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Reuse styling helpers if available; otherwise define minimal fallbacks.
if [ -f "$REPO_ROOT/setup/lib.sh" ]; then
  # shellcheck source=setup/lib.sh
  . "$REPO_ROOT/setup/lib.sh"
else
  have() { command -v "$1" >/dev/null 2>&1; }
  ok()   { printf '  [OK]   %s\n' "$*"; }
  bad()  { printf '  [FAIL] %s\n' "$*"; }
  warn() { printf '  [warn] %s\n' "$*"; }
  info() { printf '  [ .. ] %s\n' "$*"; }
  heading() { printf '\n== %s ==\n' "$*"; }
  title() { printf '\n### %s ###\n' "$*"; }
fi

FAILURES=0
CHECKS=0
fail() { bad "$*"; FAILURES=$((FAILURES + 1)); }
pass() { ok "$*"; CHECKS=$((CHECKS + 1)); }

# THE workshop version floor (US-D-VERSION-FLOOR). Single definition: the
# preflight gate below enforces it on the running toolchain, and section 11
# asserts the inventoried consumers that restate it (bootstrap MIN_TOFU, docs,
# deck) still say the same number — so the floor cannot silently re-diverge the way
# the 1.8/1.9 split did. Labs may declare LOWER per-artifact floors (honest
# feature minimums the workshop floor satisfies); no lab may demand more,
# except a step that discloses it inline (Lab 04's S3 stretch, >= 1.10
# use_lockfile — satisfied by the versions.env pin, and stated in the lab).
TOFU_FLOOR="1.9"

title "OpenTofu Workshop · verify (unit lane)"

# ---------------------------------------------------------------------------
# 0. Single-run guard + temp lifetime (US-F-GATEHYG)
#
#    WHY A LOCK AT ALL: since US-C-GATE this gate is STATEFUL in the worktree.
#    Section 3 runs `tofu init -backend=false` IN PLACE in every swept day-1/
#    day-2/day-3 lab workdir, writing labs/**/.terraform/. Nothing serialized that, so two
#    overlapping runs in the same checkout populate the same provider cache
#    directories and shred each other's. The damage does not surface where it
#    was done — it surfaces later, as
#
#        labs/day-2/17-mocking: init failed
#        there is no package for registry.opentofu.org/hashicorp/aws 5.100.0
#        cached in .terraform/providers
#
#    in a directory that VARIES BY TIMING. That reads exactly like a flake, and
#    a failure of that shape has already cost this project a revert of an
#    innocent lane. A gate whose red can be produced by a second copy of itself
#    is not evidence about the diff under test.
#
#    WHY mkdir AND NOT flock: flock(1) is a util-linux tool and is NOT present
#    on macOS/BSD, where this repo is developed. `mkdir` is atomic on every
#    POSIX filesystem and needs nothing installed, so one mechanism covers the
#    darwin dev host and the Linux CI runner. (`set -o noclobber` is the weaker
#    guarantee — its `>|` override semantics vary between shells.)
#
#    WHY $REPO_ROOT AND NOT $TMPDIR: the resource being protected is THIS
#    checkout's lab workdirs, so the lock belongs next to them. A TMPDIR-keyed
#    lock silently stops excluding anything the moment two shells disagree about
#    TMPDIR — which is the normal case under nix-shell and direnv, each of which
#    mints a per-shell temp directory. Deriving it from `git rev-parse --git-dir`
#    was rejected for a different reason: scripts/verify-selftest.sh drives this
#    script inside a NON-git temp root, so every self-test would exercise a
#    fallback while production exercised the primary — the precise "the gate
#    does not test what it certifies" shape this story exists to close.
#
#    .verify.lock is untracked and transient: it exists only while a run is in
#    flight, so it does not sit in `git status` between runs. It is deliberately
#    NOT placed under a `git clean -X`-able path — the documented local gate
#    matrix starts with `git clean -Xfd labs`, and a lock that a routine cleanup
#    can delete out from under a LIVE run is not a lock.
#
#    WHAT IT DOES NOT FIX: the same "no package … cached in .terraform/providers"
#    message is much more often produced by a COLD provider cache on the first
#    run after `git clean -Xfd labs`, with no second process anywhere. This lock
#    cannot help with that; section 3's failure branch names both causes instead.
# ---------------------------------------------------------------------------
VERIFY_LOCK_DIR="$REPO_ROOT/.verify.lock"
VERIFY_LOCK_NAME="${VERIFY_LOCK_DIR#"$REPO_ROOT"/}"
VERIFY_LOCK_HELD=0
VERIFY_HOST="$(uname -n)"
# Every mktemp this script takes is registered here so the exit path can reclaim
# it. The explicit `rm -f`s further down stay: they free early, this is the net
# that catches an exit BETWEEN the mktemp and the rm.
VERIFY_TMP_FILES=()

release_verify_lock() {
  # Only ever remove a lock THIS process owns. Without the guard, the run that
  # was REFUSED the lock would delete the live holder's on its way out — the
  # corruption reopened by the very code that just prevented it, and with a
  # clean-looking refusal on screen. (Self-tested: "the refused run left the
  # holder's lock intact".)
  [ "$VERIFY_LOCK_HELD" -eq 1 ] || return 0
  VERIFY_LOCK_HELD=0
  rm -rf "$VERIFY_LOCK_DIR"
  return 0
}

verify_cleanup() {
  release_verify_lock
  if [ "${#VERIFY_TMP_FILES[@]}" -gt 0 ]; then
    rm -f "${VERIFY_TMP_FILES[@]}"
  fi
  # Never let the cleanup itself decide the exit status.
  return 0
}

# EXIT covers a normal `exit 0`/`exit 1`, every `set -e` death including the
# preflight bail-out below, and — MEASURED, not assumed — an untrapped SIGTERM
# as well: bash's fatal-signal handler runs the EXIT trap before re-raising
# (probe on GNU bash 5.3.15: the trap fired and the shell still exited 143).
# The explicit INT/TERM handlers below are therefore REDUNDANT on this shell.
# That was checked the only way it can be: deleting them does NOT turn the
# "a SIGTERMed run releases its lock" self-test red. They are kept as
# belt-and-braces for shells that do not run the exit trap on a fatal signal,
# and the self-test asserts the OUTCOME, so either mechanism satisfies it.
# SIGKILL is untrappable by anyone — that residue is what the staleness
# detection in acquire_verify_lock is for, and it is self-tested too.
verify_rc=0
trap 'verify_rc=$?; verify_cleanup; exit "$verify_rc"' EXIT
trap 'verify_cleanup; trap - INT;  kill -INT  $$' INT
trap 'verify_cleanup; trap - TERM; kill -TERM $$' TERM

holder_is_alive() {
  # G3: NOT `kill -0`. That conflates ESRCH ("no such process") with EPERM
  # ("alive, but you may not signal it"), so a holder started by another user on
  # this host — `sudo bash scripts/verify.sh`, a CI runner that switches user —
  # reads as DEAD and its LIVE lock gets broken. `ps -p` is POSIX and answers
  # the question actually being asked: does this pid exist?
  ps -p "$1" >/dev/null 2>&1
}

write_verify_lock_metadata() {
  printf '%s\n' "$$"           >"$VERIFY_LOCK_DIR/pid"
  printf '%s\n' "$VERIFY_HOST" >"$VERIFY_LOCK_DIR/host"
  # `date` is only ever read back for the human-facing message.
  date                          >"$VERIFY_LOCK_DIR/started" 2>/dev/null || true
}

# Refuse, naming whoever holds the lock RIGHT NOW rather than whatever this
# process happened to read earlier (review F5). Falls back to the caller's
# values when the lock has since vanished, so the message degrades to stale
# information rather than to no information. Without this, the refusal after a
# lost `mv` race printed the DEAD pid we had just decided to break, announced as
# "already running" — a message that is precisely, confidently wrong, in a lane
# whose thesis is that gate messages must not lie.
refuse_with_current_holder() {
  local fb_pid="$1" fb_host="$2" fb_when="$3"
  local pid host when
  pid="$(cat "$VERIFY_LOCK_DIR/pid" 2>/dev/null || true)"
  host="$(cat "$VERIFY_LOCK_DIR/host" 2>/dev/null || true)"
  when="$(cat "$VERIFY_LOCK_DIR/started" 2>/dev/null || true)"
  [ -n "$pid" ]  || pid="$fb_pid"
  [ -n "$host" ] || host="$fb_host"
  [ -n "$when" ] || when="$fb_when"
  refuse_concurrent_run "$pid" "$host" "$when"
}

refuse_concurrent_run() {
  local pid="$1" host="$2" when="$3"
  bad "another verify.sh is already running in this checkout — refusing to start"
  info "holder: pid ${pid:-unknown} on ${host:-unknown}${when:+, started $when}"
  # G8: the ABSOLUTE path. This message is read wherever the reader happens to
  # be, and `rm -rf .verify.lock` typed from labs/day-1/03-core-workflow removes
  # nothing at all while looking like it worked.
  info "lock:   $VERIFY_LOCK_DIR"
  info "why: this gate runs 'tofu init' IN PLACE in every swept day-1/2/3 lab workdir,"
  info "     so two runs here would write the same labs/**/.terraform/ and corrupt"
  info "     each other's provider cache. The damage would surface later as an init"
  info "     failure in a directory that varies by timing — i.e. as a fake flake."
  info "wait for the other run to finish, or run the second one in its own checkout."
  info "if no such process exists the lock is stale: rm -rf $VERIFY_LOCK_DIR"
  # Distinct from 1 on purpose: 1 means "the gate ran and found problems",
  # 2 means "the gate declined to run and certified nothing".
  exit 2
}

# Undo a `mv` that turned out to have moved somebody's LIVE lock aside.
#
# NOT `mv "$stale_dir" "$VERIFY_LOCK_DIR"` (review F3). When the destination
# already exists as a directory, mv(1) does not fail and does not replace — it
# moves the source INSIDE the destination, returning 0. Verified:
#
#     mv src dst   →  rc 0,  dst/pid  dst/src/pid
#
# So the old `|| rm -rf "$stale_dir"` fallback was unreachable in exactly the
# case it existed to handle, the new holder's lock silently gained a nested
# `.verify.lock.stale.NNN`, and the victim — still believing it holds the lock —
# would delete the NEW holder's directory on its way out.
#
# `mkdir` is the atomic test-and-set that mv(1) is not: it succeeds only if
# nothing is there. So restore = claim the empty slot, then repopulate it with
# the metadata we moved. If someone else has already taken the slot, we restore
# NOTHING and drop the copy, which is the correct outcome — their lock is live
# and ours is a stale snapshot.
#
# RESIDUAL, stated rather than called "best effort": between the `mv` and this
# `mkdir` the victim's lock does not exist, so a third racer can acquire in that
# gap. Then the victim holds VERIFY_LOCK_HELD=1 while a different process owns
# the directory, and the victim's exit will `rm -rf` a lock it no longer owns.
# Reaching that needs three racers AND a hand-deleted lock AND microsecond
# timing; it is not covered by a self-test, and it is the known limit of this
# design rather than something the code silently handles.
restore_moved_lock() {
  local stale_dir="$1"
  if mkdir "$VERIFY_LOCK_DIR" 2>/dev/null; then
    # `.`-glob free: copy the metadata files we know we wrote.
    local f
    for f in pid host started; do
      [ -f "$stale_dir/$f" ] && cp "$stale_dir/$f" "$VERIFY_LOCK_DIR/$f" 2>/dev/null
    done
  fi
  rm -rf "$stale_dir"
  return 0
}

# Break a lock whose holder is gone, and take it — or refuse. Never return
# without doing one of those two things.
#
# THE BUG THIS EXISTS TO CLOSE (review G1). The obvious form is
#
#     read pid -> decide it is dead -> rm -rf the lock -> mkdir it again
#
# and between the read and the `rm` sit three forks and a `warn` write. If any
# other run acquires the lock in that gap, the `rm -rf` destroys a LIVE lock
# while announcing "breaking it", and two runs then `tofu init` in the same lab
# workdirs — precisely the corruption this whole guard exists to prevent, with a
# confident message on top. A re-`mkdir` afterwards does not help: it only
# covers someone acquiring between the `rm` and the `mkdir`, which is the
# narrower half of the window.
#
# Two racers B and C both finding the same stale lock is not exotic either. A
# SIGKILL (an agent-harness timeout, a laptop sleep) leaves the stale lock, and
# a parallel lane launch supplies the second starter.
#
# The arbitration primitive here is `mv`, not `mkdir`: renaming a directory
# within the same parent is a single `rename(2)`, and it fails for everyone
# except the one caller whose source still exists. So of any number of
# simultaneous breakers, exactly ONE can move the lock aside, and the losers
# find their source gone and refuse. `mkdir` cannot do this job — two breakers
# can both `rm -rf` and both `mkdir`, and the loser's `rm` deletes the winner's
# fresh lock.
#
# A rename is also the right failure mode. If this process is killed between the
# `mv` and the re-`mkdir`, what is stranded is a `.verify.lock.stale.<pid>`
# directory and NO lock — so the next run acquires normally. A break TOKEN, the
# other obvious design, strands the token instead and then refuses every future
# break, wedging the checkout: strictly worse than the bug being fixed.
break_stale_lock_and_acquire() {
  local pid="$1" host="$2" when="$3"
  local stale_dir="$VERIFY_LOCK_DIR.stale.$$" moved_pid
  # 1. Re-read first, cheaply and with no side effects. If the holder changed
  #    between the read above and now, someone re-acquired and there is nothing
  #    stale here — leave their lock strictly alone. This is a courtesy, NOT the
  #    safety property: step 2 is what actually prevents two holders, and the
  #    two-breaker self-test drives step 2 with this step already satisfied.
  if [ "$(cat "$VERIFY_LOCK_DIR/pid" 2>/dev/null || true)" != "$pid" ]; then
    refuse_with_current_holder "$pid" "$host" "$when"
  fi
  # 2. Claim the break by moving the lock aside. THIS is the arbitration: of any
  #    number of racers that got past step 1 holding the same dead pid, exactly
  #    one `rename(2)` can succeed, and the losers find their source gone.
  if ! mv "$VERIFY_LOCK_DIR" "$stale_dir" 2>/dev/null; then
    refuse_with_current_holder "$pid" "$host" "$when"
  fi
  # 3. Confirm what was actually moved. Step 1 can still be beaten by a narrow
  #    interleaving — a lock removed by hand and re-acquired between the re-read
  #    and the `mv` — and this is the last chance to notice before the contents
  #    are gone.
  moved_pid="$(cat "$stale_dir/pid" 2>/dev/null || true)"
  if [ "$moved_pid" != "$pid" ]; then
    restore_moved_lock "$stale_dir"
    refuse_with_current_holder "$moved_pid" "$host" "$when"
  fi
  warn "stale $VERIFY_LOCK_DIR left by pid $pid (no longer running) — breaking it"
  rm -rf "$stale_dir"
  if mkdir "$VERIFY_LOCK_DIR" 2>/dev/null; then
    VERIFY_LOCK_HELD=1
    write_verify_lock_metadata
    return 0
  fi
  # Someone acquired in the instant after the break. Correct and expected —
  # breaking is not acquiring.
  refuse_with_current_holder "$pid" "$host" "$when"
}

acquire_verify_lock() {
  local pid host when
  if mkdir "$VERIFY_LOCK_DIR" 2>/dev/null; then
    VERIFY_LOCK_HELD=1
    write_verify_lock_metadata
    return 0
  fi
  # `mkdir` failing does NOT prove contention. It also fails on a read-only or
  # full filesystem, on a permissions problem, and — the one seen in practice —
  # when something left a regular FILE called .verify.lock in the way. Blaming a
  # concurrent run for those would send the reader hunting a process that does
  # not exist, which is the same class of misdiagnosis this whole guard exists
  # to end. Only treat it as contention once the lock is actually a directory.
  if [ ! -d "$VERIFY_LOCK_DIR" ]; then
    bad "cannot create $VERIFY_LOCK_NAME — the single-run guard cannot be established"
    info "this is NOT a concurrent run: something other than a lock directory is in"
    info "the way, or $REPO_ROOT is not writable."
    info "check: ls -ld $VERIFY_LOCK_DIR  (a stray regular file? remove it)"
    exit 2
  fi
  pid="$(cat "$VERIFY_LOCK_DIR/pid" 2>/dev/null || true)"
  host="$(cat "$VERIFY_LOCK_DIR/host" 2>/dev/null || true)"
  when="$(cat "$VERIFY_LOCK_DIR/started" 2>/dev/null || true)"
  # Staleness, conservatively. Break the lock ONLY when this host recorded it
  # (a pid from another machine says nothing about any process here) and that
  # pid is provably gone. A missing or non-numeric pid file is NOT staleness —
  # it is most likely the holder having won the mkdir microseconds ago and not
  # yet written its metadata, and breaking that would be the original bug with
  # extra steps.
  case "$pid" in
    '' | *[!0-9]*) refuse_concurrent_run "$pid" "$host" "$when" ;;
  esac
  if [ "$host" = "$VERIFY_HOST" ] && ! holder_is_alive "$pid"; then
    # The breaker either acquires and returns 0, or refuses and exits — it never
    # returns without resolving. So this `return` is unconditional, and leaving
    # it out let a SUCCESSFUL break fall straight through into the refusal
    # below. (It did: the two-racer case went green while the ordinary
    # stale-break case started failing with exit 2.)
    break_stale_lock_and_acquire "$pid" "$host" "$when"
    return 0
  fi
  refuse_concurrent_run "$pid" "$host" "$when"
}

acquire_verify_lock

# ---------------------------------------------------------------------------
# 1. Deps preflight
# ---------------------------------------------------------------------------
heading "Preflight"
if have tofu; then
  # This is the FIRST external call the gate makes, and it used to be:
  #     TOFU_VER="$(tofu version 2>/dev/null | head -n1 | awk '{print $2}')"
  # which packs two silent-death traps into one line under `set -euo pipefail`
  # (line 22):
  #
  #   1. `2>/dev/null` throws away tofu's OWN diagnosis, so a failing probe
  #      leaves nothing to read.
  #   2. `head` as a pipe SINK closes the pipe as soon as it has its line;
  #      the upstream `tofu` takes SIGPIPE and `pipefail` surfaces it.
  #
  # Either way the assignment is a plain command, so `set -e` kills verify.sh
  # right here — after the "Preflight" heading and before anything else prints.
  # CI caught exactly that (job 96001788290, 2026-08-19): a FOUR-line run —
  # blank, title, blank, "Preflight" — exiting 1 with no failure message. It
  # had been read as an unexplainable flake and cost a revert, because a gate
  # that dies without a word gives its reader nothing to go on.
  #
  # Now: capture rc instead of dying (`|| rc=$?` is exempt from errexit), keep
  # stderr, and parse with `awk` reading to EOF so there is no early close.
  # stdout is PARSED, stderr is only REPORTED — deliberately separate streams.
  # Merging them (`2>&1`) and parsing line 1 looks harmless until anything emits
  # a warning first: a proxy notice, TF_LOG, a dyld message. Then line 1 is the
  # warning, `$2` is a word out of it, min_version strips it to empty, and a
  # perfectly good toolchain reds the gate with "tofu <junk> is below the
  # required floor". That would be a NEW spurious-red path introduced by the very
  # change meant to remove one — so stderr goes to a file, out of the parser's
  # way, and is echoed only when the probe actually fails.
  TOFU_VER_RC=0
  TOFU_VER_ERR="$(mktemp)"
  VERIFY_TMP_FILES+=("$TOFU_VER_ERR")
  TOFU_VER_OUT="$(tofu version 2>"$TOFU_VER_ERR")" || TOFU_VER_RC=$?
  TOFU_VER="$(printf '%s\n' "$TOFU_VER_OUT" | awk 'NR == 1 { print $2 }')"
  if [ "$TOFU_VER_RC" -ne 0 ] || [ -z "$TOFU_VER" ]; then
    fail "tofu version probe failed (exit $TOFU_VER_RC) — cannot establish the toolchain version"
    info "tofu said:"
    # Both streams here: when the probe fails, whatever it managed to say is the
    # whole of the evidence, and dropping either half is how this became a
    # mystery in the first place.
    { printf '%s\n' "$TOFU_VER_OUT"; cat "$TOFU_VER_ERR"; } | sed 's/^/    /'
  elif min_version "${TOFU_VER#v}" "$TOFU_FLOOR"; then
    pass "tofu ${TOFU_VER} (>= $TOFU_FLOOR)"
  else
    fail "tofu ${TOFU_VER} is below the required $TOFU_FLOOR"
  fi
  rm -f "$TOFU_VER_ERR"
else
  fail "tofu not found on PATH (install: brew install opentofu)"
  heading "Summary"
  bad "verify FAILED — tofu is required. $FAILURES failure(s)."
  exit 1
fi

# Collect module/example dirs that actually contain Terraform/OpenTofu code,
# plus EVERY lab workdir under days 1/2/3 that holds .tf (US-C-GATE for days
# 1/3; US-E-D2SWEEP folded day-2 into the same recursive scan — see the WHY
# block below for the two intentionally-broken day-2 fixtures it excludes).
# nullglob makes empty globs vanish instead of expanding to a literal '*'.
shopt -s nullglob
CODE_DIRS=()
for base in modules examples; do
  for d in "$base"/*/; do
    [ -d "$d" ] || continue
    # any .tf at the top of the dir counts as a config
    tf=("$d"*.tf)
    [ "${#tf[@]}" -gt 0 ] && CODE_DIRS+=("${d%/}")
  done
done
# Day-1 / Day-2 / Day-3 lab workdirs (US-C-GATE, extended by US-E-D2SWEEP).
#
# WHY THIS EXISTS: these two days shipped ZERO semantic validation. A dangling
# reference in a Day-1 lab was caught only INDIRECTLY, by the §6 drift gate
# noticing that the annotated ```hcl block no longer matched its source file.
# Regenerate that block — exactly what a curriculum story asks an author to do —
# and the gate goes green over structurally broken HCL, which the learner then
# meets as a failing `tofu plan`. Nothing in CI ran `task lab:validate`.
#
# WHY DAY-2 IS IN THIS SWEEP TOO (US-E-D2SWEEP): day-2 used to have its own
# loop that only picked workdirs shipping *.tftest.hcl (audit TEST-A2), which
# left 18-terratest-cost/, 18-terratest-cost/cost/ and 19-testing-cicd/fixture/
# fmt-only — with audit TEST-1, lab 18 had ZERO semantic gates (audit TEST-2).
# Sweeping .tf directly subsumes that loop: every dir it found (12, 16, 17)
# holds .tf, and §3/§4 below still run each discovered dir's *.tftest.hcl, so
# tftest execution is unchanged — only validate coverage widened.
#
# WHY RECURSIVE: Day-3's runnable roots are NESTED, never at the top of the
# lab dir — Terramate stacks live at labs/day-3/NN-topic/stacks/<name>/ and
# the Terragrunt comparison at .../terragrunt-style/units/<name>/. A
# top-level-only scan would validate 1 of the 15 Day-3 roots. Day-1 nests too
# (07-modules/modules/service-manifest, a child module; 02-hcl-blocks/greeting),
# and so does Day-2: 18-terratest-cost/cost/ (the Infracost stretch fixture)
# and 19-testing-cicd/fixture/ are runnable roots below the lab dir. Child
# modules are validated as roots as well: it costs ~1s, and it keeps them
# covered even when no parent references them. `**/` matches zero or more
# directories, so top-level roots are included.
#
# EXACTLY TWO EXCLUSIONS, BY PATH, both intentionally-broken teaching fixtures:
#   labs/day-2/13-static-analysis/messy/   — its `default = "payments"` for a
#       list(string) fails even `tofu init`; S13 exists to let learners point
#       tflint at broken HCL (the fmt gate allowlists the same file, see
#       S13_MESSY_FIXTURE below);
#   labs/day-2/14-security-scanners/messy/ — S14's deliberately insecure
#       scanner fodder; validating it green would teach nothing and any red is
#       noise, not rot.
# Prefix match, not exact-dir: anything a story later nests UNDER messy/ is
# fixture too. BY PATH, not by count or by "fails validate": an exclusion that
# keys on breakage would silently swallow real rot in a real lab. Every OTHER
# discovered root inits and validates standalone today (Day-3's generated
# _providers.tf/_backend.tf are committed, so no `terramate generate` is
# needed first).
#
# ASYMMETRY WITH §2, ON PURPOSE: the fmt scan is scoped to the git INDEX so a
# sibling worktree or untracked file cannot red a clean tree. This scan is a
# filesystem sweep, because `tofu validate` reads whatever .tf sits in the
# directory — index-scoping the DISCOVERY would change nothing, tofu would still
# read the scratch file. So a learner mid-lab with the gitignored break→fix
# `broken.tf` in place WILL red this gate locally; the failure branch below says
# so by name. Accepted rather than excluded: a directory holding an ignored file
# is not a reason to stop validating it. CI checkouts have no ignored scratch.
declare -A LAB_DIR_SEEN=()
shopt -s globstar
for base in labs/day-1 labs/day-2 labs/day-3; do
  [ -d "$base" ] || continue
  for tf_path in "$base"/**/*.tf; do
    [ -f "$tf_path" ] || continue
    d="${tf_path%/*}"
    # Provider plugins that a previous run installed are not lab source. Without
    # this the check COUNT grows between two consecutive runs of an unchanged
    # tree — a gate whose result depends on whether it has run before.
    case "$d" in */.terraform | */.terraform/*) continue ;; esac
    # The two intentionally-broken teaching fixtures — see EXACTLY TWO
    # EXCLUSIONS above for why these paths, why prefix, and why nothing else.
    case "$d" in
      labs/day-2/13-static-analysis/messy | labs/day-2/13-static-analysis/messy/* | \
      labs/day-2/14-security-scanners/messy | labs/day-2/14-security-scanners/messy/*) continue ;;
    esac
    [ -n "${LAB_DIR_SEEN[$d]+set}" ] && continue
    LAB_DIR_SEEN["$d"]=1
    CODE_DIRS+=("$d")
  done
done
shopt -u globstar
shopt -u nullglob

# ---------------------------------------------------------------------------
# 2. fmt -check (git-tracked .tf except the intentional S13 break→fix fixture)
#
#    Scope is the git INDEX, not a filesystem walk (US-F-VERIFY-WT). A walk also
#    descends into whatever else happens to sit under the repo root — most
#    painfully sibling git worktrees at .worktrees/<lane>/, each holding its own
#    copy of the whole tree INCLUDING the deliberately-unformatted S13 fixture.
#    That turned a clean tree red with another lane's fixture, purely locally
#    (CI checkouts have no siblings), which trains people to ignore the gate.
#    Scanning the index excludes every sibling worktree, node_modules, provider
#    cache and future untracked directory structurally — no exclusion list to
#    keep in sync — and makes the pass message below actually true.
#
#    Trade-off: a brand-new .tf that has never been `git add`ed is not scanned.
#    It is picked up the moment it is staged, and CI checkouts are fully tracked.
#
#    FALLBACK: scripts/verify-selftest.sh copies this script into a throwaway
#    temp root that is NOT a git work tree, where `git ls-files` would exit 128
#    and yield an empty list — i.e. a silently disarmed gate. When the root is
#    not a work tree we fall back to the filesystem walk, with .worktrees/ added
#    to the exclusions so the fallback is worktree-safe too. Both paths are
#    covered by verify-selftest.sh.
#
#    An empty scan is NEVER a pass on the git path, whether git exits non-zero
#    or exits 0 with no output (deleted/absent index, bogus GIT_INDEX_FILE), and
#    tracked paths missing from the worktree are warned rather than dropped in
#    silence. The empty→pass degradation survives only on the find path, where it
#    means "no content authored yet".
# ---------------------------------------------------------------------------
S13_MESSY_FIXTURE='labs/day-2/13-static-analysis/messy/main.tf'
# A .git ENTRY at the root is the discriminator: a directory in a normal clone,
# a file in a linked worktree, absent in the self-test's temp root. Deliberately
# not a `git rev-parse --show-toplevel` path comparison — that returns the
# PHYSICAL path while REPO_ROOT is logical, so on macOS (/var → /private/var)
# it would mis-route to the fallback without anyone noticing.
FMT_SCAN_OK=1
FMT_SCAN_ERR=""
FMT_SKIPPED=0
if have git && [ -e "$REPO_ROOT/.git" ]; then
  heading "Formatting (tofu fmt -check; git-tracked .tf, S13 messy fixture excluded)"
  FORMAT_FILES=()
  # Route via a temp file rather than `< <(git ls-files …)`: process substitution
  # discards the exit status, so a git that REFUSES (stale linked-worktree gitdir,
  # safe.directory/dubious ownership, corrupt index) would yield an empty list and
  # short-circuit into the green "canonically formatted" message below — a gate
  # reporting success over a tree it never scanned. Command substitution is not an
  # option either: "$(git ls-files -z)" strips NUL bytes and collapses the list
  # into one bogus path.
  GIT_TF_LIST="$(mktemp)"
  GIT_TF_ERR="$(mktemp)"
  VERIFY_TMP_FILES+=("$GIT_TF_LIST" "$GIT_TF_ERR")
  # Keep git's OWN diagnosis (dubious ownership, corrupt index, …) instead of
  # discarding it and leaving the operator to guess between the causes.
  git ls-files -z -- '*.tf' >"$GIT_TF_LIST" 2>"$GIT_TF_ERR" || FMT_SCAN_OK=0
  # A non-zero exit is only HALF the failure surface: git also fails SOFTLY,
  # exiting 0 with empty output — a deleted .git/index, a fresh `git init` with
  # nothing staged, or GIT_INDEX_FILE pointing at a nonexistent index all do
  # this. An empty list then short-circuits into the green message below, over a
  # tree that was never scanned. Gate on RAW OUTPUT emptiness, deliberately not
  # on ${#FORMAT_FILES[@]}: a repo whose only tracked .tf is the S13 fixture
  # legitimately filters down to an empty array and must stay a pass.
  [ -s "$GIT_TF_LIST" ] || FMT_SCAN_OK=0
  if [ "$FMT_SCAN_OK" -eq 1 ]; then
    while IFS= read -r -d '' tf_file; do
      [ "$tf_file" = "$S13_MESSY_FIXTURE" ] && continue
      # Tracked but not present in the worktree: a staged deletion, sparse
      # checkout or skip-worktree bit. Skip it — handing tofu fmt a missing path
      # would fail with a misleading message — but SAY SO. Silently dropping
      # every entry would otherwise leave a green gate asserting that all tracked
      # files were checked. Warn rather than fail: a legitimately staged-deleted
      # file must not manufacture a fresh false-red.
      if [ ! -f "$tf_file" ]; then
        warn "fmt scan: tracked .tf absent from the worktree — skipped: $tf_file"
        FMT_SKIPPED=$((FMT_SKIPPED + 1))
        continue
      fi
      FORMAT_FILES+=("$tf_file")
    done <"$GIT_TF_LIST"
  else
    # `head` must be the SOURCE of this pipeline, not its sink: as a sink it
    # closes the pipe early and can SIGPIPE the upstream `tr`, which under
    # `set -o pipefail` fails the substitution and `set -e` kills the script —
    # inside the branch whose entire job is to REPORT a failure. Multi-line
    # stderr (safe.directory dubious-ownership is ~5 lines) is the trigger.
    FMT_SCAN_ERR="$(head -n 3 "$GIT_TF_ERR" | tr -d '\r' | tr '\n' ' ')"
  fi
  rm -f "$GIT_TF_LIST" "$GIT_TF_ERR"
else
  heading "Formatting (tofu fmt -check; no git index — filesystem walk, S13 messy fixture + agent/cache/worktree paths excluded)"
  FORMAT_FILES=()
  while IFS= read -r -d '' tf_file; do
    FORMAT_FILES+=("$tf_file")
  done < <(find . -type f -name '*.tf' \
    ! -path "./$S13_MESSY_FIXTURE" \
    ! -path './.claude/*' \
    ! -path './.worktrees/*' \
    ! -path './node_modules/*' \
    ! -path '*/.terraform/*' \
    -print0)
fi

if [ "$FMT_SCAN_OK" -eq 0 ]; then
  # Never degrade an unknown file set to a pass. The empty-list→pass below is a
  # deliberate "nothing to check yet" degradation for the find path; here the
  # list is empty because the scan BROKE, which is a different thing entirely.
  fail "fmt scan: 'git ls-files' returned no usable file list at a root that has a .git entry (stale worktree gitdir, safe.directory, or corrupt/absent index) — refusing to report a green gate on an unknown file set"
  [ -n "$FMT_SCAN_ERR" ] && info "git said: $FMT_SCAN_ERR"
elif [ "${#FORMAT_FILES[@]}" -eq 0 ] || tofu fmt -check "${FORMAT_FILES[@]}" >/dev/null 2>&1; then
  # Any suffix here must stay a SUFFIX: the base sentence is grepped verbatim by
  # several verify-selftest.sh cases.
  if [ "$FMT_SKIPPED" -gt 0 ]; then
    pass "all tracked .tf files outside the S13 messy fixture are canonically formatted — except ${FMT_SKIPPED} absent from the worktree (skipped; see warnings above)"
  else
    pass "all tracked .tf files outside the S13 messy fixture are canonically formatted"
  fi
else
  # The parenthetical used to read "(tofu fmt -recursive)". It was removed
  # deliberately: a bare recursive format REWRITES the deliberately-unformatted
  # S13 teaching fixture at labs/day-2/13-static-analysis/messy/main.tf, which
  # this very gate allowlists — so the remedy printed next to a red gate was the
  # one command that silently destroys a lab. That fired in the wild on
  # 2026-08-19. Name only the task target, which is being made index-scoped.
  fail "unformatted files found — run 'task lab:fmt'"
  info "offending files:"
  tofu fmt -check "${FORMAT_FILES[@]}" 2>/dev/null | sed 's/^/    /' || true
fi

# ---------------------------------------------------------------------------
# 3 & 4. validate + test per code dir
# ---------------------------------------------------------------------------
heading "Validate & test (modules · examples · labs/day-1 · labs/day-2 · labs/day-3)"
if [ "${#CODE_DIRS[@]}" -eq 0 ]; then
  warn "no modules/* / examples/* / labs/day-1|day-2|day-3 roots with .tf files yet — nothing to validate."
  info "This is expected before lab content is authored. (pass)"
else
  # init's output used to go straight to /dev/null, so the failure branch below
  # could only ever say "init failed" and nothing else — no message, no cause,
  # nothing to act on. Capture it once and reuse the file for every directory.
  INIT_LOG="$(mktemp)"
  VERIFY_TMP_FILES+=("$INIT_LOG")
  for d in "${CODE_DIRS[@]}"; do
    info "→ $d"
    # init without a backend so validate has its providers, no remote state.
    if tofu -chdir="$d" init -backend=false -input=false >"$INIT_LOG" 2>&1; then
      if tofu -chdir="$d" validate -no-color >/dev/null 2>&1; then
        pass "$d: validate"
      else
        fail "$d: validate"
        tofu -chdir="$d" validate -no-color 2>&1 | sed 's/^/    /' || true
        # A learner part-way through a lab may have SCRATCH .tf in the workdir —
        # every day-1 lab .gitignore lists the break→fix `broken.tf`, which is
        # deliberately invalid (lab 03's is a dependency cycle). §2's fmt scan is
        # scoped to the git index and never sees such files; `tofu validate`
        # reads every .tf in the directory and reds on them. Name them, so the
        # failure explains itself instead of reading as repo rot. Deliberately
        # NOT an exclusion: skipping a directory because it holds an ignored file
        # would reopen the exact hole this check closes (US-C-GATE). CI checkouts
        # carry no ignored scratch, so this only ever fires locally.
        if have git && [ -e "$REPO_ROOT/.git" ]; then
          shopt -s nullglob
          scratch_tf=()
          for cand in "$d"/*.tf; do
            if git check-ignore -q "$cand" 2>/dev/null; then
              scratch_tf+=("$cand")
            fi
          done
          shopt -u nullglob
          if [ "${#scratch_tf[@]}" -gt 0 ]; then
            info "$d: git-ignored scratch .tf present — remove before re-running: ${scratch_tf[*]}"
          fi
        fi
      fi
    else
      # ENCRYPTED LEARNER STATE is not repo rot, and reporting it as such sends
      # the learner hunting a defect that is not there. `init -backend=false`
      # still loads the local state to decide whether the backend changed, and
      # with -backend=false the `encryption {}` block is never configured — so
      # any workdir holding state a learner produced under state encryption
      # (Lab 05 teaches it; Lab 08 Step 4 applies with it) dies here with
      # "Unsupported state file format". The learner did exactly what the lab
      # said, then ran the gate the workshop tells them to run, and got a red.
      #
      # Same discrimination as the git-ignored scratch .tf block above: *.tfstate
      # is git-ignored, so a state file present here is a LOCAL artifact by
      # construction. A CI checkout carries none, so this never softens CI —
      # there, an encrypted-state init failure would still be a genuine fail.
      # Deliberately a warn and NOT a pass: the directory really was not
      # validated, and the gate says so along with the one command that fixes it.
      init_enc_state=""
      if grep -q 'state file is encrypted' "$INIT_LOG" && have git && [ -e "$REPO_ROOT/.git" ]; then
        shopt -s nullglob
        for cand in "$d"/*.tfstate; do
          if git check-ignore -q "$cand" 2>/dev/null; then
            init_enc_state="$cand"
            break
          fi
        done
        shopt -u nullglob
      fi
      if [ -n "$init_enc_state" ]; then
        warn "$d: not validated — ${init_enc_state#"$REPO_ROOT"/} is encrypted local state, which init -backend=false cannot read"
        info "$d: this is YOUR lab state, not a repo defect. Clear it and re-run:"
        info "    TF_VAR_state_passphrase=… tofu -chdir=$d destroy -auto-approve && rm -f $d/*.tfstate*"
        # Skips this directory's validate AND its tofu test, unlike the fail
        # branch below which falls through and still attempts the test. That is
        # deliberate: the test would hit the same unreadable state file and
        # produce a second, more confusing error about the same one cause.
        continue
      fi
      fail "$d: init failed (cannot validate)"
      sed 's/^/    /' "$INIT_LOG" || true
      # TWO different mechanisms produce this one message, and telling them
      # apart by hand has already cost this project real debugging time — plus
      # one revert of an innocent lane. Neither is a defect in the diff under
      # test, and the lock above only rules out ONE of them.
      if grep -qE 'no package for registry|cached in \.terraform/providers' "$INIT_LOG"; then
        info "$d: that is the provider-cache signature. It has TWO causes:"
        info "  (1) a COLD or partial provider cache — typically the FIRST run"
        info "      after 'git clean -Xfd labs' removed every .terraform/."
        info "      Nothing in this script fixes that: re-run verify once, on its"
        info "      own, and it clears. Treat the SECOND run as the result."
        info "  (2) another process writing .terraform/ in this checkout at the"
        info "      same time. A concurrent verify.sh is already ruled out — the"
        info "      $VERIFY_LOCK_NAME guard refused it — but a stray 'tofu init'"
        info "      or 'task lab:apply' in another terminal is not."
        info "  Both pick a DIFFERENT directory each time, which is why this"
        info "  reads like a flake. Re-run serialized before suspecting the diff."
      fi
      # THE OTHER wandering red: the registry did not answer in time. This sweep
      # runs `tofu init` in ~50 directories back to back, so a slow or rate-
      # limited registry.opentofu.org surfaces as a handful of failures that land
      # on a DIFFERENT directory every run — indistinguishable, at a glance, from
      # the cache signature above and equally unrelated to the diff under test.
      # It is called out separately because the remedy differs: the cache case
      # clears on a re-run, this one clears when the network does.
      if grep -qE 'Failed to resolve provider packages|Client\.Timeout|context deadline exceeded|TLS handshake timeout|failed to request discovery document' "$INIT_LOG"; then
        info "$d: that is a REGISTRY REACHABILITY signature, not a config defect."
        info "  This sweep inits ~50 directories in a row; a slow or rate-limited"
        info "  registry.opentofu.org drops a few of them, and it picks different"
        info "  directories each run. Check connectivity, then re-run:"
        info "    curl -sS -o /dev/null -w '%{http_code} %{time_total}s\\n' \\"
        info "      https://registry.opentofu.org/v1/providers/hashicorp/aws/versions"
        info "  A warm .terraform/ avoids the round trip entirely, so a directory"
        info "  whose cache you just cleared is the most likely one to fail here."
      fi
    fi

    # tofu test if the dir (or its tests/ subdir) ships *.tftest.hcl.
    # UNIT LANE ONLY: integration files (…integration….tftest.hcl) need
    # LocalStack/Docker and belong to `task verify:integration` / the CI
    # verify-integration job — exclude them here and run each remaining file
    # explicitly with -filter.
    shopt -s nullglob
    tests=("$d"/*.tftest.hcl "$d"/tests/*.tftest.hcl)
    shopt -u nullglob
    unit_filters=()
    skipped_integration=0
    for t in "${tests[@]}"; do
      case "$t" in
        *integration*.tftest.hcl) skipped_integration=$((skipped_integration + 1)) ;;
        *) unit_filters+=("-filter=${t#"$d"/}") ;;  # path relative to -chdir
      esac
    done
    if [ "${#unit_filters[@]}" -gt 0 ]; then
      if tofu -chdir="$d" test "${unit_filters[@]}" >/dev/null 2>&1; then
        pass "$d: tofu test (plan/mock)"
      else
        fail "$d: tofu test"
        tofu -chdir="$d" test "${unit_filters[@]}" 2>&1 | sed 's/^/    /' | tail -n 30 || true
      fi
    elif [ "${#tests[@]}" -gt 0 ]; then
      info "$d: only integration test(s) — deferred to task verify:integration / CI verify-integration"
    else
      info "$d: no *.tftest.hcl — skipping tofu test"
    fi
    [ "$skipped_integration" -gt 0 ] && info "$d: skipped ${skipped_integration} integration file(s) (unit lane)"
  done
fi

# ---------------------------------------------------------------------------
# 5. Slide ↔ lab drift smoke check
#    Labs mix two kinds of HCL:
#      (a) learner-scratch snippets (files the learner creates, e.g. bucket.tf)
#          and inline teaching blocks — these are NOT expected to exist in-repo.
#      (b) references to SHARED repo code under modules/ or examples/ — these
#          MUST exist on disk, or a slide has drifted from runnable source.
#    We assert (b) only for real runnable citations (US-F-R4):
#      · HCL `source = "…modules|examples/…"`
#      · shell entrypoints: `tofu -chdir=…`, `cd …`, `DIR=…` / `task lab:* DIR=…`
#    Bare prose / markdown links mentioning those prefixes are ignored.
#    Annotated `<!-- source: -->` paths are existence-checked + byte-diffed by §6.
# ---------------------------------------------------------------------------
heading "Slide ↔ lab drift smoke check"
shopt -s nullglob globstar
LAB_FILES=(labs/**/*.md)
shopt -u nullglob globstar
if [ "${#LAB_FILES[@]}" -eq 0 ]; then
  warn "no lab Markdown under labs/ yet — drift check is a no-op. (pass)"
  info "TODO: once labs exist, assert each modules/|examples/ path they cite exists."
else
  HCL_BLOCKS=0
  MISSING_REFS=0
  CHECKED_REFS=0
  for f in "${LAB_FILES[@]}"; do
    n="$(grep -c '^```hcl' "$f" 2>/dev/null || true)"
    HCL_BLOCKS=$((HCL_BLOCKS + ${n:-0}))
    # Extract modules/... or examples/... from real runnable citations only:
    # HCL source = "…", tofu -chdir=…, cd …, and DIR=… (task lab:* DIR=…).
    # Bare prose mentioning those prefixes must not hard-fail (US-F-R4).
    #
    # A ref may be a REPO-ROOT shared-code path (modules/foo, examples/bar) OR a
    # path RELATIVE to the lab's own workdir — a lab under labs/day-N/NN-topic/
    # may carry a local `modules/` subdir (e.g. a child module reached via
    # `source = "./modules/service-manifest"`). Accept either: pass if the ref
    # exists at repo root OR under the lab's sibling workdir
    # (labs/day-N/NN-topic/<ref>). Only a ref resolving under neither fails.
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      ref="${ref%%[\`\"\')]*}"
      CHECKED_REFS=$((CHECKED_REFS + 1))
      if [ -e "$ref" ] || [ -e "${f%.md}/$ref" ]; then
        pass "lab ref exists: $ref  ($(basename "$f"))"
      else
        fail "lab ref missing on disk: $ref  (cited in $f)"
        MISSING_REFS=$((MISSING_REFS + 1))
      fi
    # Collect candidate citation tokens, then peel modules|examples paths.
    # Relative prefixes (./, ../../) are discarded by the peel. Trailing
    # punctuation/backticks are stripped by the char class / ref trim above.
    done < <({
      grep -hoE 'source[[:space:]]*=[[:space:]]*"[^"]*"' "$f" 2>/dev/null || true
      grep -hoE -- '-chdir=[^[:space:]]+' "$f" 2>/dev/null || true
      grep -hoE '(^|[[:space:`$])cd[[:space:]]+[^[:space:]]+' "$f" 2>/dev/null || true
      grep -hoE 'DIR=[^[:space:]]+' "$f" 2>/dev/null || true
    } | grep -hoE '(modules|examples)/[A-Za-z0-9_./-]+' 2>/dev/null \
      | sed 's:/*$::' | sort -u)
  done
  info "scanned ${#LAB_FILES[@]} lab file(s): ${HCL_BLOCKS} \`\`\`hcl block(s), ${CHECKED_REFS} shared-code reference(s)"
  if [ "$CHECKED_REFS" -eq 0 ]; then
    info "no modules/|examples/ references in labs (all HCL is scratch/inline) — nothing to drift-check yet"
  elif [ "$MISSING_REFS" -eq 0 ]; then
    pass "all shared-code references cited by labs exist on disk"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Slide ↔ lab/pages drift ENFORCEMENT (annotated fenced blocks)
#    Contract (see docs/authoring-guide.md · "Lab workdir & drift contract"): a fenced ```hcl
#    block may be tied to a tracked source file by an HTML comment marker on the
#    line immediately above the fence:
#
#        <!-- source: labs/fixtures/drift-demo/main.tf -->
#        ```hcl
#        ...exact file contents...
#        ```
#
#    The same contract applies under pages/SNN-*/index.md and the template
#    gallery deck slides-templates.md (audit TEST-A4). Slidev magic-move
#    fences carry highlight metadata on the opening fence line:
#
#        ```hcl {none|1-4|all}
#
#    That metadata is fence chrome, not block content — the extractor tolerates
#    it so annotated slide blocks can be drift-checked instead of false-failing
#    (or silently disarming) on the bare-```hcl selector.
#
#    Rules:
#      · annotated block  → its content is diffed against the named file;
#        drift OR a missing file FAILS the build, naming the file (criterion #2).
#      · unannotated block → ignored (only counted/warned) so partially-authored
#        labs never block unrelated lanes (criterion #3).
#      · a file that has ```hcl block(s) but ZERO annotated ones → warn, not fail.
# ---------------------------------------------------------------------------
heading "Slide ↔ lab/pages drift enforcement (annotated blocks)"
shopt -s nullglob globstar
DRIFT_FILES=(labs/**/*.md pages/**/*.md slides-templates.md)
shopt -u nullglob globstar
if [ "${#DRIFT_FILES[@]}" -eq 0 ]; then
  warn "no lab/pages/templates Markdown yet — nothing to enforce. (pass)"
else
  ANNOTATED=0
  DRIFTED=0
  # awk emits one record per annotated block:
  #   \x01<source-path>\n<block-body...>\x02\n
  # It only arms on a `<!-- source: PATH -->` line that is IMMEDIATELY followed
  # by an opening ```hcl fence (optional magic-move `{…}` metadata allowed); a
  # marker not hugging a fence is ignored. Using \x01/\x02 sentinels avoids any
  # collision with HCL/Markdown content. Written with plain awk (not multiline
  # `grep -o`) to stay portable on macOS/BSD.
  # NOTE (F1): the file is piped through `tr -d '\r'` BEFORE awk (see the loop
  # below), so a CRLF-authored lab/page can never disarm the selectors. The `\r?`
  # anchors here are belt-and-suspenders in case awk is ever fed raw bytes.
  extract='
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t\r]+$/,"",s); return s }
    /^[ \t]*<!--[ \t]*source:[ \t]*.*-->[ \t]*\r?$/ {
      p=$0
      sub(/^[ \t]*<!--[ \t]*source:[ \t]*/,"",p); sub(/[ \t]*-->[ \t]*\r?$/,"",p)
      pending=trim(p); next
    }
    pending!="" && /^[ \t]*```hcl([ \t]+\{[^}\r]*\})?[ \t]*\r?$/ { printf "\x01%s\n", pending; incode=1; pending=""; next }
    pending!="" { pending="" }   # marker not immediately hugging a fence → drop
    incode && /^[ \t]*```[ \t]*\r?$/ { printf "\x02\n"; incode=0; next }
    incode { print }
  '
  for f in "${DRIFT_FILES[@]}"; do
    # Split awk output into per-block records on the \x02 terminator.
    while IFS= read -r -d $'\x02' record; do
      # record starts with \x01<path>\n<body...>. Strip leading newline artefacts.
      record="${record#$'\n'}"
      case "$record" in
        $'\x01'*) : ;;      # a real block record
        *) continue ;;      # trailing/empty chunk after the last terminator
      esac
      src="${record#$'\x01'}"     # drop the \x01 sentinel
      src="${src%%$'\n'*}"         # path is up to the first newline
      body="${record#*$'\n'}"      # everything after that first newline is the body
      [ "$body" = "$record" ] && body=""   # empty block (fence right after marker)
      ANNOTATED=$((ANNOTATED + 1))

      if [ ! -f "$src" ]; then
        fail "drift: annotated block cites missing file: $src  (in $f)"
        DRIFTED=$((DRIFTED + 1))
        continue
      fi

      # Normalise both sides: strip CR (CRLF→LF) and any trailing newline so a
      # lone trailing-newline difference is not spurious drift. `$(...)` already
      # eats trailing newlines; do the same to the block body, and strip \r too.
      file_norm="$(tr -d '\r' < "$src")"
      body_norm="$(printf '%s' "$body" | tr -d '\r')"
      if [ "$body_norm" = "$file_norm" ]; then
        pass "no drift: $src matches its block in $(basename "$f")"
      else
        fail "drift: block in $f does NOT match source file: $src"
        info "diff (source ↔ block) for $src:"
        diff <(printf '%s\n' "$file_norm") <(printf '%s\n' "$body_norm") 2>/dev/null \
          | sed 's/^/    /' | head -n 40 || true
        DRIFTED=$((DRIFTED + 1))
      fi
    done < <(tr -d '\r' < "$f" | awk "$extract")
  done

  if [ "$ANNOTATED" -eq 0 ]; then
    warn "no annotated \`\`\`hcl blocks found — drift enforcement is a no-op. (pass)"
    info "Annotate a block with '<!-- source: PATH -->' above its fence to enforce it (see docs/authoring-guide.md)."
  elif [ "$DRIFTED" -eq 0 ]; then
    pass "all ${ANNOTATED} annotated block(s) match their source files — no slide↔lab drift"
  else
    info "${DRIFTED} of ${ANNOTATED} annotated block(s) drifted from source"
  fi
fi

# ---------------------------------------------------------------------------
# 7. Deck tier truth (scripts/deck-manifest.mjs SSoT)
#    Tier tokens and slides-3day hide flags must match the manifest. Cross-deck
#    drift and hide:invariant failures use the same messages as verify-selftest.
# ---------------------------------------------------------------------------
heading "Deck tier truth (scripts/deck-manifest.mjs)"
if [ ! -f scripts/deck-manifest.mjs ] || [ ! -f scripts/generate-decks.mjs ]; then
  warn "deck manifest scripts missing — skipping tier truth check."
elif ! node scripts/generate-decks.mjs --check-tiers 2>&1; then
  fail "deck tier truth check failed (run \`pnpm decks:generate\`)"
else
  pass "deck tiers and hide flags match scripts/deck-manifest.mjs"
fi

# ---------------------------------------------------------------------------
# 8. README navigation contract
# ---------------------------------------------------------------------------
heading "README navigation contract"
if [ ! -f README.md ]; then
  fail "README navigation contract: README.md is missing"
elif [ ! -f Taskfile.yaml ]; then
  fail "README navigation contract: Taskfile.yaml is missing"
else
  REQUIRED_README_ROUTES=(
    "canonical 3-day workshop|slides-3day.md"
    "full superset|slides.md"
    "template gallery|slides-templates.md"
    "Lab 00|labs/day-1/00-setup.md"
    "LocalStack troubleshooting|setup/localstack.md"
    "contributor guide|docs/authoring-guide.md"
    "decision index|docs/decisions/README.md"
  )
  NAV_FAILURES=0
  for route in "${REQUIRED_README_ROUTES[@]}"; do
    label="${route%%|*}"
    path="${route#*|}"
    if [ ! -e "$path" ]; then
      fail "README route '$label' is missing: $path"
      NAV_FAILURES=$((NAV_FAILURES + 1))
    elif ! grep -qF "]($path)" README.md && ! grep -qF "](./$path)" README.md; then
      fail "README route '$label' is not linked: $path"
      NAV_FAILURES=$((NAV_FAILURES + 1))
    fi
  done

  declare -A TASK_NAMES=()
  while IFS= read -r task_name; do
    [ -n "$task_name" ] && TASK_NAMES["$task_name"]=1
  done < <(awk '/^  [A-Za-z0-9][A-Za-z0-9:_-]*:$/ { name=$1; sub(/:$/, "", name); print name }' Taskfile.yaml)

  while IFS= read -r command; do
    [ -n "$command" ] || continue
    task_name="${command#task }"
    if [ -z "${TASK_NAMES[$task_name]+set}" ]; then
      fail "README task command does not exist: $command"
      NAV_FAILURES=$((NAV_FAILURES + 1))
    fi
  done < <(grep -oE '`task [A-Za-z0-9:_-]+' README.md | tr -d '`' | sort -u)

  if [ "$NAV_FAILURES" -eq 0 ]; then
    pass "README navigation contract: required routes and documented task commands resolve"
  fi
fi

# ---------------------------------------------------------------------------
# 9. Day-2/3 optional tool lanes
#    The bootstrap requires these tools before their labs are taught. The repo
#    verifier remains usable on a Day-1-only machine: checks owned by an absent
#    or broken tool skip explicitly instead of turning unrelated work red.
# ---------------------------------------------------------------------------
heading "Day-2/3 tool-dependent checks"
DAY_TOOL_CHECKS=(
  "tflint|--version|S13 static analysis"
  "trivy|--version|S14 security scanning"
  "checkov|--version|S14 security scanning"
  "conftest|--version|S14 policy checks"
  "terramate|version|S20-S25 Terramate labs"
)
for spec in "${DAY_TOOL_CHECKS[@]}"; do
  tool="${spec%%|*}"
  rest="${spec#*|}"
  version_arg="${rest%%|*}"
  labs="${rest#*|}"
  version=""
  if have "$tool"; then
    version="$("$tool" "$version_arg" 2>/dev/null | head -n1 || true)"
  fi
  if [ -n "$version" ]; then
    info "$tool available — $labs checks run when their content is authored"
  else
    warn "$tool unavailable — skipping tool-dependent checks for $labs"
  fi
done

# ---------------------------------------------------------------------------
# 10. Toolchain pin drift (US-P-PINS)
#    versions.env is canonical; listed consumers must mirror it exactly.
# ---------------------------------------------------------------------------
heading "Toolchain pin drift (versions.env)"
PIN_FILE="$REPO_ROOT/versions.env"
if [ ! -f "$PIN_FILE" ]; then
  fail "versions.env is missing — create the canonical pin file at repo root"
else
  # shellcheck source=versions.env disable=SC1091
  . "$PIN_FILE"
  PIN_FAILURES=0
  pin_fail() {
    fail "$1"
    PIN_FAILURES=$((PIN_FAILURES + 1))
  }
  pin_expect() {
    local file="$1" needle="$2" label="$3"
    if [ ! -f "$file" ]; then
      pin_fail "pin drift: missing consumer file for $label: $file"
    elif ! grep -qF -- "$needle" "$file"; then
      pin_fail "pin drift: $label in ${file#"$REPO_ROOT"/} does not match versions.env (expected fragment: $needle)"
    fi
  }

  pin_expect "$REPO_ROOT/docker-compose.yml" \
    'localstack/localstack:${LOCALSTACK_VERSION}' "LOCALSTACK_VERSION (compose image)"
  pin_expect "$REPO_ROOT/docker-compose.yml" \
    'golang:${GO_VERSION}-bookworm' "GO_VERSION (compose build arg)"
  pin_expect "$REPO_ROOT/docker-compose.yml" \
    'TOFU_VERSION: ${TOFU_VERSION}' "TOFU_VERSION (compose build arg)"
  pin_expect "$REPO_ROOT/docker-compose.yml" \
    'go${GO_VERSION}-tofu${TOFU_VERSION}' "terratest image tag"
  pin_expect "$REPO_ROOT/setup/terratest/Dockerfile" \
    "ARG GO_IMAGE=golang:${GO_VERSION}-bookworm" "GO_IMAGE (Dockerfile default)"
  pin_expect "$REPO_ROOT/setup/terratest/Dockerfile" \
    "ARG TOFU_VERSION=${TOFU_VERSION}" "TOFU_VERSION (Dockerfile default)"
  pin_expect "$REPO_ROOT/setup/terratest/Dockerfile" \
    "tofu_\${TOFU_VERSION}_SHA256SUMS" "OpenTofu SHA256SUMS verification (SEC-4)"
  pin_expect "$REPO_ROOT/Taskfile.yaml" \
    'dotenv: ["versions.env"]' "Taskfile dotenv"
  pin_expect "$REPO_ROOT/Taskfile.yaml" \
    'COMPOSE_ENV_FILE: versions.env' "Taskfile COMPOSE_ENV_FILE"
  pin_expect "$REPO_ROOT/Taskfile.yaml" \
    '--env-file {{.COMPOSE_ENV_FILE}}' "Taskfile compose --env-file"
  pin_expect "$REPO_ROOT/scripts/lab-terratest.sh" \
    'COMPOSE_ENV_FILE="${COMPOSE_ENV_FILE:-$ROOT/versions.env}"' "lab-terratest versions.env default"
  pin_expect "$REPO_ROOT/scripts/lab-terratest.sh" \
    '--env-file "$COMPOSE_ENV_FILE"' "lab-terratest compose --env-file"
  pin_expect "$REPO_ROOT/setup/bootstrap.sh" \
    'VERSIONS_ENV="$SCRIPT_DIR/../versions.env"' "bootstrap versions.env path"
  pin_expect "$REPO_ROOT/setup/bootstrap.sh" \
    '. "$VERSIONS_ENV"' "bootstrap sources versions.env (TERRAMATE_VERSION et al.)"
  pin_expect "$REPO_ROOT/setup/bootstrap.sh" \
    'TERRAMATE_VERSION' "bootstrap TERRAMATE_VERSION workshop pin"
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
  pin_expect "$CI_YML" \
    "tofu_version: \"${TOFU_VERSION}\"" "TOFU_VERSION (ci.yml setup-opentofu)"
  pin_expect "$CI_YML" \
    "localstack/localstack:${LOCALSTACK_VERSION}" "LOCALSTACK_VERSION (ci.yml service)"

  # Go toolchain ceiling (the F8 defect class). The needle inventory above only
  # proves consumers RESTATE ${GO_VERSION}; it never asked whether that version
  # can actually build the labs. It cannot self-correct at run time either: the
  # official golang images set GOTOOLCHAIN=local, so a container built from
  # golang:${GO_VERSION}-bookworm cannot fetch a newer toolchain and dies on the
  # first `go test` with "go.mod requires go >= X (running Y; GOTOOLCHAIN=local)".
  #
  # A dependency-bump bot raising a `go` directive is the realistic way this
  # drifts — it edits go.mod and nothing else, so every needle above stays true
  # while the lab stops running. Scan the directives instead of trusting them.
  #
  # MIN_GO (setup/bootstrap.sh) is checked against the same directives: it is
  # the HOST lane's floor, and a host that satisfies bootstrap must be able to
  # run `task lab:terratest:host`.
  GO_MIN_HOST="$(sed -n 's/^MIN_GO="\([0-9.]*\)".*/\1/p' "$REPO_ROOT/setup/bootstrap.sh" | head -n1)"
  if [ -z "$GO_MIN_HOST" ]; then
    pin_fail "pin drift: cannot read MIN_GO from setup/bootstrap.sh"
  fi
  # Pad both sides of every compare to three components — min_version is a plain
  # sort -V, where "1.25" sorts BELOW "1.25.0" and would false-red an exact match.
  go_pad() { case "$1" in *.*.*) printf '%s\n' "$1" ;; *.*) printf '%s.0\n' "$1" ;; *) printf '%s.0.0\n' "$1" ;; esac; }
  GO_MIN_HOST_CMP="$(go_pad "$GO_MIN_HOST")"
  GO_VERSION_CMP="$(go_pad "$GO_VERSION")"
  #
  # `git ls-files`, not `find`: the claim is about TRACKED modules. A learner's
  # stray `go mod init` under labs/, or a vendored module, is not something the
  # container pin owes anything to, and scanning it could only false-red.
  #
  # THREE states, and only one of them is a pass. The rule this file states at
  # the git-ignored-scratch block above — never degrade an unknown file set to a
  # pass — is what the shape below is for: an empty list because nothing is
  # tracked is not the same fact as an empty list because the scan broke, and
  # collapsing them is how a ceiling gate greens while covering nothing.
  GOMOD_LIST=""
  GOMOD_HAVE_INDEX=0
  if have git && [ -e "$REPO_ROOT/.git" ] \
     && GOMOD_LIST="$(git -C "$REPO_ROOT" ls-files 'labs/**/go.mod' 2>/dev/null)"; then
    GOMOD_HAVE_INDEX=1
  fi
  GOMOD_FS_COUNT="$(find "$REPO_ROOT/labs" -name go.mod -not -path '*/.terraform/*' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$GOMOD_HAVE_INDEX" -eq 0 ]; then
    # No index to ask. Say so rather than reporting a ceiling nobody checked.
    if [ "${GOMOD_FS_COUNT:-0}" -gt 0 ]; then
      pin_fail "pin drift: $GOMOD_FS_COUNT labs/**/go.mod on disk but no git index to confirm which are tracked — refusing to green the Go ceiling on a set it cannot determine"
    else
      info "  no git index and no labs/**/go.mod present — Go ceiling not applicable here"
    fi
  fi
  GOMOD_EXPECTED="$(printf '%s' "$GOMOD_LIST" | grep -c . || true)"
  GOMOD_SCANNED=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    gomod="$REPO_ROOT/$rel"
    # [[:space:]][[:space:]]* and NOT \+ — the latter is a GNU extension that a
    # BSD sed reads as a literal plus, which would leave go_req empty for every
    # file and skip the whole scan. This repo is developed on macOS.
    go_req="$(sed -n 's/^go[[:space:]][[:space:]]*\([0-9][0-9.]*\)[[:space:]]*$/\1/p' "$gomod" | head -n1)"
    if [ -z "$go_req" ]; then
      pin_fail "pin drift: $rel has no parseable \`go\` directive — refusing to skip a module the ceiling is supposed to cover"
      continue
    fi
    GOMOD_SCANNED=$((GOMOD_SCANNED + 1))
    go_req_cmp="$(go_pad "$go_req")"
    if ! min_version "$GO_VERSION_CMP" "$go_req_cmp"; then
      pin_fail "pin drift: $rel declares go $go_req, above versions.env GO_VERSION=$GO_VERSION — the container lane runs golang:${GO_VERSION}-bookworm with GOTOOLCHAIN=local and cannot upgrade itself"
    fi
    if [ -n "$GO_MIN_HOST" ] && ! min_version "$GO_MIN_HOST_CMP" "$go_req_cmp"; then
      pin_fail "pin drift: $rel declares go $go_req, above bootstrap MIN_GO=$GO_MIN_HOST — a host that passes bootstrap would still fail task lab:terratest:host"
    fi
  done < <(printf '%s\n' "$GOMOD_LIST" | sort)

  # Every tracked module must have been reached. A directive nobody could parse
  # already failed above; this catches the set itself coming up short.
  if [ "$GOMOD_HAVE_INDEX" -eq 1 ] && [ "$GOMOD_SCANNED" -ne "$GOMOD_EXPECTED" ]; then
    pin_fail "pin drift: scanned $GOMOD_SCANNED of $GOMOD_EXPECTED tracked labs/**/go.mod — refusing to green the Go ceiling on an incomplete scan"
  fi
  # Tracked nothing, but files are on disk: the pathspec stopped matching (a
  # renamed labs/, a module moved out from under it). Green here would mean
  # "no drift" when it actually means "nothing was looked at".
  if [ "$GOMOD_HAVE_INDEX" -eq 1 ] && [ "$GOMOD_EXPECTED" -eq 0 ] && [ "${GOMOD_FS_COUNT:-0}" -gt 0 ]; then
    pin_fail "pin drift: no TRACKED labs/**/go.mod matched, yet $GOMOD_FS_COUNT exist on disk — the Go ceiling is scanning nothing"
  fi

  if [ "$PIN_FAILURES" -eq 0 ]; then
    pass "toolchain pins: all listed consumers match versions.env ($GOMOD_SCANNED go.mod directive(s) within GO_VERSION=$GO_VERSION / MIN_GO=$GO_MIN_HOST)"
  fi
fi

# ---------------------------------------------------------------------------
# 11. Version-floor skew (US-D-VERSION-FLOOR)
#     TOFU_FLOOR (defined at the top, enforced by the preflight) is THE floor.
#     Two halves, mirroring the E2 defect class this replaces ("build check 1"
#     in docs/claims-verification.md §K):
#       (a) the INVENTORIED consumers that RESTATE the floor still state this
#           number — an inventory of needles, like section 10, not a count.
#           The list below is the known restating set at the time of writing;
#           extend it when a new doc restates the floor (it is not — and
#           cannot cheaply be — a guarantee of exhaustiveness);
#       (b) no tracked lab/module/example artifact DEMANDS more than the floor
#           via required_version / Terramate's terraform_version global. Lower
#           per-artifact floors are deliberate (honest feature minimums, see
#           docs/claims-verification.md); higher ones are the defect where a
#           learner satisfies setup and still hard-fails a lab. Per-STEP needs
#           above the floor live in prose with an inline disclosure (Lab 04's
#           S3 stretch, use_lockfile >= 1.10) — prose is not scanned here.
# ---------------------------------------------------------------------------
heading "Version-floor skew (TOFU_FLOOR=$TOFU_FLOOR)"
FLOOR_FAILURES=0
floor_fail() {
  fail "$1"
  FLOOR_FAILURES=$((FLOOR_FAILURES + 1))
}
floor_expect() {
  local file="$1" needle="$2" label="$3"
  if [ ! -f "$file" ]; then
    floor_fail "floor skew: missing consumer file for $label: $file"
  elif ! grep -qF -- "$needle" "$file"; then
    floor_fail "floor skew: $label in ${file#"$REPO_ROOT"/} does not state the floor $TOFU_FLOOR (expected fragment: $needle)"
  fi
}

floor_expect "$REPO_ROOT/setup/bootstrap.sh" \
  "MIN_TOFU=\"${TOFU_FLOOR}\"" "bootstrap MIN_TOFU"
floor_expect "$REPO_ROOT/docs/setup.md" \
  "OpenTofu ≥${TOFU_FLOOR}" "setup guide toolchain row"
floor_expect "$REPO_ROOT/README.md" \
  "OpenTofu ≥${TOFU_FLOOR}" "README toolchain row"
floor_expect "$REPO_ROOT/docs/validation-matrix.md" \
  "≥ **${TOFU_FLOOR}** (\`setup/bootstrap.sh\`)" "validation-matrix canonical pin row"
floor_expect "$REPO_ROOT/pages/S00-welcome/index.md" \
  "tofu ≥ ${TOFU_FLOOR}" "S00 required-toolchain card"
floor_expect "$REPO_ROOT/pages/S19-testing-cicd/index.md" \
  "OpenTofu ≥ ${TOFU_FLOOR} preflight" "S19 preflight bullet"
floor_expect "$REPO_ROOT/docs/facilitator-runbook.md" \
  "\`tofu version\` ≥${TOFU_FLOOR}" "runbook any-machine row"
floor_expect "$REPO_ROOT/docs/rehearsal-checklist.md" \
  "confirm \`tofu version\` ≥${TOFU_FLOOR}" "rehearsal fresh-machine step"
floor_expect "$REPO_ROOT/docs/rehearsal-checklist.md" \
  "OpenTofu ≥${TOFU_FLOOR} on" "rehearsal morning checklist"
floor_expect "$REPO_ROOT/pages/S17-mocking/index.md" \
  "workshop floor of <strong>${TOFU_FLOOR}</strong>" "S17 mocking floor panel"

# (b) ceiling scan: no artifact may require more than the floor. The floor is
# padded to three components because min_version is a plain sort -V compare
# ("1.9" < "1.9.0" there, which would false-red every X.Y.0 pin). Terramate's
# own required_version lines (">= 0.14.0", a Terramate CLI bound, not tofu)
# match the pattern too; they pass the same ceiling check trivially and are
# deliberately left in the sweep rather than special-cased.
#
# The scan matches EVERY constraint form, not just ">= X": a "~> X", an exact
# "= X", or a bare "X" pin imposes an UPPER bound, which is the same learner-
# stranding defect from the other side — a workdir that can hard-fail on the
# newer tofu the setup instructions install. Lax ">= X" (with or without the
# space) is the only shape a lab/module/example may use, and only at or below
# the floor.
FLOOR_SCANNED=0
for floor_dir in labs modules examples; do
  [ -d "$REPO_ROOT/$floor_dir" ] || continue
  while IFS= read -r floor_hit; do
    floor_file="${floor_hit%%:*}"
    floor_rest="${floor_hit#*:}"
    floor_lineno="${floor_rest%%:*}"
    floor_constraint="$(printf '%s\n' "${floor_hit}" | sed -E 's/.*"((>=|~>|=)?[[:space:]]*[0-9][0-9.]*)".*/\1/')"
    floor_op="$(printf '%s\n' "${floor_constraint}" | sed -E 's/^((>=|~>|=)?).*$/\1/')"
    floor_req="$(printf '%s\n' "${floor_constraint}" | sed -E 's/[^0-9]*([0-9][0-9.]*)$/\1/')"
    FLOOR_SCANNED=$((FLOOR_SCANNED + 1))
    if [ "$floor_op" != ">=" ]; then
      floor_fail "floor skew: ${floor_file#"$REPO_ROOT"/}:${floor_lineno} pins a ceiling-imposing constraint \"${floor_constraint}\" — use a lax \">= X\" floor at or below ${TOFU_FLOOR}"
    elif ! min_version "${TOFU_FLOOR}.0" "$floor_req"; then
      floor_fail "floor skew: ${floor_file#"$REPO_ROOT"/}:${floor_lineno} demands >= ${floor_req}, above the workshop floor ${TOFU_FLOOR}"
    fi
  done < <(grep -rn -E '(required_version|terraform_version)[[:space:]]*=[[:space:]]*"(>=|~>|=)?[[:space:]]*[0-9][0-9.]*"' \
    --include='*.tf' --include='*.tofu' --include='*.tm.hcl' \
    --exclude-dir='.terraform' "$REPO_ROOT/$floor_dir" || true)
done

if [ "$FLOOR_FAILURES" -eq 0 ]; then
  pass "version floor: consumers state $TOFU_FLOOR and no artifact ($FLOOR_SCANNED version pins scanned) demands more"
fi

# ---------------------------------------------------------------------------
# 12. Tracked-prose pointer hygiene (ADR 0016)
#     The planning directory is gitignored, so a tracked file that points into
#     it dangles in every fresh clone. Allowlist: the ignore rule itself and
#     the two ADRs that RECORD the convention (0002, 0016). The needle is
#     assembled by concatenation so this script never matches itself — the
#     same self-match trap as pgrep -f, applied to grep.
# ---------------------------------------------------------------------------
POINTER_NEEDLE='agent-''context/'
heading "Tracked-prose pointer hygiene (no ${POINTER_NEEDLE} pointers)"
POINTER_ALLOWLIST=(
  ".gitignore"
  "docs/decisions/0002-repository-and-content-structure.md"
  "docs/decisions/0016-authoring-contract-home.md"
)
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  POINTER_HITS="$(git -C "$REPO_ROOT" grep -lF -- "$POINTER_NEEDLE" 2>/dev/null || true)"
else
  # Self-test sandboxes are plain directories: walk what a clone would hold.
  POINTER_HITS="$(grep -rlF --exclude-dir=.git --exclude-dir=node_modules \
    --exclude-dir=.terraform --exclude-dir=.claude --exclude-dir=site \
    -- "$POINTER_NEEDLE" "$REPO_ROOT" 2>/dev/null | sed "s|^$REPO_ROOT/||" || true)"
fi
POINTER_FAILURES=0
while IFS= read -r pointer_file; do
  [ -n "$pointer_file" ] || continue
  pointer_allowed=0
  for pointer_allow in "${POINTER_ALLOWLIST[@]}"; do
    if [ "$pointer_file" = "$pointer_allow" ]; then
      pointer_allowed=1
      break
    fi
  done
  if [ "$pointer_allowed" -eq 0 ]; then
    fail "pointer hygiene: ${pointer_file} references gitignored ${POINTER_NEEDLE} content (dangling in a fresh clone — ADR 0016)"
    POINTER_FAILURES=$((POINTER_FAILURES + 1))
  fi
done <<<"$POINTER_HITS"
if [ "$POINTER_FAILURES" -eq 0 ]; then
  pass "pointer hygiene: no tracked prose references ${POINTER_NEEDLE} outside the recorded allowlist"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
heading "Summary"
if [ "$FAILURES" -eq 0 ]; then
  ok "verify PASSED — $CHECKS check(s) OK, 0 failures."
  exit 0
else
  bad "verify FAILED — $FAILURES failure(s) across $((CHECKS + FAILURES)) check(s)."
  exit 1
fi
