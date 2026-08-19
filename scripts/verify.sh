#!/usr/bin/env bash
# scripts/verify.sh — the "tested workshop" gate.
#
# Unit lane (no Docker needed):
#   1. deps preflight (tofu present, version)
#   2. tofu fmt -check over git-tracked *.tf (minus the S13 messy fixture);
#      falls back to a filesystem walk when the root is not a git work tree
#   3. per module/example/day-2-lab that has *.tf: tofu init -backend=false + validate
#   4. per module/example/day-2-lab that has *.tftest.hcl: tofu test (plan/mock lanes;
#      *integration*.tftest.hcl deferred to task verify:integration / CI verify-integration)
#   5. slide ↔ lab drift smoke check (source=/chdir=/cd/DIR= → modules|examples exist)
#   6. slide ↔ lab/pages drift ENFORCEMENT (annotated ```hcl blocks diffed vs source;
#      pages/** fences may carry magic-move metadata like ```hcl {none|…})
#   10. toolchain pin drift (versions.env consumers — US-P-PINS)
#
# Everything degrades to "nothing to check yet → pass" while the content dirs
# are empty, so this is safe to wire into CI from day one.
#
# Exit non-zero on any failure. Prints a clear pass/fail summary.
set -euo pipefail

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

title "OpenTofu Workshop · verify (unit lane)"

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
  # required 1.8". That would be a NEW spurious-red path introduced by the very
  # change meant to remove one — so stderr goes to a file, out of the parser's
  # way, and is echoed only when the probe actually fails.
  TOFU_VER_RC=0
  TOFU_VER_ERR="$(mktemp)"
  TOFU_VER_OUT="$(tofu version 2>"$TOFU_VER_ERR")" || TOFU_VER_RC=$?
  TOFU_VER="$(printf '%s\n' "$TOFU_VER_OUT" | awk 'NR == 1 { print $2 }')"
  if [ "$TOFU_VER_RC" -ne 0 ] || [ -z "$TOFU_VER" ]; then
    fail "tofu version probe failed (exit $TOFU_VER_RC) — cannot establish the toolchain version"
    info "tofu said:"
    # Both streams here: when the probe fails, whatever it managed to say is the
    # whole of the evidence, and dropping either half is how this became a
    # mystery in the first place.
    { printf '%s\n' "$TOFU_VER_OUT"; cat "$TOFU_VER_ERR"; } | sed 's/^/    /'
  elif min_version "${TOFU_VER#v}" "1.8"; then
    pass "tofu ${TOFU_VER} (>= 1.8)"
  else
    fail "tofu ${TOFU_VER} is below the required 1.8"
  fi
  rm -f "$TOFU_VER_ERR"
else
  fail "tofu not found on PATH (install: brew install opentofu)"
  heading "Summary"
  bad "verify FAILED — tofu is required. $FAILURES failure(s)."
  exit 1
fi

# Collect module/example dirs that actually contain Terraform/OpenTofu code,
# plus day-2 lab workdirs that ship *.tftest.hcl (audit TEST-A2). Lab dirs
# without a tftest suite stay out of the validate/test loop — they are learner
# scratch or tool-only fixtures (e.g. S13 messy) and are covered elsewhere.
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
# Day-2 labs: discover workdirs that contain both *.tf and *.tftest.hcl
# (top-level or under tests/). Integration-named suites are filtered later.
for d in labs/day-2/*/; do
  [ -d "$d" ] || continue
  tf=("$d"*.tf)
  [ "${#tf[@]}" -gt 0 ] || continue
  lab_tests=("$d"*.tftest.hcl "$d"tests/*.tftest.hcl)
  [ "${#lab_tests[@]}" -gt 0 ] && CODE_DIRS+=("${d%/}")
done
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
  fail "unformatted files found — run 'task lab:fmt' (tofu fmt -recursive)"
  info "offending files:"
  tofu fmt -check "${FORMAT_FILES[@]}" 2>/dev/null | sed 's/^/    /' || true
fi

# ---------------------------------------------------------------------------
# 3 & 4. validate + test per code dir
# ---------------------------------------------------------------------------
heading "Validate & test"
if [ "${#CODE_DIRS[@]}" -eq 0 ]; then
  warn "no modules/* / examples/* / labs/day-2 tftest roots with .tf files yet — nothing to validate."
  info "This is expected before lab content is authored. (pass)"
else
  for d in "${CODE_DIRS[@]}"; do
    info "→ $d"
    # init without a backend so validate has its providers, no remote state.
    if tofu -chdir="$d" init -backend=false -input=false >/dev/null 2>&1; then
      if tofu -chdir="$d" validate -no-color >/dev/null 2>&1; then
        pass "$d: validate"
      else
        fail "$d: validate"
        tofu -chdir="$d" validate -no-color 2>&1 | sed 's/^/    /' || true
      fi
    else
      fail "$d: init failed (cannot validate)"
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
#    Contract (see AGENT.md · "Lab workdir & drift contract"): a fenced ```hcl
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
    info "Annotate a block with '<!-- source: PATH -->' above its fence to enforce it (see AGENT.md)."
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
    "contributor guide|AGENT.md"
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

  if [ "$PIN_FAILURES" -eq 0 ]; then
    pass "toolchain pins: all listed consumers match versions.env"
  fi
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
