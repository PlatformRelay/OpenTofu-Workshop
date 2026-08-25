#!/usr/bin/env bash
# scripts/lab-fmt.sh — the remediation half of the fmt gate (`task lab:fmt`).
#
# THE DEFECT THIS REPLACES (US-F-FMTSCOPE)
#
# This task used to be a bare `tofu fmt -recursive` from the repo root, and it
# is the exact remedy scripts/verify.sh names when its fmt gate reds. Running
# the advertised remedy silently DESTROYED a teaching fixture:
# labs/day-2/13-static-analysis/messy/main.tf is a deliberately unformatted
# Day-2 static-analysis exercise — unindented `required_version`, unaligned
# `type =` / `default =` / `value =`. Being unformatted IS its purpose, and a
# read-only `tofu fmt -check` over the tree shows it is the ONLY non-canonical
# file in the repo. So `-recursive` had exactly one file to "fix", and fixing it
# was the whole damage. It fired in the wild on 2026-08-19: a worktree was found
# holding one modified file — that fixture, canonicalised away.
#
# CORRECTION, verified rather than assumed: `-recursive` did NOT reach the agent
# worktrees. `tofu fmt -recursive` SKIPS dot-prefixed directories, so
# .worktrees/<lane>/ and .claude/worktrees/<lane>/ were never in its reach —
# reproduced by planting identical unformatted files in `.worktrees/x/`,
# `.claude/worktrees/y/` and `normal/`, running `tofu fmt -recursive`, and seeing
# only `normal/main.tf` rewritten. An earlier draft of this header asserted the
# opposite and was wrong. What `-recursive` DID reach is every NON-dot directory
# under the root — which is labs/, which is the fixture. That is the whole
# hazard; the sibling-worktree story was never part of it.
#
# The dot-skip is luck, not protection: a worktree at a non-dot path (or any
# untracked clone, vendored tree or build output that is not dot-prefixed) sits
# squarely in `-recursive`'s path. Index scoping removes the class rather than
# relying on a prefix convention.
#
# `-recursive` is NOT the only path that destroys this fixture. Two others exist
# at the time of writing:
#   * .pre-commit-config.yaml's `terraform_fmt` hook — `files: \.tf$` with NO
#     `exclude:` — rewrites the fixture on commit or on the `pre-commit run
#     --all-files` its own header documents. Independently reproduced. This is
#     the likelier cause of the 2026-08-19 incident than `task lab:fmt`, and it
#     is NOT fixed by this script. Owner: lane/us-f-ciparity.
#   * labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml's bare
#     `tofu fmt -recursive` — a DELIBERATELY planted false-green gate the lab
#     teaches learners to find. Leave it alone; any grep-and-fix sweep for
#     `fmt -recursive` must skip it.
#
# SCOPE: the git INDEX minus that fixture — deliberately the SAME mechanism
# verify.sh §2 uses to DETECT (US-F-VERIFY-WT), because detection and
# remediation disagreeing means one of them is lying to the user. Untracked
# files, sibling worktrees, node_modules and provider caches fall out of scope
# structurally, with no exclusion list to keep in sync and no dependence on a
# dot-prefix convention.
#
# Trade-off, inherited from verify.sh on purpose: a brand-new .tf that has never
# been `git add`ed is not formatted. It is picked up the moment it is staged,
# and verify.sh will not red on it before then either. The two halves agreeing
# matters more than either one's individual reach.
#
# scripts/lab-fmt-selftest.sh covers every branch below, including the two
# defects the verify.sh change introduced into its own error paths.
set -euo pipefail

