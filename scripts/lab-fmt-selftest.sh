#!/usr/bin/env bash
# scripts/lab-fmt-selftest.sh — regression guard for scripts/lab-fmt.sh.
#
# WHY THIS EXISTS (US-F-FMTSCOPE)
#
# `task lab:fmt` is the remedy scripts/verify.sh advertises when its fmt gate
# reds. It used to run a bare `tofu fmt -recursive` from the repo root, which
# rewrote labs/day-2/13-static-analysis/messy/main.tf — a DELIBERATELY
# unformatted Day-2 static-analysis fixture whose misalignment IS the exercise.
# Following the advertised remedy silently destroyed the lab. It fired in the
# wild on 2026-08-19. It did NOT, contrary to an earlier draft of this header,
# descend into the agent worktrees: `tofu fmt -recursive` skips dot-prefixed
# directories, so `.worktrees/` and `.claude/worktrees/` were never in its reach.
# Case 3 below depends on that fact being stated correctly — see its comment.
#
# So lab-fmt.sh is now scoped to the git INDEX minus that one fixture, mirroring
# verify.sh §2. Detection and remediation must agree or one of them is lying.
#
# The verify.sh scoping fix (US-F-VERIFY-WT) introduced and then self-found two
# defects in its own error-reporting paths. Both are re-guarded here because
# lab-fmt.sh is the same shape of change:
#   * an empty `git ls-files` result silently disarming the whole thing
#     (in a MUTATOR this is a lying success, not a false green), and
#   * `head -n 3` used as a pipeline SINK, which can SIGPIPE its upstream under
#     `set -o pipefail` and kill the script from inside the branch whose only
#     job is to report a failure.
#
# Case 10 additionally pins the WIRING: `task lab:fmt` must actually invoke this
# script. Without it, reverting Taskfile.yaml to `tofu fmt -recursive` leaves
# every case here green while the fixture burns — the same hand-maintained-parity
# defect this lane criticises in ci.yml, reintroduced by the fix itself.
#
# Every case runs against a throwaway git repo in a temp dir. Nothing here
# touches the real worktree except cases 7 and 10, which only READ tracked files.
#
# CI CONTRACT. .github/workflows/ci.yml discovers scripts/*-selftest.sh by glob
# (US-F-CIPARITY), so this script runs on every push and a failure here reds
# verify-unit for everyone. It must therefore never fail for environmental
# reasons:
#   * No network, no Docker, no package manager. External binaries used are
#     git, tofu, awk, sed, grep, cmp, mktemp, cp, mkdir, rm, chmod — all present
#     on a bare ubuntu-latest runner.
#   * No git identity inherited. CI runners have no default user.email, so every
#     throwaway repo sets user.email/user.name repo-locally and disables
#     commit.gpgsign; a global signing key requirement would otherwise fail the
#     commit.
#   * No inherited hooks. See make_repo — this is a real trap, not a hypothetical.
#   * No tofu version dependency. The multi-file mutating form `tofu fmt a b`
#     that lab-fmt.sh relies on was verified on the CI pin (1.10.3) as well as
#     1.12.5, and case 2 re-proves it at runtime on whatever version is present:
#     a tofu that processed only argv[1] reds the late-sorting assertion.
#   * No ordering or locale dependency. Nothing here sorts, and every pattern is
#     ASCII, so LC_ALL=C discovery order is irrelevant.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="$ROOT/scripts/lab-fmt.sh"
S13_REL='labs/day-2/13-static-analysis/messy/main.tf'
S13_REL_DIR='labs/day-2/13-static-analysis/messy'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  [OK]   %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  [FAIL] %s\n' "$*"; }
case_() { printf '\n== %s ==\n' "$*"; }

[ -f "$SUT" ] || { echo "missing system under test: $SUT" >&2; exit 1; }
command -v tofu >/dev/null 2>&1 || {
  echo "tofu is required for this self-test. Install: brew install opentofu" >&2
  exit 1
}

# The genuine article: byte-for-byte the fixture the lab ships. Copying it rather
# than re-authoring an approximation is the point — an approximation could be
# accidentally canonical and the headline assertion would pass vacuously.
REAL_S13="$ROOT/$S13_REL"
[ -f "$REAL_S13" ] || { echo "missing S13 fixture in the repo: $REAL_S13" >&2; exit 1; }
if tofu fmt -check "$REAL_S13" >/dev/null 2>&1; then
  echo "the S13 fixture at $S13_REL is canonically formatted — this self-test's" >&2
  echo "headline assertion would pass vacuously. The fixture has been destroyed." >&2
  exit 1
fi

