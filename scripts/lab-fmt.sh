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
trap 'rm -f "$GIT_TF_LIST" "$GIT_TF_ERR"' EXIT

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

SUMMARY="lab:fmt: formatted ${#FORMAT_FILES[@]} tracked .tf file(s); left the S13 messy fixture untouched"
[ "$SKIPPED" -gt 0 ] && SUMMARY="$SUMMARY (${SKIPPED} tracked path(s) absent from the worktree — see above)"
[ "$SKIPPED_LINKS" -gt 0 ] && SUMMARY="$SUMMARY (${SKIPPED_LINKS} tracked symlink(s) skipped — see above)"
echo "$SUMMARY"