# TF_CLI_ARGS / TF_CLI_ARGS_fmt TURN `tofu fmt -check` INTO A MUTATOR, so they
# are cleared before any tofu invocation below. OpenTofu splices these env args
# in BEFORE user argv, and a positional in them terminates flag parsing:
#
#   TF_CLI_ARGS_fmt="-recursive ." tofu fmt -check <path>
#
# becomes `tofu fmt -recursive . -check <path>` — the `.` is formatted
# RECURSIVELY, `-check` is demoted from a flag to a path, and only then does tofu
# error on it (rc=2). Reproduced: that one line took the S13 fixture from
# 13f0af5a66fd to d0b767a2f3a9, and this script then reported "formatted 87
# tracked .tf file(s); left the S13 messy fixture untouched" — destroyed it and
# said otherwise.
#
# This falsifies TWO assumptions this script was built on: that `fmt -check` is
# read-only, and that passing explicit paths bounds the blast radius. Neither
# holds. No repo edit and no maintainer error is required — an exported shell
# var, a direnv .envrc, or a CI env is enough, which is the 2026-08-19 incident
# shape arriving through a new door.
#
# Scoped deliberately to these two names. Clearing all TF_* would also wipe
# TF_LOG, TF_DATA_DIR and provider credentials that callers legitimately set,
# trading one surprise for another.
unset TF_CLI_ARGS TF_CLI_ARGS_fmt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Kept byte-identical to verify.sh's declaration — scripts/lab-fmt-selftest.sh
# case 7 greps both files and fails on divergence, so moving the fixture forces
# both halves to move together instead of one silently regressing.
S13_MESSY_FIXTURE='labs/day-2/13-static-analysis/messy/main.tf'