UNFORMATTED_TF='variable "scratch" {
  type    =   string
    default = "x"
}
'

# Build a throwaway repo. $1 = which .tf content to track:
#   full  → S13 fixture + two other unformatted files (one early, one late)
#   s13   → the S13 fixture only
#   none  → files on disk, nothing added to the index
make_repo() {
  local mode="$1" r="$TMP/repo-$2"
  rm -rf "$r"
  mkdir -p "$r/scripts" "$r/$(dirname "$S13_REL")" "$r/modules/aaa-early" "$r/zzz-late"
  cp "$SUT" "$r/scripts/lab-fmt.sh"
  cp "$REAL_S13" "$r/$S13_REL"
  printf '%s' "$UNFORMATTED_TF" >"$r/modules/aaa-early/main.tf"
  printf '%s' "$UNFORMATTED_TF" >"$r/zzz-late/main.tf"
  git -c init.defaultBranch=main -C "$r" init -q
  # Identity is set repo-LOCAL, never inherited: CI runners have no default
  # user.email and `git commit` would red only there, which is the worst place
  # to discover it.
  git -C "$r" config user.email selftest@example.invalid
  git -C "$r" config user.name 'lab-fmt selftest'
  # Disarm inherited hooks. This repo's own README tells contributors to run
  # `pre-commit install`, and .pre-commit-config.yaml's terraform_fmt hook
  # rewrites .tf on commit. A developer with a GLOBAL core.hooksPath (or an
  # init.templateDir that installs hooks) would have that hook fire inside these
  # throwaway repos and reformat the very fixture case 1 asserts is untouched —
  # a false red caused entirely by the tester's own machine. Belt and braces:
  # hooksPath is neutralised here and every commit below also passes --no-verify.
  git -C "$r" config core.hooksPath /dev/null
  # Inherited commit.gpgsign with no key available fails the commit outright.
  git -C "$r" config commit.gpgsign false
  case "$mode" in
    full) git -C "$r" add -A ;;
    s13)  git -C "$r" add "scripts/lab-fmt.sh" "$S13_REL" ;;
    none) : ;;
  esac
  [ "$mode" = none ] || git -C "$r" commit -q --no-verify -m 'selftest fixture'
  printf '%s' "$r"
}

