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
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="$ROOT/scripts/lab-fmt.sh"
S13_REL='labs/day-2/13-static-analysis/messy/main.tf'

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
  git -C "$r" config user.email selftest@example.invalid
  git -C "$r" config user.name 'lab-fmt selftest'
  case "$mode" in
    full) git -C "$r" add -A ;;
    s13)  git -C "$r" add "scripts/lab-fmt.sh" "$S13_REL" ;;
    none) : ;;
  esac
  [ "$mode" = none ] || git -C "$r" commit -qm 'selftest fixture'
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
# 10. THE WIRING. Everything above proves scripts/lab-fmt.sh is safe. NONE of it
#     proves `task lab:fmt` — the command verify.sh actually advertises — still
#     calls it. Reverting Taskfile.yaml's `lab:fmt` cmds to `tofu fmt -recursive`
#     left this self-test AND verify.sh fully green while the fixture burned:
#     verify.sh enumerates task NAMES only, never their `cmds`. That is the same
#     hand-maintained-parity defect this lane flags in ci.yml, reintroduced by
#     the fix itself, so it is pinned here rather than merely commented.
#
#     Parsed with awk rather than a YAML library to keep the self-test free of
#     runtime deps: take the lines after the `  lab:fmt:` key up to the next
#     2-space-indented key. The extraction is asserted to have WORKED before
#     anything is concluded from it — an awk that silently matches nothing would
#     otherwise "find no -recursive" and pass over a block it never read, which
#     is exactly the empty-scan degradation case 4 exists to forbid.
# ---------------------------------------------------------------------------
case_ "10. task lab:fmt is still wired to scripts/lab-fmt.sh"
TASKFILE="$ROOT/Taskfile.yaml"
LABFMT_BLOCK="$(awk '
  /^  lab:fmt:[[:space:]]*$/ { inblock = 1; next }
  inblock && /^  [^[:space:]]/ { exit }
  inblock { print }
' "$TASKFILE")"
# Narrow the block to its cmds LIST ITEMS before asserting anything. Substring
# matching the whole block would include the prose comments inside `lab:fmt:` —
# a comment merely MENTIONING `bash scripts/lab-fmt.sh` would satisfy the wiring
# assertion while `cmds` ran something else entirely. That is the identical
# vacuity F3 was raised for, and it would be invisible: the case stays green.
LABFMT_CMDS="$(printf '%s\n' "$LABFMT_BLOCK" | grep -E '^[[:space:]]*-[[:space:]]' || true)"
if [ -n "$LABFMT_BLOCK" ] && printf '%s' "$LABFMT_BLOCK" | grep -q '^    cmds:' && [ -n "$LABFMT_CMDS" ]; then
  ok "the lab:fmt cmds list was extracted from Taskfile.yaml"
else
  bad "could not extract lab:fmt's cmds from $TASKFILE — this case proves nothing; fix the parser"
fi
# Anchored to a whole list item, not a substring of the block.
if printf '%s\n' "$LABFMT_CMDS" | grep -qE '^[[:space:]]*-[[:space:]]+bash scripts/lab-fmt\.sh[[:space:]]*$'; then
  ok "a lab:fmt cmd is exactly 'bash scripts/lab-fmt.sh'"
else
  bad "no lab:fmt cmd invokes scripts/lab-fmt.sh — every case above is now moot"
fi
# Anywhere in a cmd, not just at its head: `- sh -c 'tofu fmt -recursive'` and
# `- tofu fmt -recursive` are equally destructive and must both red.
if printf '%s\n' "$LABFMT_CMDS" | grep -q 'tofu fmt'; then
  bad "a lab:fmt cmd shells out to 'tofu fmt' — the S13 fixture is unprotected"
else
  ok "no lab:fmt cmd shells out to 'tofu fmt' directly"
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf 'lab-fmt selftest: PASSED — %d check(s) OK, 0 failures\n' "$PASS"
  exit 0
fi
printf 'lab-fmt selftest: FAILED — %d failure(s), %d OK\n' "$FAIL" "$PASS"
exit 1