command -v tofu >/dev/null 2>&1 || {
  echo "lab:fmt: tofu is required. Install: brew install opentofu" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# FIXTURE POST-CONDITION — the outermost safety net, on an EXIT trap.
#
# Everything else in this script reasons about WHICH PATHS are handed to tofu.
# That reasoning has now been wrong twice in ways nothing here could see: a
# tracked symlink wrote through to the fixture under a different path, and
# TF_CLI_ARGS_fmt made a read-only `-check` reformat the whole tree regardless of
# argv. Both destroyed the fixture while this script printed "left the S13 messy
# fixture untouched". So the final claim is no longer INFERRED from the path
# list — it is OBSERVED against the file itself, immediately before exiting.
#
# Three properties this depends on, each learned the hard way:
#
#   * ON A TRAP, NOT A LINE BEFORE THE FINAL echo. A Taskfile's `deps:` and
#     `preconditions:` both run BEFORE `cmds:`, so damage can already be done by
#     the time this script starts; and the script has four exit paths (two
#     refusals, the nothing-to-do branch, and normal completion). A trap observes
#     all of them. A check placed before the summary would be evasion number 12.
#
#   * CONTENT-BASED, NEVER AGAINST THE INDEX BLOB. Comparing the worktree file to
#     its staged blob greens forever the moment someone runs `git add -A` after a
#     destructive run — the index then holds the destroyed copy and agrees with
#     it. The assertion is that the fixture is still NON-CANONICAL, which is the
#     property that actually makes it a teaching fixture.
#
#   * IT NEEDS THE unset ABOVE. The probe is itself `tofu fmt -check`, so without
#     clearing TF_CLI_ARGS_fmt the post-condition would be the thing that
#     destroys the fixture — precisely how the self-test's startup guard failed.
#
# Skipped when the fixture is absent or is itself a symlink: this script must
# keep working in a checkout without that lab, and a missing file is not a
# regression.
#
# NOTE THE POLARITY. The trap does NOT ask "did THIS SCRIPT change it?" — it asks
# "is it canonical NOW?". Those differ, and the difference is the whole point: a
# Taskfile's `deps:` and `preconditions:` run BEFORE `cmds:`, so by the time this
# script starts the fixture can already be destroyed. Gating on "it was
# unformatted when we started" would make every such attack invisible — this
# script would shrug and report success over an already-ruined fixture. Being
# canonical is never correct for this file: unformatted IS what it is for. So
# canonical at exit is a failure regardless of who did it, and the message
# distinguishes the two cases to point at the right culprit.
S13_ALREADY_DESTROYED=0
S13_WATCHED=0
if [ -f "$REPO_ROOT/$S13_MESSY_FIXTURE" ] && [ ! -L "$REPO_ROOT/$S13_MESSY_FIXTURE" ]; then
  S13_WATCHED=1
  if tofu fmt -check "$REPO_ROOT/$S13_MESSY_FIXTURE" >/dev/null 2>&1; then
    S13_ALREADY_DESTROYED=1
  fi
fi

_lab_fmt_on_exit() {
  rc=$?
  rm -f "${GIT_TF_LIST:-}" "${GIT_TF_ERR:-}" 2>/dev/null || true
  if [ "$S13_WATCHED" -eq 1 ] &&
    [ -f "$REPO_ROOT/$S13_MESSY_FIXTURE" ] &&
    tofu fmt -check "$REPO_ROOT/$S13_MESSY_FIXTURE" >/dev/null 2>&1; then
    echo "" >&2
    echo "lab:fmt: FIXTURE DESTROYED — $S13_MESSY_FIXTURE is canonically formatted." >&2
    echo "         It is the Day-2 static-analysis exercise; being unformatted IS its" >&2
    echo "         purpose, so canonical means broken." >&2
    if [ "$S13_ALREADY_DESTROYED" -eq 1 ]; then
      echo "         It was ALREADY destroyed before this script started, so the cause" >&2
      echo "         is upstream of it: a Taskfile 'deps:' or 'preconditions:' entry" >&2
      echo "         (both run before 'cmds:'), a pre-commit terraform_fmt hook, or an" >&2
      echo "         earlier command in the same shell." >&2
    else
      echo "         It was intact when this script started, so this invocation did it:" >&2
      echo "         look for TF_CLI_ARGS/TF_CLI_ARGS_fmt in the environment or a" >&2
      echo "         tracked symlink pointing at the fixture." >&2
    fi
    echo "         Restore it with:  git checkout -- $S13_MESSY_FIXTURE" >&2
    exit 1
  fi
  exit "$rc"
}
trap _lab_fmt_on_exit EXIT
# ---------------------------------------------------------------------------

# A .git ENTRY at the root is the discriminator — a directory in a normal clone,
# a FILE in a linked worktree. Same test verify.sh uses, and deliberately not a
# `git rev-parse --show-toplevel` comparison: that returns the PHYSICAL path
# while REPO_ROOT is logical, so on macOS (/var → /private/var) it would
# mis-route without anyone noticing.
#
# verify.sh falls back to a filesystem walk here; this script must NOT. verify.sh
# only READS, and its fallback exists solely because its self-test copies it into
# a non-git temp root. A walk from an unknown root is the precise behavior being
# removed, and doing it in a MUTATOR is how the fixture died. Refuse instead.
if ! [ -e "$REPO_ROOT/.git" ]; then
  echo "lab:fmt: refusing to run — $REPO_ROOT is not a git work tree, and this" >&2
  echo "         command is scoped to tracked files. A filesystem walk here would" >&2
  echo "         rewrite whatever .tf happens to sit under this root, which is the" >&2
  echo "         defect this script exists to remove. Run it from a checkout." >&2
  exit 1
fi

GIT_TF_LIST="$(mktemp)"
GIT_TF_ERR="$(mktemp)"
# Cleanup is handled by _lab_fmt_on_exit above. A second `trap ... EXIT` here
# would REPLACE that handler and silently uninstall the fixture post-condition.

SCAN_OK=1
# Routed through a temp file rather than `< <(git ls-files …)`: process
# substitution discards the exit status, so a git that REFUSES (stale linked
# worktree gitdir, safe.directory/dubious ownership, corrupt index) would yield
# an empty list and be indistinguishable from "nothing to do". Command
# substitution is no good either — "$(git ls-files -z)" strips the NUL bytes and
# collapses the list into one bogus path. git's own stderr is kept rather than
# discarded, so the operator gets git's diagnosis instead of guessing.
git ls-files -z -- '*.tf' >"$GIT_TF_LIST" 2>"$GIT_TF_ERR" || SCAN_OK=0
# A non-zero exit is only HALF the failure surface. git also fails SOFTLY,
# exiting 0 with empty output: a deleted .git/index, a fresh `git init` with
# nothing staged, and a GIT_INDEX_FILE pointing at a nonexistent index all do
# this. An empty list then makes this script format NOTHING and report success —
# the user's fmt failure stays unfixed and the remedy claims it worked. Gate on
# RAW OUTPUT emptiness, deliberately NOT on ${#FORMAT_FILES[@]}: a tree whose
# only tracked .tf is the S13 fixture legitimately filters down to an empty
# array and must stay a benign no-op (see the nothing-to-do branch below).
[ -s "$GIT_TF_LIST" ] || SCAN_OK=0

if [ "$SCAN_OK" -eq 0 ]; then
  # `head` must be the SOURCE of this pipeline, never its sink. As a sink it
  # closes the pipe early and can SIGPIPE the upstream, which under
  # `set -o pipefail` fails the substitution and `set -e` kills the script —
  # from inside the branch whose entire job is to REPORT a failure. Multi-line
  # stderr (safe.directory dubious-ownership is ~5 lines) is the trigger.
  SCAN_ERR="$(head -n 3 "$GIT_TF_ERR" | tr -d '\r' | tr '\n' ' ')"
  echo "lab:fmt: refusing to run — 'git ls-files' returned no usable file list at a" >&2
  echo "         root that has a .git entry (stale worktree gitdir, safe.directory," >&2
  echo "         or a corrupt/absent index). Formatting nothing and calling it a" >&2
  echo "         success would leave your fmt failure unfixed." >&2
  [ -n "$SCAN_ERR" ] && echo "         git said: $SCAN_ERR" >&2
  exit 1
fi

FORMAT_FILES=()
SKIPPED=0
SKIPPED_LINKS=0
while IFS= read -r -d '' tf_file; do
  # The one file this command exists to protect.
  [ "$tf_file" = "$S13_MESSY_FIXTURE" ] && continue
  # A tracked SYMLINK defeats the string compare above and writes THROUGH to its
  # target. `git ls-files` reports the link's own path, which is not the fixture
  # path, so the exclusion misses; `[ -f ]` follows the link and reports true;
  # and tofu then rewrites the target. Reproduced: a tracked
  # labs/day-2/13-static-analysis/messy/alias.tf -> main.tf took the fixture from
  # 13f0af5a66fd to d0b767a2f3a9 while this script printed "left the S13 messy
  # fixture untouched" — destroying the fixture AND lying about it.
  #
  # Skipped rather than resolved-and-compared. A symlink is not source: whatever
  # it points at is either tracked (and formatted on its own merits, under its
  # own path, where the exclusion works) or deliberately outside scope. Resolving
  # would also mean formatting a path outside the index via an in-index alias,
  # which is the reach this script exists to remove. Said out loud, never silent.
  if [ -L "$tf_file" ]; then
    echo "lab:fmt: tracked .tf is a symlink — skipped (its target is formatted under its own path, if tracked): $tf_file" >&2
    SKIPPED_LINKS=$((SKIPPED_LINKS + 1))
    continue
  fi
  # Tracked but not in the worktree: a staged deletion, sparse checkout, or the
  # skip-worktree bit. Handing tofu a missing path fails with a misleading
  # message; dropping it in silence leaves a success message asserting every
  # tracked file was formatted. Say so and carry on.
  if [ ! -f "$tf_file" ]; then
    echo "lab:fmt: tracked .tf absent from the worktree — skipped: $tf_file" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  FORMAT_FILES+=("$tf_file")
done <"$GIT_TF_LIST"

if [ "${#FORMAT_FILES[@]}" -eq 0 ]; then
  echo "lab:fmt: no tracked .tf files to format outside the S13 messy fixture — nothing to do"
  exit 0
fi

# Explicit paths, not -recursive. tofu rewrites every path it is given, so the
# whole list goes in one invocation.
tofu fmt "${FORMAT_FILES[@]}"

# The summary states what this script DID — the scope it worked on. It no longer
# asserts the fixture's OUTCOME ("left it untouched"), because that claim was
# false twice: under a tracked symlink and under TF_CLI_ARGS_fmt it printed
# "untouched" over a destroyed file. Outcome is now the EXIT TRAP's job, which
# observes the file rather than inferring from the path list. One claim, one
# owner, and the reassuring sentence can no longer contradict reality.
SUMMARY="lab:fmt: formatted ${#FORMAT_FILES[@]} tracked .tf file(s); the S13 messy fixture was excluded from the file list"
[ "$SKIPPED" -gt 0 ] && SUMMARY="$SUMMARY (${SKIPPED} tracked path(s) absent from the worktree — see above)"
[ "$SKIPPED_LINKS" -gt 0 ] && SUMMARY="$SUMMARY (${SKIPPED_LINKS} tracked symlink(s) skipped — see above)"
echo "$SUMMARY"