is_canonical() { tofu fmt -check "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# 1. THE HEADLINE. lab:fmt must leave the S13 teaching fixture byte-identical.
# ---------------------------------------------------------------------------
case_ "1. the S13 messy fixture survives lab:fmt byte-for-byte"
R="$(make_repo full 1)"
if (cd "$R" && bash scripts/lab-fmt.sh >"$TMP/out1" 2>&1); then
  ok "lab-fmt.sh exits 0 on a normal repo"
else
  bad "lab-fmt.sh exited non-zero on a normal repo: $(cat "$TMP/out1")"
fi
if cmp -s "$REAL_S13" "$R/$S13_REL"; then
  ok "S13 fixture is byte-identical after lab:fmt"
else
  bad "S13 fixture was REWRITTEN by lab:fmt — the teaching fixture is destroyed"
fi
if [ -z "$(git -C "$R" status --porcelain -- "$S13_REL")" ]; then
  ok "git reports the S13 fixture path clean after lab:fmt"
else
  bad "git reports the S13 fixture path dirty after lab:fmt"
fi

# ---------------------------------------------------------------------------
# 2. POSITIVE CONTROL. A fix that scopes away everything is a silent no-op.
#    Two files, one sorting early and one late, because `tofu fmt a.tf b.tf`
#    processing only argv[1] would look identical to a working script if the
#    only planted file happened to come first.
# ---------------------------------------------------------------------------
case_ "2. positive control: tracked .tf elsewhere still gets formatted"
if is_canonical "$R/modules/aaa-early/main.tf"; then
  ok "early-sorting tracked .tf was formatted"
else
  bad "early-sorting tracked .tf was NOT formatted — lab:fmt scoped away real work"
fi
if is_canonical "$R/zzz-late/main.tf"; then
  ok "late-sorting tracked .tf was formatted (multi-file argv is honored)"
else
  bad "late-sorting tracked .tf was NOT formatted — only argv[1] is being processed"
fi

# ---------------------------------------------------------------------------
# 3. Index scoping is what puts untracked content out of reach. Tested directly
#    rather than trusting the absence of `-recursive`.
#
#    THE DIRECTORY NAMES HERE ARE LOAD-BEARING AND MUST NOT BE DOT-PREFIXED.
#    An earlier version of this case planted the file in `.worktrees/other-lane/`
#    and asserted it survived. That assertion was VACUOUS: `tofu fmt -recursive`
#    skips dot-prefixed directories, so it passed even against a fully
#    destructive `-recursive` stand-in — a gate certifying nothing. Reproduced:
#    identical files in `.worktrees/x/`, `.claude/worktrees/y/` and `normal/`,
#    `tofu fmt -recursive`, only `normal/main.tf` rewritten.
#
#    So the stand-ins below sit at NON-dot paths, where `-recursive` genuinely
#    would reach them: `worktrees/` (a worktree root without the dot), a nested
#    untracked directory, and an untracked file at the root. Those three are what
#    make this case bite.
# ---------------------------------------------------------------------------
case_ "3. untracked .tf at non-dot paths (reachable by -recursive) is left alone"
R3="$(make_repo full 3)"
mkdir -p "$R3/worktrees/other-lane" "$R3/vendor/nested/deep"
printf '%s' "$UNFORMATTED_TF" >"$R3/worktrees/other-lane/main.tf"
printf '%s' "$UNFORMATTED_TF" >"$R3/vendor/nested/deep/main.tf"
printf '%s' "$UNFORMATTED_TF" >"$R3/untracked-scratch.tf"
(cd "$R3" && bash scripts/lab-fmt.sh >/dev/null 2>&1) || true
if ! is_canonical "$R3/worktrees/other-lane/main.tf"; then
  ok "a .tf in a non-dot sibling-worktree root was not touched"
else
  bad "lab:fmt reformatted a file under worktrees/ — untracked trees are still in scope"
fi
if ! is_canonical "$R3/vendor/nested/deep/main.tf"; then
  ok "a deeply nested untracked .tf was not touched"
else
  bad "lab:fmt reformatted a nested untracked .tf — the scan is not index-scoped"
fi
if ! is_canonical "$R3/untracked-scratch.tf"; then
  ok "an untracked .tf at the root was not touched"
else
  bad "lab:fmt reformatted an untracked .tf — the scan is not index-scoped"
fi

# ---------------------------------------------------------------------------
# 4. EMPTY-LIST GUARD (the P0 the previous lane was blocked on). `git ls-files`
#    exits 0 with NO output for a deleted index, a fresh `git init` with nothing
#    staged, or a bogus GIT_INDEX_FILE. In verify.sh that degraded to a green
#    gate over an unscanned tree. Here it would degrade to "formatted!" over a
#    tree nothing was formatted in — the user then re-reds verify.sh and has no
#    idea why. It must fail LOUDLY.
# ---------------------------------------------------------------------------
case_ "4. an empty git ls-files result fails loudly instead of no-opping"
R4="$(make_repo none 4)"
if (cd "$R4" && bash scripts/lab-fmt.sh >"$TMP/out4" 2>&1); then
  bad "lab-fmt.sh reported success over an EMPTY file list (silent no-op)"
else
  ok "lab-fmt.sh exits non-zero when git ls-files yields nothing"
fi
if grep -qi 'refus' "$TMP/out4"; then
  ok "the empty-list failure says it is refusing, not just 'error'"
else
  bad "the empty-list failure message does not explain the refusal: $(cat "$TMP/out4")"
fi
if ! is_canonical "$R4/modules/aaa-early/main.tf"; then
  ok "nothing was formatted on the refusal path"
else
  bad "files were formatted despite the refusal"
fi

case_ "4b. same guard via a bogus GIT_INDEX_FILE on a repo that does have content"
R4B="$(make_repo full 4b)"
if (cd "$R4B" && GIT_INDEX_FILE="$TMP/no-such-index" bash scripts/lab-fmt.sh >"$TMP/out4b" 2>&1); then
  bad "lab-fmt.sh reported success with a bogus GIT_INDEX_FILE"
else
  ok "lab-fmt.sh exits non-zero with a bogus GIT_INDEX_FILE"
fi

# ---------------------------------------------------------------------------
# 5. SIGPIPE TRAP. git's own diagnosis is echoed back, truncated with `head -n 3`.
#    `head` must be the SOURCE of that pipeline. As a SINK it closes the pipe
#    early and can SIGPIPE its upstream, which under `set -o pipefail` + `set -e`
#    kills the script inside the branch whose only job is to report the failure.
#    safe.directory dubious-ownership stderr is ~5 lines, so this is reachable.
#    A git shim emitting many stderr lines and exiting 128 provokes it.
# ---------------------------------------------------------------------------
case_ "5. a failing git with long multi-line stderr is REPORTED, not fatal"
R5="$(make_repo full 5)"
SHIM="$TMP/shim-bin"
mkdir -p "$SHIM"
REAL_GIT="$(command -v git)"
# The real path is baked in rather than re-resolved through PATH: the shim IS on
# PATH ahead of git, so a `git` fallthrough would recurse forever.
cat >"$SHIM/git" <<SHIM_EOF
#!/bin/sh
if [ "\$1" = "ls-files" ]; then
  # Far more than the ~5 lines safe.directory actually emits, and deliberately
  # so: a few KB of stderr fits entirely inside the 64 KB pipe buffer, the
  # upstream finishes writing before the downstream \`head\` exits, and no
  # SIGPIPE is ever raised — the defect stays latent and the test passes on a
  # broken script. Overflowing the buffer is what makes this assertion bite.
  i=1
  while [ "\$i" -le 5000 ]; do
    echo "fatal: detected dubious ownership in repository (line \$i)" >&2
    i=\$((i + 1))
  done
  exit 128
fi
exec "$REAL_GIT" "\$@"
SHIM_EOF
chmod +x "$SHIM/git"
set +e
(cd "$R5" && PATH="$SHIM:$PATH" bash scripts/lab-fmt.sh >"$TMP/out5" 2>&1)
RC5=$?
set -e
if [ "$RC5" -ne 0 ]; then
  ok "lab-fmt.sh exits non-zero when git ls-files fails"
else
  bad "lab-fmt.sh reported success when git ls-files failed"
fi
# 141 = 128 + SIGPIPE(13): the exact death the head-as-sink defect produces.
if [ "$RC5" -ne 141 ]; then
  ok "exit status is not 141/SIGPIPE (head is used as a pipeline source)"
else
  bad "lab-fmt.sh died with SIGPIPE (141) inside its own failure-reporting branch"
fi
if grep -q 'dubious ownership' "$TMP/out5"; then
  ok "git's own diagnosis is surfaced to the user"
else
  bad "git's diagnosis was swallowed: $(cat "$TMP/out5")"
fi

# ---------------------------------------------------------------------------
# 6. A root that is not a git work tree. verify.sh falls back to a filesystem
#    walk there; a MUTATOR must not. A walk in an unknown root is precisely the
#    behavior being removed. Refuse.
# ---------------------------------------------------------------------------
case_ "6. a non-git root is refused, not walked"
R6="$(make_repo full 6)"
rm -rf "$R6/.git"
if (cd "$R6" && bash scripts/lab-fmt.sh >"$TMP/out6" 2>&1); then
  bad "lab-fmt.sh ran in a non-git root"
else
  ok "lab-fmt.sh refuses to run in a non-git root"
fi
if ! is_canonical "$R6/modules/aaa-early/main.tf"; then
  ok "nothing was formatted in the non-git root"
else
  bad "lab-fmt.sh formatted files in a non-git root — it fell back to a walk"
fi

# ---------------------------------------------------------------------------
# 7. THE TWO HALVES MUST AGREE. verify.sh DETECTS, lab-fmt.sh REMEDIATES, and
#    each hardcodes the fixture path. If they ever diverge, verify.sh reds on a
#    file lab:fmt refuses to fix, or lab:fmt destroys a file verify.sh excuses.
#    Enforced, not merely true-for-now: the next person to move the fixture gets
#    a red here instead of a silent regression.
# ---------------------------------------------------------------------------
case_ "7. verify.sh and lab-fmt.sh name the same S13 fixture path"
V_CONST="$(grep -m1 '^S13_MESSY_FIXTURE=' "$ROOT/scripts/verify.sh" || true)"
F_CONST="$(grep -m1 '^S13_MESSY_FIXTURE=' "$SUT" || true)"
if [ -n "$V_CONST" ] && [ -n "$F_CONST" ]; then
  ok "both scripts declare S13_MESSY_FIXTURE at the top level"
else
  bad "S13_MESSY_FIXTURE not found in both scripts (verify.sh='$V_CONST' lab-fmt.sh='$F_CONST')"
fi
if [ "$V_CONST" = "$F_CONST" ]; then
  ok "the detection and remediation halves exclude the identical path"
else
  bad "DIVERGENCE: verify.sh has $V_CONST but lab-fmt.sh has $F_CONST"
fi
# And the path they agree on has to exist, or they agree on a lie.
FIXTURE_PATH="$(printf '%s' "$F_CONST" | sed "s/^S13_MESSY_FIXTURE=//; s/^'//; s/'$//")"
if [ -f "$ROOT/$FIXTURE_PATH" ]; then
  ok "the excluded path exists in the repo: $FIXTURE_PATH"
else
  bad "the excluded path does not exist: $FIXTURE_PATH"
fi

# THIRD WRITER. `task lab:fmt` is not the only thing that can destroy this
# fixture: .pre-commit-config.yaml's `terraform_fmt` hook rewrites .tf on commit
# and on the `pre-commit run --all-files` its own header documents. That exclude
# is owned by another lane (US-F-CIPARITY), so this assertion is CONDITIONAL —
# it checks agreement once an exclude exists and says so plainly while none does.
# Hard-failing over a file this lane does not own would red verify-unit for
# everyone purely on which lane merges first.
#
# THREE THINGS THIS GETS RIGHT THAT AN EARLIER VERSION DID NOT:
#
#   * BOTH placements are read. pre-commit honours a repo-level top-level
#     `exclude:` as well as a per-hook one. Reading only the hook meant that if
#     CIPARITY put it at the top level this check would report the benign
#     "no exclude yet" note FOREVER — armed in appearance, disarmed in fact.
#
#   * A BROADER exclude is accepted. The exclude is a REGEX, and a directory-wide
#     `^labs/day-2/13-static-analysis/` protects the fixture perfectly well.
#     Demanding string equality with the file path would red the suite over
#     another lane's wording, and once glob discovery lands that reds CI for
#     everyone. So the fixture path is MATCHED against the regex rather than
#     compared to it.
#
#   * A blanket exclude is still rejected. Matching alone is too weak: `.` or
#     `.*` matches the fixture and also disables terraform_fmt for the entire
#     repo, which is a bigger regression than the one being guarded. So a normal
#     tracked .tf must NOT match. Broader-but-targeted passes; blanket fails.
PRECOMMIT="$ROOT/.pre-commit-config.yaml"
PC_EXCLUDE=""
PC_WHERE=""
if [ -f "$PRECOMMIT" ]; then
  # Per-hook exclude, bounded to the terraform_fmt hook.
  PC_EXCLUDE="$(awk '
    /^[[:space:]]*-[[:space:]]*id:[[:space:]]*terraform_fmt[[:space:]]*$/ { inhook = 1; next }
    inhook && /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/ { exit }
    inhook && /^[[:space:]]*exclude:[[:space:]]*/ { print; exit }
  ' "$PRECOMMIT")"
  PC_WHERE="the terraform_fmt hook"
  if [ -z "$PC_EXCLUDE" ]; then
    # Repo-level top-level exclude (column 0), which applies to every hook.
    PC_EXCLUDE="$(grep -m1 '^exclude:[[:space:]]*' "$PRECOMMIT" || true)"
    PC_WHERE="the repo-level exclude"
  fi
fi
if [ -z "$PC_EXCLUDE" ]; then
  ok "note: .pre-commit-config.yaml has no terraform_fmt or repo-level exclude yet (US-F-CIPARITY owns it) — nothing to agree with"
else
  # Strip the key and any surrounding quotes; keep the regex itself intact.
  PC_RE="${PC_EXCLUDE#*exclude:}"
  PC_RE="${PC_RE#"${PC_RE%%[![:space:]]*}"}"
  PC_RE="${PC_RE%"${PC_RE##*[![:space:]]}"}"
  PC_RE="${PC_RE#\'}"; PC_RE="${PC_RE%\'}"
  PC_RE="${PC_RE#\"}"; PC_RE="${PC_RE%\"}"
  if printf '%s' "$FIXTURE_PATH" | grep -qE "$PC_RE" 2>/dev/null; then
    ok "$PC_WHERE excludes the S13 fixture (regex '$PC_RE' matches $FIXTURE_PATH)"
  else
    bad "DIVERGENCE: $PC_WHERE ('$PC_RE') does NOT cover $FIXTURE_PATH — pre-commit will still destroy it"
  fi
  # Negative control: a targeted exclude, not terraform_fmt switched off wholesale.
  PC_CONTROL='modules/naming/variables.tf'
  if printf '%s' "$PC_CONTROL" | grep -qE "$PC_RE" 2>/dev/null; then
    bad "$PC_WHERE ('$PC_RE') also matches $PC_CONTROL — that is a blanket exclude, not a fixture exclude"
  else
    ok "$PC_WHERE leaves ordinary tracked .tf in scope (checked against $PC_CONTROL)"
  fi
fi

# ---------------------------------------------------------------------------
# 8. A repo whose only tracked .tf IS the fixture legitimately filters down to
#    an empty argv. That is a benign no-op, NOT the case-4 refusal. Getting this
#    polarity wrong manufactures a false red on a legitimate tree — the mirror
#    image of the case-4 defect, and just as easy to write.
# ---------------------------------------------------------------------------
case_ "8. filtering down to zero files is a benign no-op, not a refusal"
R8="$(make_repo s13 8)"
if (cd "$R8" && bash scripts/lab-fmt.sh >"$TMP/out8" 2>&1); then
  ok "a repo whose only tracked .tf is the S13 fixture exits 0"
else
  bad "false red: nothing-to-do was reported as a failure: $(cat "$TMP/out8")"
fi
if cmp -s "$REAL_S13" "$R8/$S13_REL"; then
  ok "the fixture is still byte-identical in the nothing-to-do case"
else
  bad "the fixture was rewritten in the nothing-to-do case"
fi

# ---------------------------------------------------------------------------
# 9. Tracked but absent from the worktree (staged deletion, sparse checkout,
#    skip-worktree). Handing tofu a missing path fails with a misleading
#    message; dropping it in silence leaves a success claiming every tracked
#    file was formatted. Warn and continue — mirroring verify.sh.
# ---------------------------------------------------------------------------
case_ "9. a tracked .tf missing from the worktree is warned about, not fatal"
R9="$(make_repo full 9)"
rm -f "$R9/zzz-late/main.tf"
if (cd "$R9" && bash scripts/lab-fmt.sh >"$TMP/out9" 2>&1); then
  ok "a staged-deleted .tf does not fail the run"
else
  bad "a staged-deleted .tf failed the run: $(cat "$TMP/out9")"
fi
if grep -qi 'absent from the worktree' "$TMP/out9"; then
  ok "the absent tracked file is reported by name"
else
  bad "the absent tracked file was dropped silently: $(cat "$TMP/out9")"
fi
if is_canonical "$R9/modules/aaa-early/main.tf"; then
  ok "the remaining files were still formatted"
else
  bad "one absent file aborted formatting of the rest"
fi

# ---------------------------------------------------------------------------
# 10. THE WIRING, AS AN ALLOWLIST.
#
#     Everything above proves scripts/lab-fmt.sh is safe. None of it proves
#     `task lab:fmt` — the command verify.sh advertises — still calls it.
#
#     THIS CASE WAS DEFEATED IN THREE SUCCESSIVE ROUNDS, and the reason it kept
#     happening is worth more than the fixes: it was a DENYLIST. It hunted for
#     `tofu fmt` in a bounded slice of the task and passed when it found none.
#     A denylist over an unbounded input can only ever enumerate the evasions
#     someone has already thought of, so each round shipped green and the next
#     round found more:
#
#       r2  `sh -c 'tofu fmt -recursive'` slipped a head-anchored pattern.
#       r3  a column-2 comment truncated the block; a `- |` scalar hid the
#           command on a continuation line.
#       r4  SEVEN more. A duplicate `lab:fmt:` key (go-task last-wins, and
#           check-yaml's SafeLoader also takes the last, so nothing else catches
#           it — this is what "keep both sides" on a merge conflict produces, and
#           five lanes are editing this file right now). `deps:`. `vars:`
#           indirection — the idiom `lab:validate` twenty lines below already
#           uses. A destructive `preconditions: sh:`. `terraform fmt` instead of
#           `tofu fmt`. A backslash continuation splitting the token across two
#           lines. Every one green while the fixture was destroyed.
#
#     The structural fault was that only the `cmds:` range was ever searched, so
#     every OTHER key go-task executes — deps, vars, preconditions — was out of
#     scope BY CONSTRUCTION. Fixing where the range ended, three times, never
#     addressed that a range existed at all. Worse, bounding the scan to `cmds:`
#     to kill a false-red is exactly what made the `preconditions:` attack
#     invisible: the previous round's fix created this round's hole.
#
#     So this is now an ALLOWLIST. It does not ask "does anything dangerous
#     appear?" — an unbounded question. It asks "is this task EXACTLY the four
#     things it is supposed to be?", which is bounded and answerable:
#
#       1. `lab:fmt:` is declared exactly ONCE.
#       2. The task's key set is exactly {desc, cmds, preconditions}.
#       3. `cmds` is exactly one line: `- bash scripts/lab-fmt.sh`.
#       4. `preconditions` is exactly the `command -v tofu` guard.
#
#     Adding deps, vars, env, a second cmds, a different precondition or a second
#     command all red — not because they are recognised as dangerous, but because
#     they are not on the list. A maintainer with a legitimate reason to add one
#     must consciously update this guard, which is the point. It also fixes two
#     FALSE reds the denylist produced, for the same reason.
#
#     WHAT IT STILL CANNOT SEE: the allowlist bounds THIS task. It cannot police
#     what `scripts/lab-fmt.sh` does — cases 1-9 do that — and it would not
#     notice `Taskfile.yaml` being replaced wholesale by an `includes:` from
#     elsewhere. Assertion 1 is a `grep -c` over the whole file, so a `lab:fmt`
#     defined in an included Taskfile is out of reach. Named, not papered over.
#
#     NO go-task CROSS-CHECK. An earlier version ran `task lab:fmt --dry -v` to
#     ask go-task itself. `--dry` does not skip `preconditions:` — it RUNS them.
#     Measured: with a destructive precondition, `--dry` took the real fixture
#     from 13f0af5a66fd to d0b767a2f3a9, and this self-test then printed
#     "PASSED — 32 checks OK, 0 failures" having destroyed the thing it exists to
#     protect, in the developer's own worktree. It was removed rather than moved
#     into a temp copy: it was never authoritative either (it is authoritative
#     about RESOLUTION, while the predicate applied to its output was the same
#     denylist), and the allowlist supersedes what it did cover. A self-test that
#     can mutate the tree it audits is not worth a second layer of assurance.
# ---------------------------------------------------------------------------
case_ "10. task lab:fmt is exactly the task it is supposed to be (allowlist)"
TASKFILE="$ROOT/Taskfile.yaml"

# 1. EXACTLY ONE DECLARATION. go-task silently last-wins on a duplicate task
#    name, so a second `lab:fmt:` anywhere in the file overrides the first while
#    every other check happily inspects whichever one it finds. Counted on the
#    RAW file: a duplicate is the thing being detected, so it must not be
#    normalised away first.
LABFMT_DECLS="$(grep -c '^  lab:fmt:[[:space:]]*$' "$TASKFILE" || true)"
if [ "${LABFMT_DECLS:-0}" -eq 1 ]; then
  ok "lab:fmt is declared exactly once in Taskfile.yaml"
else
  bad "lab:fmt is declared ${LABFMT_DECLS} times — go-task last-wins, so the effective task is not the one reviewed"
fi

# Comments stripped first so none can terminate a range; the block ends at the
# next real column-2 key, or at a column-0 key.
TASKFILE_NOCOMMENT="$(grep -v '^[[:space:]]*#' "$TASKFILE")"
LABFMT_BLOCK="$(printf '%s\n' "$TASKFILE_NOCOMMENT" | awk '
  /^  lab:fmt:[[:space:]]*$/ { inblock = 1; next }
  inblock && /^[^[:space:]]/  { exit }
  inblock && /^  [^[:space:]]/ { exit }
  inblock { print }
')"

# 2. EXACTLY THE EXPECTED KEY SET. This is what makes the guard bounded: deps,
#    vars, env, dotenv, includes, a second cmds — anything go-task would act on
#    reds here without this script needing to know what it does.
LABFMT_KEYS="$(printf '%s\n' "$LABFMT_BLOCK" | sed -n 's/^    \([A-Za-z_][A-Za-z0-9_-]*\):.*$/\1/p' | sort | tr '\n' ' ')"
LABFMT_KEYS="${LABFMT_KEYS% }"
LABFMT_KEYS_EXPECTED='cmds desc preconditions'
if [ "$LABFMT_KEYS" = "$LABFMT_KEYS_EXPECTED" ]; then
  ok "lab:fmt's keys are exactly {$LABFMT_KEYS_EXPECTED}"
else
  bad "lab:fmt's keys are {$LABFMT_KEYS} — expected exactly {$LABFMT_KEYS_EXPECTED}. If this addition is legitimate, update this allowlist deliberately"
fi

# 3. cmds IS EXACTLY ONE LINE, AND THAT LINE IS THE SCRIPT. One line, not one
#    item: a `- |` block scalar is several lines under a single item head, and
#    that is how round 3's evasion worked.
LABFMT_CMDS="$(printf '%s\n' "$LABFMT_BLOCK" | awk '
  /^    cmds:[[:space:]]*$/ { inc = 1; next }
  inc && /^    [^[:space:]]/ { exit }
  inc { print }
' | sed '/^[[:space:]]*$/d')"
LABFMT_CMD_LINES="$(printf '%s\n' "$LABFMT_CMDS" | sed '/^$/d' | wc -l | tr -d ' ')"
LABFMT_CMDS_NORM="$(printf '%s\n' "$LABFMT_CMDS" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
if [ "$LABFMT_CMD_LINES" = "1" ] && [ "$LABFMT_CMDS_NORM" = "- bash scripts/lab-fmt.sh" ]; then
  ok "lab:fmt's cmds is exactly one line: '- bash scripts/lab-fmt.sh'"
else
  bad "lab:fmt's cmds is ${LABFMT_CMD_LINES} line(s) [$LABFMT_CMDS_NORM] — expected exactly '- bash scripts/lab-fmt.sh'"
fi

# 4. THE PRECONDITION IS THE TOOL CHECK, NOTHING ELSE. `preconditions: sh:` runs
#    arbitrary shell, before cmds, every single invocation. It is as executable
#    as cmds and must be pinned just as tightly.
LABFMT_PRECOND_SH="$(printf '%s\n' "$LABFMT_BLOCK" | awk '
  /^    preconditions:[[:space:]]*$/ { inp = 1; next }
  inp && /^    [^[:space:]]/ { exit }
  inp { print }
' | sed -n 's/^[[:space:]]*-[[:space:]]*sh:[[:space:]]*//p' | sed 's/[[:space:]]*$//')"
if [ "$LABFMT_PRECOND_SH" = "command -v tofu" ]; then
  ok "lab:fmt's only precondition is 'command -v tofu'"
else
  bad "lab:fmt's precondition sh is '$LABFMT_PRECOND_SH' — expected 'command -v tofu'; preconditions run arbitrary shell on every invocation"
fi

# 5. SECONDARY, DEFENCE IN DEPTH. The allowlist above already forbids everything
#    this finds, so it should never fire on its own — it is here to keep biting
#    if the allowlist is ever loosened, and it is deliberately BROADER than the
#    predicates that were evaded: both formatters, any whitespace, and `-check`
#    (read-only) permitted. It is NOT relied upon: a backslash-split token
#    defeats any single-line pattern, which is precisely why assertion 3 counts
#    LINES instead of hunting for strings.
if printf '%s\n' "$LABFMT_BLOCK" | grep -qE '(tofu|terraform)[[:space:]]+fmt' && \
   ! printf '%s\n' "$LABFMT_BLOCK" | grep -E '(tofu|terraform)[[:space:]]+fmt' | grep -q -- '-check'; then
  bad "lab:fmt contains a mutating '(tofu|terraform) fmt' invocation — the S13 fixture is unprotected"
else
  ok "lab:fmt contains no mutating '(tofu|terraform) fmt' invocation"
fi

# ---------------------------------------------------------------------------
# 11. SYMLINKS. The fixture exclusion is a STRING COMPARE against a path from
#     `git ls-files`. A tracked symlink has its OWN path, which is not the
#     fixture's path, so the compare misses; `[ -f ]` follows the link and says
#     true; and tofu then writes THROUGH it to the fixture.
#
#     Reproduced against the real repo before this guard existed: a tracked
#     labs/day-2/13-static-analysis/messy/alias.tf -> main.tf took the fixture
#     from 13f0af5a66fd to d0b767a2f3a9 while lab-fmt.sh printed "formatted 88
#     tracked .tf file(s); left the S13 messy fixture untouched". It destroyed
#     the fixture AND reported that it had not — the worst pair.
#
#     Both halves are asserted here, because the message being honest is not a
#     nicety: it is what a reader relies on to believe a run was safe.
# ---------------------------------------------------------------------------
case_ "11. a tracked symlink cannot smuggle a write through to the fixture"
R11="$(make_repo full 11)"
ln -s main.tf "$R11/$S13_REL_DIR/alias.tf"
git -C "$R11" add "$S13_REL_DIR/alias.tf"
git -C "$R11" commit -q --no-verify -m 'tracked symlink'
if (cd "$R11" && bash scripts/lab-fmt.sh >"$TMP/out11" 2>&1); then
  ok "lab-fmt.sh completes with a tracked symlink present"
else
  bad "lab-fmt.sh failed outright on a tracked symlink: $(cat "$TMP/out11")"
fi
if cmp -s "$REAL_S13" "$R11/$S13_REL"; then
  ok "the fixture survives a tracked symlink pointing at it"
else
  bad "a tracked symlink wrote THROUGH to the fixture — the string-compare exclusion was bypassed"
fi
if grep -qi 'symlink' "$TMP/out11"; then
  ok "the skipped symlink is reported by name rather than dropped in silence"
else
  bad "the symlink was skipped silently: $(cat "$TMP/out11")"
fi
# The lie is the second half of the defect. A summary claiming the fixture was
# left untouched must not appear alongside a silently-followed link.
if grep -q 'symlink(s) skipped' "$TMP/out11"; then
  ok "the summary line accounts for the skipped symlink"
else
  bad "the summary does not mention the skipped symlink — it overstates what was checked"
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf 'lab-fmt selftest: PASSED — %d check(s) OK, 0 failures\n' "$PASS"
  exit 0
fi
printf 'lab-fmt selftest: FAILED — %d failure(s), %d OK\n' "$FAIL" "$PASS"
exit 1
