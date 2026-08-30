#!/usr/bin/env bash
# scripts/verify-selftest.sh — regression protection for three ENFORCEMENT gates in
# scripts/verify.sh: (A) slide↔lab/pages drift enforcement (section 6), (B) deck tier
# consistency + hide invariant (section 7), and (C) the README navigation
# contract (section 8), plus the Day-2/3 skip contract (section 9). These gates are positive-only in the
# tracked tree (matching fixture / consistent decks), so silently deleting or
# weakening any of them would leave the build green and nobody would notice. This
# meta-test proves each check actually FAILS when it should.
#
# How it works: it copies the LIVE verify.sh + setup/lib.sh + the drift-demo
# fixture (and, for the tier cases, the two content decks) into a throwaway temp
# root. Because verify.sh derives REPO_ROOT from its own location and `cd`s there,
# the copy auto-isolates to the temp dir — no modules/examples, so tofu
# validate/test are no-ops and it runs sub-second. Copying at runtime (not
# vendoring a snapshot) means removing/weakening the enforcement in the real
# verify.sh turns THIS test red — that is the regression protection.
#
# Cases, each asserting BOTH exit code AND message (exit code alone is ambiguous —
# a clean pass could be a silent "no annotated blocks / no headers" no-op, and a
# non-zero could be an env break rather than a real violation):
#   drift gate (section 6):
#     1. clean      → exit 0  AND  "no drift: …main.tf matches"   (enforcement ARMED)
#     2. LF drift   → exit !=0 AND  "✗ drift: …main.tf"           (catches drift)
#     3. CRLF drift → exit !=0 AND  "✗ drift: …main.tf"           (locks in F1)
#     4. pages/ magic-move clean → exit 0 AND "…matches its block in index.md"
#        (fence metadata ```hcl {none|…}``` tolerated; pages/** scan ARMED)
#     5. pages/ LF drift → exit !=0 AND pages/…/index.md named
#     6. pages/ CRLF drift → exit !=0 AND pages/…/index.md named   (F1 on pages)
#     6b. slides-templates.md magic-move clean → exit 0 AND
#         "…matches its block in slides-templates.md" (root deck in DRIFT_FILES)
#     6c. slides-templates.md LF drift → exit !=0 AND slides-templates.md named
#   tier gate (section 7):
#     7. cross-deck tier mismatch → exit !=0 AND "tier drift: S05 …"   (deck↔deck)
#     8. hide-invariant violation → exit !=0 AND "hide invariant: S18 …" (3-day cut)
#   README navigation gate (section 8):
#     9. clean routes → exit 0 AND "README navigation contract"
#    10. deleted route → exit !=0 AND the route label + path
#    11. unknown task → exit !=0 AND the command name
#   Day-2/3 tool contract (section 9):
#    12. broken/absent tool → exit 0 AND an explicit affected-lab skip warning
#   formatting allowlist contract (section 2):
#    13. exact S13 messy fixture → exit 0 AND formatting gate remains armed
#    14. another unformatted .tf beside the fixture → exit !=0 AND path is named
#    15. any other unformatted .tf → exit !=0 AND offending path is named
#    16. unformatted .tf under .claude/worktrees/ → exit 0 (ignored; no false fail)
#    17. unformatted .tf under node_modules/ → exit 0 (ignored)
#    18. unformatted .tf under */.terraform/ → exit 0 (ignored)
#    18b. unformatted .tf under .worktrees/<lane>/ → exit 0 (sibling git worktree;
#         US-F-VERIFY-WT — exercises the `find` FALLBACK path)
#    18c. git-inited root + untracked .worktrees/<lane>/ → exit 0 (primary
#         `git ls-files` path selected; sibling worktree structurally invisible)
#    18d. git-inited root + TRACKED unformatted .tf → exit !=0 AND path named
#         (proves the primary path is ARMED, not silently returning nothing)
#    18e. .git entry present but `git ls-files` exits 128 (stale worktree gitdir,
#         safe.directory, corrupt index) → exit !=0 AND an explicit refusal, never
#         a green tick over an unscanned tree
#    18f. .git entry present but `git ls-files` exits 0 with EMPTY output (deleted
#         .git/index, fresh init, bogus GIT_INDEX_FILE) → exit !=0 AND the same
#         refusal (review F1: the rc guard alone does not catch this)
#    18g/18h. git-path S13 allowlist, both directions — the git scan compares
#         ROOT-RELATIVE paths, which cases 13-18e never exercised (review F3)
#    18i. tracked path listed by git but absent from the worktree → exit 0 AND an
#         explicit warning, never a bare green claiming all files were checked
#         (review F2; warn not fail, so a staged deletion is not a new false-red)
#   day-2 lab tftest discovery (TEST-A2 / section 3–4 CODE_DIRS):
#    19. planted labs/day-2/*/tests/*.tftest.hcl → exit 0 AND "…: tofu test (plan/mock)"
#    20. broken lab unit assert → exit !=0 AND the lab path named (discovery ARMED)
#    21. lab with only *integration*.tftest.hcl → exit 0 AND deferred message (unit skip)
#   day-1/day-3 lab workdir validation (US-C-GATE / section 3 CODE_DIRS):
#    21a. clean labs/day-1/** workdir → exit 0 AND "…: validate" (discovery ARMED —
#         a pass alone would also be produced by never looking at the dir)
#    21b. labs/day-1/** with an undeclared reference → exit !=0 AND the dir named,
#         with every annotated block in sync (the §6 drift gate CANNOT see this)
#    21c. labs/day-3/**/stacks/<name>/ with an undeclared reference → exit !=0 AND
#         the nested dir named (pins RECURSIVE discovery; day-3 has no top-level roots)
#   day-2 lab workdir sweep (US-E-D2SWEEP / section 3 CODE_DIRS):
#    21d. broken .tf in a NESTED day-2 workdir with no *.tftest.hcl → exit !=0 AND
#         the nested dir named (day-2 sweep ARMED and recursive, not tftest-gated)
#    21e. validate-broken .tf planted in 14-security-scanners/messy/ AND in a
#         subdir of it → exit 0 while a swept sibling's "…: validate" line shows
#         the sweep ran (messy/ excluded BY PATH PREFIX, not by silent no-op)
#   §5 smoke-check scope (US-F-R4):
#    22. prose mentioning modules/does-not-exist → exit 0 (NOT a shared-code ref)
#    23. missing path in HCL source = "…modules/…" → exit !=0 AND path named (ARMED)
#    24. missing examples/… via -chdir=/cd/DIR= → exit !=0 AND path named (ARMED)
#   release script self-tests (US-P-REL):
#    25–26. release-tag-guard-selftest + release-notes-flags-selftest → exit 0
#   lab inventory (US-P-VALDOCS):
#    27–28. lab-inventory.test.mjs + lab-inventory.mjs --check → exit 0
#   toolchain pin drift (US-P-PINS / section 10):
#    29. clean pins → exit 0 AND "toolchain pins: all listed consumers match versions.env"
#    30. skewed Dockerfile TOFU default → exit !=0 AND pin drift named
#    31. skewed compose LocalStack image ref → exit !=0 AND pin drift named
#    32. skewed ci.yml tofu_version → exit !=0 AND pin drift named
#   SEC-4 offline pin (no network; live verify stays in terratest Dockerfile):
#    33. versions.env TOFU_VERSION matches committed artifact/SUMS fixture
#   version-floor skew (US-D-VERSION-FLOOR / section 11):
#    33a. clean tree → exit 0 AND "version floor: consumers state" (gate ARMED)
#    33b. bootstrap MIN_TOFU skewed away from TOFU_FLOOR → exit !=0 AND
#         "floor skew: bootstrap MIN_TOFU" named
#    33c. a planted lab artifact demanding more than the floor → exit !=0 AND
#         the file and its ">= 99.0" ceiling violation named
#   preflight robustness (verify.sh section 1):
#    34. a FAILING `tofu version` probe → exit !=0 AND the failure NAMED AND the
#        run reaching its summary (never the 4-line silent death that cost a revert)
#   this script's OWN diagnostics — gate code needs a gate too:
#    35. dump_case_output on empty input → 0 lines AND "(no output at all"
#    36. dump_case_output on short input → verbatim, closing marker present
#    37. flood payload still exceeds the 64 KiB pipe capacity (else 39 is disarmed)
#    38. dump_case_output on a flood → head AND elision marker AND tail AND
#        closing marker, exit 0 (pins the `sed -n` that replaced a fatal `head`)
#    39. run_case WIRING: a failing case emits the dump, not a filtered grep
#   this script's OWN temp hygiene (US-F-GATEHYG):
#    40. run_case removes its temp root on the PASS path
#    41. run_case removes its temp root on the FAIL path (the wiring probe's
#        deliberately failing case — the branch a green run never enters)
#    42. whole-run sweep: EVERY case removed its own tree, 0 leaked. Deleting
#        run_case's `rm -rf` and leaning on the script-level EXIT trap instead
#        is a red, not a silent behaviour change.
#    43. whole-run sweep: no case left a .verify.lock behind (pass AND fail
#        exits) — a run that does not release wedges every later run
#   the fmt DETECTOR must stay read-only (US-F-GATEHYG round 2):
#    43b. verify.sh run with TF_CLI_ARGS/TF_CLI_ARGS_fmt="-recursive ." leaves
#         the S13 messy fixture BYTE-IDENTICAL, still unformatted, and still
#         exits 0. OpenTofu splices those vars in before user argv, so the
#         positional demotes `-check` to a path and `tofu fmt` rewrites the
#         whole checkout. Asserted against a pristine copy, never against the
#         git index — after a destructive run plus `git add -A` the index holds
#         the destroyed copy and an index check passes forever.
#   verify.sh single-run guard (US-F-GATEHYG, verify.sh section 0):
#    44. a second run against the same checkout → exit 2 AND a refusal naming
#        the holder, not silent provider-cache corruption
#    45. the refused run leaves the LIVE holder's lock intact (the error path
#        that would otherwise reopen the corruption it just refused)
#    46. a STALE lock (recorded pid provably dead) is named, broken, and the
#        run completes — a wedge is worse than the bug being fixed
#    46b. an UNUSABLE lock path (a stray regular file where the directory
#        belongs) is diagnosed as itself — `mkdir` fails with EEXIST there too,
#        so without the guard it would be reported as a phantom concurrent run
#    46c. a lock recorded on ANOTHER host, whose pid is dead LOCALLY → refused
#        intact (review G4; a live pid would let a broken host check pass)
#    46d. a lock with an UNREADABLE pid → refused intact, never assumed dead
#        (review G5; malformed rather than absent, so the host check cannot
#        produce the refusal and the pid guard is the thing under test)
#    46e. TWO RACERS: a stale-lock break must not destroy a lock re-acquired
#        between the read and the break (review G1). Reproduced against the
#        unfixed code by stubbing `cat` to return the STALE pid and only then
#        hold the pipe open — the delay has to come after the read, or the
#        guard sees the new pid and the case passes for the wrong reason.
#    46f. TWO BREAKERS racing on the same stale lock: exactly one break, exactly
#        one refusal, exactly one run past the guard (review F1). This is the
#        ONLY coverage of the `mv` arbitration — 46e exits at the step-1
#        re-read and never reaches it, and the suite was 71/71 green with the
#        `mv` reverted to `rm -rf; mkdir`. Includes a hard "window armed on
#        both racers" assertion: the sleep counter must be keyed on an env var,
#        because command substitution forks a fresh subshell per read and a
#        $PPID-keyed counter silently never arms.
#    46g. a holder this user cannot SIGNAL (pid 1, EPERM) counts as alive and
#        its lock is refused intact (review F2). Reports itself not-applicable,
#        never green, where the EPERM asymmetry does not exist (root, or a
#        container whose pid 1 belongs to this uid).
#    47. the lock is genuinely TAKEN during a run (without this, every
#        "released" assertion below passes vacuously against no guard at all)
#    48. a SIGTERMed run releases its lock — no wedge
#   init failure diagnosis (verify.sh section 3 failure branch):
#    49. an init that fails with the provider-cache signature → exit !=0 AND
#        verify.sh reproduces what tofu said AND names BOTH mechanisms: a cold
#        cache (which nothing here fixes) and a concurrent writer (which the
#        lock covers). The branch printed nothing but "init failed" before.
#
# It NEVER mutates the tracked fixture or decks; all edits happen in the temp copy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FIXTURE_MD="labs/fixtures/drift-demo.md"
FIXTURE_TF="labs/fixtures/drift-demo/main.tf"
# Temp-only pages fixture (not tracked): proves section 6 also scans pages/**
# and tolerates magic-move fence metadata. Points at the same drift-demo .tf.
PAGES_FIXTURE_MD="pages/S99-drift-selftest/index.md"
# Temp-only templates-deck annotation (TEST-A4): proves section 6 scans
# slides-templates.md and tolerates magic-move fence metadata on that root deck.
TEMPLATES_SELFTEST_TF="labs/fixtures/templates-demo/selftest.tf"

pass_n=0
fail_n=0
note() { printf '  [selftest] %s\n' "$*"; }
ok()   { printf '  [ OK ] %s\n' "$*"; pass_n=$((pass_n + 1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; fail_n=$((fail_n + 1)); }

# --- temp lifetime (US-F-GATEHYG) --------------------------------------------
#
# THE BUG THIS REPLACES: run_case used to do
#
#     tmp="$(mktemp -d)"
#     trap 'rm -rf "$tmp"' RETURN
#     ...
#     trap - RETURN          # <-- disarms the trap BEFORE the function returns
#
# so the RETURN trap was cleared while it was still the only thing that would
# ever have fired, and NOTHING removed the tree. Every case leaks a full repo
# copy: ~46 cases per run, each a few MB with provider caches, and the dev host
# had accumulated thousands. CI runners have finite disk; this is how they fill.
#
# The replacement is two layers, deliberately:
#   1. run_case removes its own tree explicitly, past the verdict, on BOTH the
#      pass and the fail path (one `rm -rf`, hoisted like the dump call is, so
#      "revert one branch" is not a representable mutation).
#   2. every case tree is a CHILD of one script-level root that an EXIT/INT/TERM
#      trap removes, so an early `set -e` death or a Ctrl-C still cleans up.
# Layer 2 alone would be enough for the disk, but not for the invariant: the
# sweep check at the end of this script asserts layer 1 actually ran, so
# deleting it turns this self-test red instead of silently relying on layer 2.
SELFTEST_TMP_ROOT="$(mktemp -d)"
selftest_cleanup() {
  [ -n "${SELFTEST_TMP_ROOT:-}" ] && rm -rf "$SELFTEST_TMP_ROOT"
  return 0
}
# EXIT covers normal exit and every `set -e` death. On GNU bash it also covers
# an untrapped SIGINT/SIGTERM — the fatal-signal handler runs the exit trap
# before re-raising, measured on 5.3.15 — so the INT/TERM handlers below are
# belt-and-braces for shells that do not, not the primary mechanism. They
# re-raise with the default disposition so "killed by signal" still reaches the
# caller instead of being swallowed into a plain exit status.
selftest_rc=0
trap 'selftest_rc=$?; selftest_cleanup; exit "$selftest_rc"' EXIT
trap 'selftest_cleanup; trap - INT;  kill -INT  $$' INT
trap 'selftest_cleanup; trap - TERM; kill -TERM $$' TERM

# Ledger of every temp root run_case created, and of any case that left a
# verify.sh lock behind. Files, not shell arrays: check_run_case_wiring drives
# run_case inside a command substitution, and a subshell cannot write back to a
# parent variable — the wiring probe is precisely the FAIL-path case whose
# cleanup we most need to observe.
RUN_CASE_TMP_TRACE="$SELFTEST_TMP_ROOT/case-tmp-roots.txt"
# G6: the lock scenarios get their OWN ledger. Sharing one with run_case made
# the "no roots recorded -> DISARMED" guard below unreachable: the lock
# sandboxes kept the total at 4 or more, so deleting run_case's ledger append
# produced "all 4 case temp root(s) removed, 0 leaked" — a confident green over
# 49 unswept roots. Two ledgers, each with its own floor, means either append
# can be deleted and something goes red.
LOCK_SANDBOX_TMP_TRACE="$SELFTEST_TMP_ROOT/lock-sandbox-roots.txt"
RUN_CASE_LOCK_TRACE="$SELFTEST_TMP_ROOT/case-lock-leaks.txt"
: >"$RUN_CASE_TMP_TRACE"
: >"$LOCK_SANDBOX_TMP_TRACE"
: >"$RUN_CASE_LOCK_TRACE"

command -v tofu >/dev/null 2>&1 || { echo "selftest: tofu required" >&2; exit 1; }

printf '\n### verify.sh enforcement self-test (drift + tier + README navigation) ###\n'

# Plant a pages/** annotated HCL block with a magic-move fence. Body must stay
# byte-identical to FIXTURE_TF (minus trailing newline handling in verify.sh).
plant_pages_fixture() {
  local root="$1"
  mkdir -p "$(dirname "$root/$PAGES_FIXTURE_MD")"
  {
    printf '%s\n' '# Temp pages drift fixture (self-test only)'
    printf '%s\n' ''
    printf '%s\n' "<!-- source: $FIXTURE_TF -->"
    # Magic-move metadata MUST be tolerated on the fence line (US-X-DRIFT2).
    printf '%s\n' '```hcl {none|1-3|all}'
    # FIXTURE_TF already ends with a trailing newline — do not add another.
    cat "$root/$FIXTURE_TF"
    printf '%s\n' '```'
  } >"$root/$PAGES_FIXTURE_MD"
}

# Append an annotated HCL block to the copied templates deck. Body must stay
# byte-identical to TEMPLATES_SELFTEST_TF (sandbox-only; not a tracked product file).
plant_templates_fixture() {
  local root="$1"
  mkdir -p "$(dirname "$root/$TEMPLATES_SELFTEST_TF")"
  cat >"$root/$TEMPLATES_SELFTEST_TF" <<'EOF'
# labs/fixtures/templates-demo/selftest.tf — sandbox-only drift marker (TEST-A4).
locals {
  templates_drift_selftest = "armed"
}
EOF
  {
    printf '\n'
    printf '%s\n' "<!-- source: $TEMPLATES_SELFTEST_TF -->"
    # Magic-move metadata MUST be tolerated on the root deck too (TEST-A4).
    printf '%s\n' '```hcl {none|1-3|all}'
    cat "$root/$TEMPLATES_SELFTEST_TF"
    printf '%s\n' '```'
  } >>"$root/slides-templates.md"
}

# Build an isolated temp repo root with only what verify.sh needs. Includes the
# two content decks so section 7 (tier consistency) has inputs; verify.sh reads
# them by literal path relative to REPO_ROOT.
build_root() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/setup" "$root/labs/fixtures/drift-demo" \
    "$root/labs/fixtures/templates-demo" \
    "$root/labs/day-1" "$root/labs/day-2/13-static-analysis/messy" \
    "$root/docs/decisions" "$root/pages/S99-drift-selftest"
  cp "$REPO_ROOT/scripts/verify.sh" "$root/scripts/verify.sh"
  cp "$REPO_ROOT/scripts/deck-manifest.mjs" "$root/scripts/deck-manifest.mjs"
  cp "$REPO_ROOT/scripts/generate-decks.mjs" "$root/scripts/generate-decks.mjs"
  cp "$REPO_ROOT/setup/lib.sh"      "$root/setup/lib.sh"
  cp "$REPO_ROOT/setup/bootstrap.sh" "$root/setup/bootstrap.sh"
  cp "$REPO_ROOT/$FIXTURE_MD"       "$root/$FIXTURE_MD"
  cp "$REPO_ROOT/$FIXTURE_TF"       "$root/$FIXTURE_TF"
  # Product templates-demo fixtures (TEST-A4 annotations in slides-templates.md).
  if [ -d "$REPO_ROOT/labs/fixtures/templates-demo" ]; then
    cp "$REPO_ROOT"/labs/fixtures/templates-demo/*.tf \
      "$root/labs/fixtures/templates-demo/" 2>/dev/null || true
  fi
  cp "$REPO_ROOT/slides.md"         "$root/slides.md"
  cp "$REPO_ROOT/slides-3day.md"    "$root/slides-3day.md"
  cp "$REPO_ROOT/slides-templates.md" "$root/slides-templates.md"
  cp "$REPO_ROOT/README.md"         "$root/README.md"
  cp "$REPO_ROOT/AGENT.md"          "$root/AGENT.md"
  cp "$REPO_ROOT/Taskfile.yaml"     "$root/Taskfile.yaml"
  cp "$REPO_ROOT/versions.env"      "$root/versions.env"
  cp "$REPO_ROOT/docker-compose.yml" "$root/docker-compose.yml"
  mkdir -p "$root/.github/workflows"
  cp "$REPO_ROOT/.github/workflows/ci.yml" "$root/.github/workflows/ci.yml"
  mkdir -p "$root/setup/terratest"
  cp "$REPO_ROOT/setup/terratest/Dockerfile" "$root/setup/terratest/Dockerfile"
  cp "$REPO_ROOT/scripts/lab-terratest.sh" "$root/scripts/lab-terratest.sh"
  # Lab 00 markdown is needed by the README-navigation route check and by the §5
  # smoke-check mutators, which append to it. Its two annotated ```hcl blocks are
  # DISARMED on the way in, and labs/day-1/00-setup/{hello,bucket}.tf are
  # deliberately NOT copied: since US-C-GATE, verify.sh validates every
  # labs/day-1/** workdir that holds .tf, and those two files pull the real aws
  # provider — a ~9s `tofu init` in EVERY case here (measured, and a warm
  # TF_PLUGIN_CACHE_DIR does not help: tofu copies the ~600MB provider rather
  # than linking it), i.e. minutes added to a sub-minute self-test. Nothing is
  # lost: the drift gate's dedicated fixture is labs/fixtures/drift-demo, and the
  # day-1/day-3 validate loop has its own provider-free cases below
  # (m_lab_validate_day1_* / m_lab_validate_day3_*). Do NOT re-add those .tf.
  sed 's/<!-- source: labs\/day-1\/00-setup\//<!-- source-disarmed: labs\/day-1\/00-setup\//' \
    "$REPO_ROOT/labs/day-1/00-setup.md" >"$root/labs/day-1/00-setup.md"
  cp "$REPO_ROOT/labs/day-2/13-static-analysis/messy/main.tf" \
    "$root/labs/day-2/13-static-analysis/messy/main.tf"
  cp "$REPO_ROOT/setup/localstack.md" "$root/setup/localstack.md"
  cp "$REPO_ROOT/docs/decisions/README.md" "$root/docs/decisions/README.md"
  # Section 11 (US-D-VERSION-FLOOR) needle-checks these floor consumers, and a
  # missing consumer file is a FAILURE by design — so the temp root must carry
  # them. The S00 page's annotated fence is DISARMED on the way in for the same
  # reason as 00-setup.md above: its source workdir is deliberately not copied.
  cp "$REPO_ROOT/docs/setup.md" "$root/docs/setup.md"
  cp "$REPO_ROOT/docs/validation-matrix.md" "$root/docs/validation-matrix.md"
  mkdir -p "$root/pages/S00-welcome" "$root/pages/S19-testing-cicd"
  sed 's/<!-- source: /<!-- source-disarmed: /' \
    "$REPO_ROOT/pages/S00-welcome/index.md" >"$root/pages/S00-welcome/index.md"
  sed 's/<!-- source: /<!-- source-disarmed: /' \
    "$REPO_ROOT/pages/S19-testing-cicd/index.md" >"$root/pages/S19-testing-cicd/index.md"
  plant_pages_fixture "$root"
  plant_templates_fixture "$root"
  mkdir -p "$root/test-bin"
  for tool in tflint trivy checkov conftest terramate; do
    printf '#!/bin/sh\nexit 127\n' >"$root/test-bin/$tool"
    chmod +x "$root/test-bin/$tool"
  done
}

# Substring test with NO subprocess and NO pipe.
#
# The obvious spelling — `printf '%s' "$out" | grep -qF -- "$needle"` — is a
# false-NEGATIVE generator under `set -o pipefail` (line 86): `grep -q` exits
# the instant it finds a match, closing the pipe; if the payload is larger than
# the pipe capacity the upstream `printf` is still writing and takes SIGPIPE, so
# the pipeline reports 141 for a needle that IS present. The earlier the needle,
# the likelier it fires — which makes it a flake, not a clean failure.
#
# Measured, needle present in every case (100 KB payload):
#     macOS  needle at line 1   -> pipeline rc 141   <- WRONG, needle is there
#     macOS  needle at line 250 -> pipeline rc 0
#     GitHub runner              -> hit the elision marker in a 400+ line dump,
#                                   reporting it "missing" while it was printed
#
# Bash's own pattern matching does the comparison in-process: no fork, no pipe,
# nothing to SIGPIPE, and it is faster besides.
has_text() {
  case "$1" in
    *"$2"*) return 0 ;;
    *)      return 1 ;;
  esac
}

# Dump everything a failing case produced.
#
# WHY THE WHOLE THING: this used to be
#   printf '%s' "$out" | grep -E 'drift|annotated|pin drift|Formatting'
# — a filter tuned to the drift cases. When verify.sh failed for any OTHER
# reason (or died early under `set -euo pipefail`, printing nothing that
# matched), a failing case reported its verdict with ZERO evidence. That
# blindness has a measured cost: a CI-only self-test failure on 2026-08-19 was
# diagnosed from the case LABEL alone, called deterministic on two attempts that
# had in fact failed on two DIFFERENT cases, and the lane was reverted without
# anyone seeing why. A self-test that can fail without saying why is not a gate,
# it is a coin flip with a log line.
#
# Bounded so a runaway verify.sh cannot flood a CI log: full output up to
# DUMP_MAX_LINES, otherwise head+tail around an explicit elision marker (the
# summary at the tail and the section headings at the head are both load-bearing).
#
# The cap is DERIVED, never written twice: head+tail must tile the budget
# exactly, or the elided count goes negative and the two halves silently
# overlap-duplicate.
DUMP_HEAD_LINES=120
DUMP_TAIL_LINES=280
DUMP_MAX_LINES=$((DUMP_HEAD_LINES + DUMP_TAIL_LINES))

dump_case_output() {
  local out="$1" n=0
  # Command substitution strips trailing newlines, so `printf '%s\n'` re-adds
  # exactly the one that was removed. Empty output is 0 lines, not the 1 that
  # `printf '%s\n' "" | wc -l` reports — the header must not contradict the
  # "(no output at all)" line directly beneath it.
  [ -n "$out" ] && n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  printf '        ---- verify.sh output (%s line(s)) ----\n' "$n"
  if [ -z "$out" ]; then
    printf '        | (no output at all — verify.sh produced nothing on stdout or stderr)\n'
  elif [ "$n" -le "$DUMP_MAX_LINES" ]; then
    printf '%s\n' "$out" | sed 's/^/        | /'
  else
    # `sed -n 1,Np`, NOT `head -n N`. This script runs under `set -euo pipefail`
    # (line 86): `head` closes the pipe as soon as it has its N lines, the
    # upstream `printf` takes SIGPIPE, `pipefail` surfaces 141 and `set -e`
    # kills the WHOLE self-test — losing the elision marker, the tail, the end
    # marker, every remaining case and the final summary. That is strictly
    # worse than the narrow grep this dump replaced, and it is the exact
    # evidence-free failure this dump exists to abolish.
    #
    # It only fires above BOTH thresholds — more than DUMP_MAX_LINES lines and
    # more than the pipe capacity (64 KiB on Linux). macOS buffers more and
    # stays green, so the local gate matrix could not have caught it; it was
    # found by independent review and confirmed in a Linux container (rc=141).
    # `sed -n` consumes stdin to EOF, so there is no early close to race.
    printf '%s\n' "$out" | sed -n "1,${DUMP_HEAD_LINES}p" | sed 's/^/        | /'
    printf '        | ... %s line(s) elided ...\n' "$((n - DUMP_HEAD_LINES - DUMP_TAIL_LINES))"
    printf '%s\n' "$out" | tail -n "$DUMP_TAIL_LINES" | sed 's/^/        | /'
  fi
  printf '        ---- end of verify.sh output ----\n'
}

# The dump is gate code, and gate code that nothing exercises rots silently.
# NONE of the run_case cases below reach dump_case_output on a green run — a
# self-test whose every case passes never enters the failure branch — so these
# three direct checks are the only coverage it has. Their absence is how the
# `head` SIGPIPE above shipped past three green local gate runs.
#
# Case (c) is the regression pin and MUST exceed BOTH thresholds (line count and
# pipe capacity); shrink it and it stops testing the thing that broke.
dump_big_payload() {
  local pad i
  pad="$(printf 'x%.0s' $(seq 1 200))"
  for i in $(seq 1 $((DUMP_MAX_LINES + 100))); do printf '%s %s\n' "$i" "$pad"; done
}

# check_dump <label> <payload> [needle...] — the dump must exit 0 and always
# terminate with its closing marker, whatever it was handed.
check_dump() {
  local label="$1" payload="$2"
  shift 2
  local out rc missing=""
  # `set -euo pipefail` INSIDE the substitution, not merely inherited: `set +e`
  # in the caller propagates into the subshell and would disable the very
  # errexit that turns a SIGPIPE into a visible failure — a check that can only
  # ever pass. (Confirmed: without this, the pre-fix `head` form scored rc=0 on
  # Linux; with it, rc=141 and no closing marker.) The outer `set +e` exists
  # only so a non-zero rc can be CAPTURED here instead of killing the run.
  set +e
  out="$(set -euo pipefail; dump_case_output "$payload" 2>&1)"
  rc=$?
  set -e
  local needle
  # Accumulate EVERY missing needle. Keeping only the last one hides how badly
  # a dump is broken — "missing the end marker" and "missing the end marker AND
  # the elision marker" are different diagnoses.
  for needle in '---- end of verify.sh output ----' "$@"; do
    has_text "$out" "$needle" || missing="${missing:+$missing, }'$needle'"
  done
  if [ "$rc" -eq 0 ] && [ -z "$missing" ]; then
    ok "dump self-check: $label — exit 0 and output terminated cleanly"
  else
    bad "dump self-check: $label — expected exit 0 + closing marker; got exit $rc${missing:+, missing $missing}"
    printf '%s\n' "$out" | tail -n 5 | sed 's/^/        | /'
  fi
}

check_dump "empty output" "" '(no output at all' '(0 line(s))'
check_dump "short output" "$(printf 'alpha\nbeta\ngamma')" '| gamma' '(3 line(s))'
# R3: the payload's BYTE size is a load-bearing half of this pin and nothing
# enforced it. dump_big_payload scales with DUMP_MAX_LINES only, so shrinking the
# constants drops it under the pipe capacity — at which point the broken `head`
# form PASSES while the label still advertises ">64 KiB". A regression pin that
# can silently disarm while still claiming to be armed is worse than no pin.
DUMP_FLOOD_PAYLOAD="$(dump_big_payload)"
if [ "${#DUMP_FLOOD_PAYLOAD}" -gt 65536 ]; then
  ok "dump self-check: flood payload still exceeds the 64 KiB pipe capacity (${#DUMP_FLOOD_PAYLOAD} bytes)"
else
  bad "dump self-check: flood payload is ${#DUMP_FLOOD_PAYLOAD} bytes — below the 64 KiB pipe capacity, so the SIGPIPE regression pin is DISARMED"
fi
# R2: '| 1 x' is the FIRST payload line and can only come from the head half —
# the tail starts at line 221, and no other line contains "| 1 x" ("| 100 x"
# breaks the match at the character after the 1). Without it the check asserted
# only the elision marker and tail content, so deleting the head emission
# outright left it green: "delete the feature, the test must fail" did not hold.
check_dump "flood: >${DUMP_MAX_LINES} lines and >64 KiB" "$DUMP_FLOOD_PAYLOAD" 'line(s) elided' '| 1 x' "$((DUMP_MAX_LINES + 100)) x"

# run_case <label> <expect: pass|fail> <needle> <mutator-fn> [also-needle]
#
# Any arguments AFTER the mutator are additional literals that must ALSO appear
# in the output. They exist so a case can pin down WHICH code path produced the
# result, not just the verdict: the git-mode cases below use one to assert
# verify.sh actually selected the `git ls-files` scan. Without it, a regression
# that silently routed git mode to the `find` fallback would leave every case
# green. Variadic because pinning a third thing must not cost you the second.
run_case() {
  local label="$1" expect="$2" needle="$3" mutate="$4"
  shift 4
  # Every remaining argument is an ADDITIONAL required needle. Previously this
  # was a single optional `also`, which forced a case wanting to pin three
  # things to choose two — and re-purposing `also` off its current literal would
  # silently drop whatever it already pinned.
  local extra=("$@")
  local tmp out rc extra_ok=1 needle_ok=0 verdict_ok=0 missing_extra=""
  # Child of the script-level root so an early death still gets collected, and
  # recorded in the ledger so the sweep at the end of this script can prove the
  # explicit removal below actually ran.
  tmp="$(mktemp -d "$SELFTEST_TMP_ROOT/case.XXXXXXXX")"
  printf '%s\n' "$tmp" >>"$RUN_CASE_TMP_TRACE"
  build_root "$tmp"
  "$mutate" "$tmp"
  set +e
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e

  local e
  for e in ${extra[@]+"${extra[@]}"}; do
    if ! has_text "$out" "$e"; then
      extra_ok=0
      missing_extra="${missing_extra:+$missing_extra, }'$e'"
    fi
  done
  has_text "$out" "$needle" && needle_ok=1

  if [ "$expect" = "pass" ]; then
    if [ "$rc" -eq 0 ] && [ "$extra_ok" -eq 1 ] && [ "$needle_ok" -eq 1 ]; then
      ok "$label — exit 0 and enforcement armed ('$needle')"
      verdict_ok=1
    else
      bad "$label — expected exit 0 + '$needle'${missing_extra:+ + $missing_extra}; got exit $rc"
    fi
  else
    if [ "$rc" -ne 0 ] && [ "$extra_ok" -eq 1 ] && [ "$needle_ok" -eq 1 ]; then
      ok "$label — exit $rc (non-zero) and drift named ('$needle')"
      verdict_ok=1
    else
      bad "$label — expected non-zero + '$needle'${missing_extra:+ + $missing_extra}; got exit $rc"
    fi
  fi
  # ONE call site, deliberately. With a dump call inside each failure branch,
  # reverting just ONE of them left the whole self-test green — including the
  # wiring check, which only ever drives the `expect=pass` branch. The uncovered
  # branch was the `expect=fail` one, which fires for the majority of cases and
  # would have fired on the CI failure that cost the revert. Hoisting past the
  # verdict makes that mutation unrepresentable rather than merely tested for.
  [ "$verdict_ok" -eq 1 ] || dump_case_output "$out"
  # A verify.sh that exits without releasing its lock wedges every future run in
  # that checkout. Record it here rather than failing the case: the sweep below
  # reports the total, so ONE misleading case message cannot be mistaken for a
  # drift/tier regression.
  # G7: `if`, not `[ … ] && …`. As an && list this returns 1 on the normal path
  # (no lock left behind), and the only thing keeping that off run_case's exit
  # status is the `rm -rf` that follows. Delete that line and run_case returns 1,
  # `set -e` kills the self-test mid-run, and it dies with no summary at all —
  # this repo's signature false-red, caused by the cleanup fix itself.
  if [ -d "$tmp/.verify.lock" ]; then
    printf '%s\n' "$tmp" >>"$RUN_CASE_LOCK_TRACE"
  fi
  # Hoisted past the verdict, exactly like the dump call above: with a copy in
  # each branch, reverting only the fail-path one would leak on every red case
  # while the self-test stayed green.
  rm -rf "$tmp"
}

# Heading literals that identify which scan path section 2 selected.
GIT_SCAN_HEADING='git-tracked .tf, S13 messy fixture excluded'
FIND_SCAN_HEADING='no git index — filesystem walk'
# Section 3-4 heading literal — names the validate scope, so a case can assert
# that day-1/day-3 discovery is the path that produced its verdict (US-C-GATE).
VALIDATE_SCOPE_HEADING='Validate & test (modules · examples · labs/day-1 · labs/day-2 · labs/day-3)'

# --- mutators (operate on the temp copy only) --------------------------------
m_clean() { :; }   # leave the copy pristine → block matches source

m_pin_clean() { :; }

m_pin_drift() {
  local root="$1" current
  current="$(grep -E '^ARG TOFU_VERSION=' "$root/setup/terratest/Dockerfile" | head -1 | sed 's/^ARG TOFU_VERSION=//')"
  [ -n "$current" ] || { echo "selftest: missing ARG TOFU_VERSION in Dockerfile" >&2; return 1; }
  perl -pi -e "s/^ARG TOFU_VERSION=\Q${current}\E/ARG TOFU_VERSION=9.9.9/" \
    "$root/setup/terratest/Dockerfile"
}

m_pin_compose_drift() {
  local root="$1"
  perl -pi -e 's/localstack\/localstack:\$\{LOCALSTACK_VERSION\}/localstack\/localstack:9.9.9/' \
    "$root/docker-compose.yml"
}

m_pin_ci_drift() {
  local root="$1" tofu_pin
  # shellcheck source=versions.env disable=SC1091
  . "$root/versions.env"
  tofu_pin="$TOFU_VERSION"
  perl -pi -e "s/tofu_version: \"\Q${tofu_pin}\E\"/tofu_version: \"9.9.9\"/" \
    "$root/.github/workflows/ci.yml"
}

# --- version-floor skew (US-D-VERSION-FLOOR / verify.sh section 11) ---------

m_floor_clean() { :; }

m_floor_bootstrap_skew() { # MIN_TOFU no longer states TOFU_FLOOR → needle red
  local root="$1"
  perl -pi -e 's/^MIN_TOFU="[0-9.]+"/MIN_TOFU="1.7"/' "$root/setup/bootstrap.sh"
}

m_floor_ceiling() { # a lab artifact demanding more than the floor → scan red
  local root="$1"
  # A Terramate global, not a .tf file, so section 3's validate sweep (which
  # inits every lab dir holding .tf) stays out of the blast radius and the
  # red provably comes from the section-11 ceiling scan.
  mkdir -p "$root/labs/day-1/floor-ceiling-selftest"
  printf 'globals {\n  terraform_version      = ">= 99.0"\n}\n' \
    >"$root/labs/day-1/floor-ceiling-selftest/globals.tm.hcl"
}

m_drift_lf() {     # change the source only → block no longer matches
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_LF/' "$root/$FIXTURE_TF"
}

m_drift_crlf() {   # drift the source AND author the .md as CRLF (F1 regression)
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_CRLF/' "$root/$FIXTURE_TF"
  perl -pi -e 's/\n/\r\n/' "$root/$FIXTURE_MD"
}

m_pages_clean() { :; }   # pages fixture already planted matching + magic-move fence

m_pages_drift_lf() {     # drift ONLY the pages block body — labs fixture stays clean
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_PAGES_LF/' "$root/$PAGES_FIXTURE_MD"
}

m_pages_drift_crlf() {   # pages body drift + CRLF-authored pages md (F1 on pages/)
  local root="$1"
  perl -pi -e 's/hello, opentofu/DRIFTED_PAGES_CRLF/' "$root/$PAGES_FIXTURE_MD"
  perl -pi -e 's/\n/\r\n/' "$root/$PAGES_FIXTURE_MD"
}

m_templates_clean() { :; }   # templates selftest block already planted matching

m_templates_drift_lf() {     # drift ONLY the templates-deck planted block body
  local root="$1"
  perl -pi -e 's/templates_drift_selftest = "armed"/templates_drift_selftest = "DRIFTED_TEMPLATES_LF"/' \
    "$root/slides-templates.md"
}

m_tier_mismatch() {  # section 7 (a): make S05's tier differ between the two decks
  local root="$1"    # mutate the SUPERSET deck only → deck↔deck identity breaks
  perl -pi -e 's/^# S05 · State encryption · core · Day 1$/# S05 · State encryption · recommended · Day 1/' \
    "$root/slides.md"
}

m_hide_violation() { # section 7 (b): optional section left visible in the 3-day cut
  local root="$1"    # S18 is optional → its hide flag must be true; force false
  perl -0pi -e 's/(# S18 · [^\n]*\n(?:src:[^\n]*\n)?hide: )true/${1}false/' \
    "$root/slides-3day.md"
}

m_missing_lab_route() {
  local root="$1"
  rm "$root/labs/day-1/00-setup.md"
}

m_unknown_readme_task() {
  local root="$1"
  perl -pi -e 's/task dev:3day/task dev:ghost/' "$root/README.md"
}

m_unformatted_outside_allowlist() {
  local root="$1"
  mkdir -p "$root/modules/unformatted-regression"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/modules/unformatted-regression/main.tf"
}

m_unformatted_beside_fixture() {
  local root="$1"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/labs/day-2/13-static-analysis/messy/adjacent.tf"
}

# Plant deliberately unformatted .tf under paths that must NOT poison fmt -check
# (agent worktrees, package installs, provider caches).
m_unformatted_under_claude_worktree() {
  local root="$1"
  mkdir -p "$root/.claude/worktrees/fake-lane/labs/day-2/13-static-analysis/messy"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/.claude/worktrees/fake-lane/labs/day-2/13-static-analysis/messy/main.tf"
}

m_unformatted_under_node_modules() {
  local root="$1"
  mkdir -p "$root/node_modules/some-pkg"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/node_modules/some-pkg/main.tf"
}

m_unformatted_under_dot_terraform() {
  local root="$1"
  mkdir -p "$root/modules/example/.terraform/providers"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/modules/example/.terraform/providers/cached.tf"
}

# US-F-VERIFY-WT: sibling git worktrees are commonly checked out at
# .worktrees/<lane>/ under the repo root. Each carries its own copy of the whole
# tree — including the deliberately-unformatted S13 fixture — so a filesystem
# walk false-reds a clean tree with another lane's fixture. Exercises the
# FIND fallback path (the temp root below is not a git work tree).
m_unformatted_under_worktrees() {
  local root="$1"
  mkdir -p "$root/.worktrees/fake-lane/labs/day-2/13-static-analysis/messy"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/.worktrees/fake-lane/labs/day-2/13-static-analysis/messy/main.tf"
}

# --- git-mode coverage (US-F-VERIFY-WT) --------------------------------------
# Every case above runs in a plain `mktemp -d`, which is NOT a git work tree, so
# they all exercise verify.sh's `find` FALLBACK. The primary path — `git ls-files`
# — would otherwise ship with zero coverage, and its failure mode is the nasty
# one: an empty file list makes the gate report a green "canonically formatted"
# while checking nothing. These two cases `git init` the temp root so the primary
# path is selected, then prove it is BOTH worktree-safe AND still armed.
#
# `git ls-files` reads the index, so `git add -A` suffices — no commit, and no
# user.name/user.email config required.
git_init_root() {
  local root="$1"
  # -f is load-bearing: `git add` honours the developer's global core.excludesFile,
  # and build_root never plants a .gitignore here. Without it, someone with e.g.
  # `modules/` globally excluded would leave the planted file untracked, and the
  # "tracked unformatted file still armed" case would go GREEN when it must go
  # red — silently disarming the very case that proves git mode is armed.
  ( cd "$root" && git init -q . && git add -A -f ) >/dev/null 2>&1
}

# git mode: an untracked sibling worktree is structurally invisible to the scan.
m_git_mode_worktree_ignored() {
  local root="$1"
  git_init_root "$root"
  mkdir -p "$root/.worktrees/fake-lane/labs/day-2/13-static-analysis/messy"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/.worktrees/fake-lane/labs/day-2/13-static-analysis/messy/main.tf"
}

# git mode ARMED: a TRACKED unformatted file must still red the gate. This is the
# case that catches a `git ls-files` that silently returns nothing.
m_git_mode_tracked_unformatted() {
  local root="$1"
  mkdir -p "$root/modules/unformatted-regression"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/modules/unformatted-regression/main.tf"
  git_init_root "$root"
}

# git mode selected but git REFUSES: a .git entry exists, so the git branch is
# taken, yet `git ls-files` exits 128. Reachable in the wild via a stale linked
# worktree whose gitdir was pruned, safe.directory/dubious-ownership (containers,
# volume-mounted checkouts), or a corrupt index.
#
# The danger is specific to the git path and strictly worse than the false-RED
# this story removes: process substitution swallows the exit status, so an empty
# file list would sail into the `[ ${#FORMAT_FILES[@]} -eq 0 ] || …` short-circuit
# and print a green "canonically formatted" over an unchecked tree. `find` can
# never fail this way. Plant an unformatted file too, so a green here is provably
# wrong rather than vacuously true.
m_git_mode_scan_broken() {
  local root="$1"
  mkdir -p "$root/modules/unformatted-regression"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/modules/unformatted-regression/main.tf"
  printf 'gitdir: /nonexistent/gitdir\n' >"$root/.git"
}

# REVIEW F1: `git ls-files` can also fail SOFTLY — exit 0 with EMPTY output. The
# rc guard does not see that, so the empty list sails into the
# `[ ${#FORMAT_FILES[@]} -eq 0 ] ||` short-circuit and prints a green tick over a
# tree that was never scanned. Reproduced three ways, all rc 0 and 0 bytes: a
# deleted .git/index, a fresh init with nothing staged, and GIT_INDEX_FILE
# pointing at a nonexistent index (hook-like environments).
#
# No existing case can reach this state: m_git_mode_tracked_unformatted plants
# its file INTO the index, so the list is never empty there.
m_git_mode_empty_index() {
  local root="$1"
  mkdir -p "$root/modules/unformatted-regression"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/modules/unformatted-regression/main.tf"
  git_init_root "$root"
  rm -f "$root/.git/index"
}

# REVIEW F3: every case above runs in a bare mktemp -d, so the S13 allowlist has
# only ever been exercised on the FIND path, which compares './'-prefixed paths.
# The git path compares ROOT-RELATIVE paths with no './' prefix — one character
# away from a silent hole, and until now proven only by the real repo passing.
# Pin both directions on the git path.
m_git_mode_s13_only() {
  local root="$1"   # build_root already ships the unformatted S13 fixture
  git_init_root "$root"
}

m_git_mode_adjacent_s13() {
  local root="$1"
  printf 'terraform {\n required_version = ">= 1.8"\n}\n' \
    >"$root/labs/day-2/13-static-analysis/messy/adjacent.tf"
  git_init_root "$root"
}

# REVIEW F2: a tracked path absent from the worktree (sparse-checkout,
# skip-worktree, staged mass deletion) is silently dropped by the `[ -f ]` skip.
# If ALL of them vanish the run collapses into the same green while claiming every
# tracked file was checked — and the F1 fix does NOT subsume it, because the raw
# git output is non-empty here. Must WARN rather than hard-fail: hard-failing a
# legitimately staged-deleted file would manufacture exactly the false-red this
# lane exists to remove.
m_git_mode_absent_tracked() {
  local root="$1"
  mkdir -p "$root/modules/absent-regression"
  printf 'terraform {\n  required_version = ">= 1.8"\n}\n' \
    >"$root/modules/absent-regression/main.tf"
  git_init_root "$root"
  rm -f "$root/modules/absent-regression/main.tf"
}

# Minimal provider-free day-2 lab with a plan-only unit suite — proves CODE_DIRS
# discovery includes labs/day-2/** that ship *.tftest.hcl (TEST-A2).
LAB_TFTTEST_DIR="labs/day-2/99-lab-tftest-selftest"
plant_lab_unit_tftest() {
  local root="$1"
  mkdir -p "$root/$LAB_TFTTEST_DIR/tests"
  cat >"$root/$LAB_TFTTEST_DIR/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.8"
}

locals {
  marker = "lab-unit-ok"
}

output "marker" {
  value = local.marker
}
EOF
  cat >"$root/$LAB_TFTTEST_DIR/tests/unit.tftest.hcl" <<'EOF'
run "lab_unit_plan" {
  command = plan

  assert {
    condition     = output.marker == "lab-unit-ok"
    error_message = "expected lab-unit-ok"
  }
}
EOF
}

m_lab_tftest_clean() {
  plant_lab_unit_tftest "$1"
}

m_lab_tftest_fail() {
  local root="$1"
  plant_lab_unit_tftest "$root"
  perl -pi -e 's/lab-unit-ok/lab-unit-BROKEN/' \
    "$root/$LAB_TFTTEST_DIR/tests/unit.tftest.hcl"
}

# Preflight: a FAILING toolchain probe must be named and the run must continue
# to its summary — never a silent death.
#
# THE HOLE THIS CLOSES: `tofu version` used to be piped through `2>/dev/null |
# head -n1 | awk`, so under `set -euo pipefail` a non-zero probe (or a SIGPIPE
# from `head` closing the pipe) killed verify.sh as a bare assignment failure,
# immediately after the "Preflight" heading. CI produced exactly that on
# 2026-08-19 (job 96001788290): four lines of output, exit 1, no message. With
# nothing to read it was misdiagnosed as a flake in an unrelated lane, and that
# lane was reverted for a defect it did not have.
#
# The stub lands in test-bin/, which run_case puts FIRST on PATH, so `have tofu`
# still succeeds and only the probe fails — the exact shape of the CI failure.
# A HEALTHY tofu whose stderr is noisy must still parse. Proxy notices, TF_LOG
# and dyld messages all land on stderr before the version line; if the probe
# merges the streams and parses line 1, `$2` is a word out of the WARNING,
# min_version strips it to empty, and a perfectly good toolchain reds the gate.
# That would be a fresh spurious-red path opened by the fix that closed one.
m_tofu_version_stderr_noise() {
  local root="$1" real
  # Resolve the REAL tofu now and bake it in: the stub sits first on PATH, so
  # every later `tofu fmt/init/validate` in the run would otherwise hit the stub
  # too. Only `version` is intercepted; everything else is delegated untouched,
  # so this case exercises the parser without disturbing any other section.
  # The pinned v1.10.3 is the STUB's answer, deliberately independent of the
  # host's real version — the assertion is "stdout was parsed", not "this host
  # runs 1.10.3".
  real="$(command -v tofu)"
  cat >"$root/test-bin/tofu" <<STUB
#!/bin/sh
if [ "\$1" = "version" ]; then
  echo "Warning: a noisy stderr line that must NOT be parsed as the version" >&2
  echo "OpenTofu v1.10.3"
  echo "on linux_amd64"
  exit 0
fi
exec "$real" "\$@"
STUB
  chmod +x "$root/test-bin/tofu"
}

m_tofu_version_probe_fails() {
  local root="$1"
  cat >"$root/test-bin/tofu" <<'STUB'
#!/bin/sh
echo "tofu: simulated toolchain probe failure (self-test)" >&2
exit 1
STUB
  chmod +x "$root/test-bin/tofu"
}

# Day-1/Day-3 lab workdir validation (US-C-GATE / section 3 CODE_DIRS).
#
# The hole these cases close: before US-C-GATE, CODE_DIRS covered only
# modules/*, examples/* and labs/day-2/* WITH a *.tftest.hcl. A Day-1 lab whose
# HCL had a dangling reference was caught only INDIRECTLY, by the §6 drift gate
# noticing the annotated ```hcl block no longer matched the file. Regenerating
# the block — exactly what a curriculum story asks an author to do — made the
# gate green over structurally broken HCL, and the learner met the error as a
# failing `tofu plan`.
#
# Both fixtures are deliberately PROVIDER-FREE so `tofu init -backend=false`
# resolves nothing and each case stays sub-second. The broken variant references
# an undeclared resource, which init accepts (it is a validate-time error) and
# `tofu validate` rejects with "Reference to undeclared resource".
DAY1_VALIDATE_DIR="labs/day-1/99-validate-selftest"
DAY3_VALIDATE_DIR="labs/day-3/99-validate-selftest/stacks/app"

plant_lab_validate_root() {
  local root="$1" rel="$2" body="$3"
  mkdir -p "$root/$rel"
  if [ "$body" = "clean" ]; then
    cat >"$root/$rel/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.8"
}

locals {
  release = "lab-validate-ok"
}

output "release_name" {
  value = local.release
}
EOF
  else
    # Undeclared `random_pet.release` — the exact shape of the defect this
    # story was written against (labs/day-1/03-core-workflow/main.tf).
    cat >"$root/$rel/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.8"
}

output "release_name" {
  value = random_pet.release.id
}
EOF
  fi
}

m_lab_validate_day1_clean() {
  plant_lab_validate_root "$1" "$DAY1_VALIDATE_DIR" clean
}

m_lab_validate_day1_broken() {
  plant_lab_validate_root "$1" "$DAY1_VALIDATE_DIR" broken
}

# Day-3's runnable roots are NESTED (labs/day-3/NN-topic/stacks/<name>/), never
# at the top of the lab dir — a top-level-only scan would validate exactly one
# of them. This case pins the recursive discovery: drop it and a day-1-only glob
# would still leave every other case green.
m_lab_validate_day3_nested_broken() {
  plant_lab_validate_root "$1" "$DAY3_VALIDATE_DIR" broken
}

# Day-2 lab workdir sweep (US-E-D2SWEEP / section 3 CODE_DIRS).
#
# The hole these cases close: after US-C-GATE, day-2 was STILL the odd one out —
# its discovery loop only picked workdirs that also shipped *.tftest.hcl, so
# 18-terratest-cost/, 18-terratest-cost/cost/ and 19-testing-cicd/fixture/ got
# fmt-only treatment (audit TEST-2). The sweep must be recursive (18's cost/
# fixture and 19's fixture/ are NESTED, exactly like day-3's stacks) and must
# exclude the two intentionally-broken teaching fixtures BY PATH:
# labs/day-2/13-static-analysis/messy/ (fails even `tofu init`) and
# labs/day-2/14-security-scanners/messy/.
DAY2_SWEEP_DIR="labs/day-2/99-d2sweep-selftest"
DAY2_SWEEP_NESTED_DIR="labs/day-2/99-d2sweep-selftest/fixture"
DAY2_MESSY_14_DIR="labs/day-2/14-security-scanners/messy"

# A broken .tf in a NESTED day-2 workdir with NO *.tftest.hcl anywhere near it.
# Nested on purpose: a top-level-only day-2 sweep would leave this case green
# while 18-terratest-cost/cost/ and 19-testing-cicd/fixture/ stayed uncovered.
m_day2_sweep_nested_broken() {
  plant_lab_validate_root "$1" "$DAY2_SWEEP_NESTED_DIR" broken
}

# Exclusion-LAYER probe, not just an inclusion outcome. Three plants in ONE run:
#   (a) a clean swept sibling → its "…: validate" pass line proves the day-2
#       sweep is ARMED in this very run (a bare green would also be produced by
#       a sweep that never ran);
#   (b) a validate-broken .tf planted directly in 14-security-scanners/messy/
#       (init-clean, so only `tofu validate` could red on it);
#   (c) a validate-broken .tf in a SUBDIR of that messy/ dir, pinning that the
#       exclusion is a PATH PREFIX, not an exact-directory match.
# The sandbox also always carries the real 13-static-analysis/messy/main.tf,
# which fails `tofu init` outright — so if EITHER messy path leaks into the
# sweep, this case (and half the suite) goes red. Expected: still green.
m_day2_messy_excluded() {
  local root="$1"
  plant_lab_validate_root "$root" "$DAY2_SWEEP_DIR" clean
  plant_lab_validate_root "$root" "$DAY2_MESSY_14_DIR" broken
  plant_lab_validate_root "$root" "$DAY2_MESSY_14_DIR/deeper" broken
}

# The init FAILURE branch used to print nothing but "init failed", and the one
# message it hides is the provider-cache signature that this project has twice
# misdiagnosed as a flake. Stub `init` for one lab dir to emit exactly that
# text, and assert verify.sh reproduces it AND names both mechanisms — the cold
# cache (which nothing here fixes) and a concurrent writer (which the lock
# covers). Everything other than that one init call is delegated to the real
# tofu, so the rest of the run is unaffected.
m_init_provider_cache_failure() {
  local root="$1" real
  plant_lab_validate_root "$root" "$DAY1_VALIDATE_DIR" clean
  real="$(command -v tofu)"
  cat >"$root/test-bin/tofu" <<STUB
#!/bin/sh
if [ "\$1" = "-chdir=$DAY1_VALIDATE_DIR" ] && [ "\$2" = "init" ]; then
  echo "Initializing the backend..." >&2
  echo "Error: Required plugins are not installed" >&2
  echo "there is no package for registry.opentofu.org/hashicorp/aws 5.100.0 cached in .terraform/providers" >&2
  exit 1
fi
exec "$real" "\$@"
STUB
  chmod +x "$root/test-bin/tofu"
}

m_lab_integration_only() {
  local root="$1"
  mkdir -p "$root/$LAB_TFTTEST_DIR/tests"
  # Provider-free stub: init must still parse the integration suite (tofu
  # validates assert expressions at init), so the condition references config.
  cat >"$root/$LAB_TFTTEST_DIR/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.8"
}

locals {
  marker = "integration-only"
}

output "marker" {
  value = local.marker
}
EOF
  # Apply-style name only — unit lane must skip without requiring LocalStack.
  cat >"$root/$LAB_TFTTEST_DIR/tests/integration.tftest.hcl" <<'EOF'
run "would_need_localstack" {
  command = apply

  assert {
    condition     = output.marker == "integration-only"
    error_message = "unreachable in unit lane"
  }
}
EOF
}

# §5: illustrative prose must not invent a hard-fail shared-code ref (US-F-R4).
m_smoke_prose_fake_module() {
  local root="$1"
  mkdir -p "$root/labs/day-1"
  cat >>"$root/labs/day-1/00-setup.md" <<'EOF'

## Illustrative (self-test only)

See `modules/does-not-exist` — teaching prose, not a `source =` dependency.
EOF
}

# §5: a real HCL source = "…modules/…" path that is missing on disk must still fail.
m_smoke_hcl_missing_source() {
  local root="$1"
  mkdir -p "$root/labs/day-1"
  cat >>"$root/labs/day-1/00-setup.md" <<'EOF'

## Broken shared ref (self-test only)

```hcl
module "ghost" {
  source = "./modules/does-not-exist"
}
```
EOF
}

# §5: shell entrypoints (-chdir=/cd/DIR=) citing a missing shared root must fail.
m_smoke_chdir_missing_example() {
  local root="$1"
  mkdir -p "$root/labs/day-1"
  cat >>"$root/labs/day-1/00-setup.md" <<'EOF'

## Broken shell entrypoint (self-test only)

cd examples/does-not-exist
tofu -chdir=examples/does-not-exist init -backend=false
task lab:apply DIR=examples/does-not-exist
EOF
}

# R1 — cover the WIRING, not just the function.
#
# The lane's actual deliverable is the `dump_case_output "$out"` call in
# run_case. Nothing exercised it: no green run enters a failure branch, so
# reverting it to the old `grep -E 'drift|annotated|pin drift|Formatting'`
# filter left all checks passing — the deliverable had zero regression
# protection. (It was originally TWO calls, one per failure branch, and this
# check drove only the `expect=pass` one, so reverting just the other stayed
# green. The call is now hoisted past the verdict to a SINGLE site, which makes
# that mutation unrepresentable rather than merely tested for.)
#
# run_case is driven in a subshell so its deliberate failure cannot pollute
# pass_n/fail_n. The probe is EXPECTED to fail; that is the point.
#
# The needles are the dump's own delimiters, decisive because the old filter
# could not emit them under any input: it printed matching lines only, never a
# header, a marker or a line count. ('Formatting' WOULD have matched the old
# filter, which is exactly why it is not used here.)
check_run_case_wiring() {
  local out
  set +e
  out="$(set -euo pipefail; run_case "wiring probe — deliberately impossible needle" \
          pass 'NEEDLE-THAT-CANNOT-APPEAR-XYZZY' m_clean 2>&1)"
  set -e
  if has_text "$out" '---- verify.sh output (' \
     && has_text "$out" '---- end of verify.sh output ----' \
     && has_text "$out" '» Preflight'; then
    ok "run_case wiring: a failing case emits the full dump, not a filtered grep"
  else
    bad "run_case wiring: a failing case did not emit the dump — the call site is gone or filtered"
    printf '%s\n' "$out" | tail -n 10 | sed 's/^/        | /'
  fi
}
# --- temp-root cleanup probes (US-F-GATEHYG) ---------------------------------
#
# Both branches of run_case must remove the case tree, and the FAIL branch is
# the one nothing ever exercised on a green run — the same blind spot that let
# the dump_case_output regression ship. check_run_case_wiring below drives a
# deliberately-failing case, so calling this immediately after it observes the
# fail path; calling it again after the first ordinary case observes the pass
# path. `tail -n 1` of the ledger is the tree the most recent case used.
check_case_tmp_cleaned() {
  local label="$1" tmp_path
  tmp_path="$(tail -n 1 "$RUN_CASE_TMP_TRACE" 2>/dev/null || true)"
  if [ -z "$tmp_path" ]; then
    # Never report a green over an empty ledger: "nothing leaked" and "nothing
    # was ever recorded" are the same observation and only one of them is good.
    bad "temp cleanup ($label) — run_case recorded no temp root; this probe is DISARMED"
  elif [ -d "$tmp_path" ]; then
    bad "temp cleanup ($label) — $tmp_path still on disk after the case returned"
  else
    ok "temp cleanup ($label) — the case's temp root was removed"
  fi
}

# Whole-run sweep. Stronger than the two point checks: it asserts EVERY case
# removed its own tree while this script was still running, so deleting
# run_case's `rm -rf` and leaning on the script-level EXIT trap instead is a
# red, not a silent behaviour change.
# check_all_case_tmp_cleaned <label> <ledger> <floor>
#
# <floor> is a LOWER BOUND on how many roots that ledger must have recorded, not
# the exact count — deliberately loose, so adding or removing a case does not
# force an edit here, while a regression that routes the append somewhere it
# only fires for a handful of cases still goes red. A ledger that recorded
# nothing is reported as DISARMED, never as a clean sweep: "nothing leaked" and
# "nothing was ever recorded" are the same observation and only one is good.
check_all_case_tmp_cleaned() {
  local label="$1" ledger="$2" floor="$3"
  local total=0 leaked=0 p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    total=$((total + 1))
    if [ -d "$p" ]; then leaked=$((leaked + 1)); fi
  done <"$ledger"
  if [ "$total" -lt "$floor" ]; then
    bad "temp cleanup sweep ($label) — only $total root(s) recorded, expected at least $floor; this probe is DISARMED"
  elif [ "$leaked" -eq 0 ]; then
    ok "temp cleanup sweep ($label) — all $total temp root(s) removed, 0 leaked"
  else
    bad "temp cleanup sweep ($label) — $leaked of $total temp root(s) still on disk"
  fi
}

# Anti-wedge sweep for the verify.sh lock: a run that exits without releasing it
# leaves every FUTURE run in that checkout refused. Covers all cases at once,
# including the ones that exit non-zero (drift, pin drift, the preflight death).
check_no_case_left_lock() {
  local leaked
  leaked="$(grep -c . "$RUN_CASE_LOCK_TRACE" 2>/dev/null || true)"
  [ -n "$leaked" ] || leaked=0
  if [ "$leaked" -eq 0 ]; then
    ok "lock release sweep — no case left a .verify.lock behind (pass and fail exits)"
  else
    bad "lock release sweep — $leaked case(s) left .verify.lock behind; the next run in that checkout is WEDGED"
  fi
}

check_run_case_wiring
check_case_tmp_cleaned "fail path — the wiring probe's deliberately failing case"

# --- verify.sh single-run guard (US-F-GATEHYG) -------------------------------
#
# These four scenarios cannot be expressed as run_case cases: each needs the
# sandbox root BEFORE and AFTER the run — to plant a lock, to inspect what
# survived, or to signal the run mid-flight — while run_case owns its root for
# exactly the duration of one invocation.
#
# What they establish, and why each is here rather than assumed:
#   * the guard REFUSES a second run and explains itself   (the deliverable)
#   * the refused run does NOT delete the holder's lock    (the error path that
#     would silently reopen the corruption while looking like a clean refusal)
#   * a STALE lock is broken, not obeyed forever           (a wedge is worse
#     than the bug being fixed)
#   * the lock is genuinely TAKEN during a run, and released after SIGTERM
#     (without the "taken" half, every "released" assertion would pass
#     vacuously against a verify.sh that never locked at all)
LOCK_REFUSAL_NEEDLE='another verify.sh is already running in this checkout'
# Mirrors S13_MESSY_FIXTURE in verify.sh — the one file in the repo that is
# unformatted on purpose, and therefore the canary for a destructive fmt run.
S13_MESSY_FIXTURE_REL='labs/day-2/13-static-analysis/messy/main.tf'

# Plant a lock directory by hand, exactly as verify.sh writes one.
plant_verify_lock() {
  local root="$1" pid="$2" host="${3:-$(uname -n)}"
  mkdir -p "$root/.verify.lock"
  printf '%s\n' "$pid"  >"$root/.verify.lock/pid"
  printf '%s\n' "$host" >"$root/.verify.lock/host"
  printf '%s\n' "planted by verify-selftest.sh" >"$root/.verify.lock/started"
}

# A sandbox root that is tracked by the same ledger run_case uses, so the
# end-of-run sweep covers these scenarios too.
new_lock_sandbox() {
  local t
  t="$(mktemp -d "$SELFTEST_TMP_ROOT/lock.XXXXXXXX")"
  printf '%s\n' "$t" >>"$LOCK_SANDBOX_TMP_TRACE"
  build_root "$t"
  printf '%s' "$t"
}

check_lock_refuses_concurrent_run() {
  local tmp holder out rc
  tmp="$(new_lock_sandbox)"
  # A LIVE holder. `kill -0` on this pid succeeds, so the staleness path must
  # NOT fire — a guard that breaks a live lock is not a guard.
  sleep 30 &
  holder=$!
  plant_verify_lock "$tmp" "$holder"
  set +e
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  kill "$holder" 2>/dev/null || true
  wait "$holder" 2>/dev/null || true
  # Exit code AND message, for the same reason every other case asserts both:
  # a non-zero exit alone would also be produced by an unrelated env break.
  if [ "$rc" -ne 0 ] && has_text "$out" "$LOCK_REFUSAL_NEEDLE"; then
    ok "concurrency guard — a second run in the same checkout is refused (exit $rc) and says why"
  else
    bad "concurrency guard — expected a non-zero refusal naming the concurrent run; got exit $rc"
    dump_case_output "$out"
  fi
  if [ -d "$tmp/.verify.lock" ]; then
    ok "concurrency guard — the refused run left the live holder's lock intact"
  else
    bad "concurrency guard — the refused run DELETED the holder's lock, reopening the corruption it just refused"
  fi
  rm -rf "$tmp"
}

check_lock_breaks_stale_lock() {
  local tmp dead out rc
  tmp="$(new_lock_sandbox)"
  # A pid that is guaranteed dead, obtained honestly: spawn, then reap. Picking
  # a large constant instead would be a coin flip on whether the OS had already
  # recycled it, and this test would fail for a reason that is not the code.
  ( exit 0 ) &
  dead=$!
  wait "$dead" 2>/dev/null || true
  plant_verify_lock "$tmp" "$dead"
  set +e
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  # Absolute path in the needle: the message names $VERIFY_LOCK_DIR so a reader
  # in a subdirectory gets a remedy that actually works (review G8).
  if [ "$rc" -eq 0 ] && has_text "$out" "stale $tmp/.verify.lock left by pid $dead" \
     && [ ! -d "$tmp/.verify.lock" ]; then
    ok "concurrency guard — a stale lock (dead pid) is named, broken, and the run completes"
  else
    bad "concurrency guard — expected the stale lock to be broken and the run to finish; got exit $rc"
    dump_case_output "$out"
  fi
  rm -rf "$tmp"
}

check_lock_released_after_kill() {
  local tmp real pid tries=0 appeared=0 alive=0
  tmp="$(new_lock_sandbox)"
  # Slow the run down so it can be caught in the act. `version` is delegated
  # untouched so preflight still passes and the lock is genuinely taken; only
  # `fmt` is padded, and it still runs for real afterwards.
  real="$(command -v tofu)"
  cat >"$tmp/test-bin/tofu" <<STUB
#!/bin/sh
if [ "\$1" = "fmt" ]; then sleep 3; fi
exec "$real" "\$@"
STUB
  chmod +x "$tmp/test-bin/tofu"
  PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" >/dev/null 2>&1 &
  pid=$!
  # Poll for the lock instead of sleeping a fixed amount: a fixed delay races
  # acquisition and would make this test intermittently green for the wrong
  # reason — in the one lane whose whole subject is misleading flakes.
  while [ "$tries" -lt 100 ]; do
    if [ -d "$tmp/.verify.lock" ]; then appeared=1; break; fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.05
    tries=$((tries + 1))
  done
  if [ "$appeared" -eq 1 ]; then
    ok "single-run guard — the lock is actually TAKEN during a run (so the release checks are not vacuous)"
  else
    bad "single-run guard — no .verify.lock ever appeared; the guard is absent and every release assertion is vacuous"
  fi
  kill -0 "$pid" 2>/dev/null && alive=1
  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if [ "$alive" -eq 1 ] && [ ! -d "$tmp/.verify.lock" ]; then
    ok "anti-wedge — a SIGTERMed run releases its lock (the next run in that checkout is not refused)"
  elif [ "$alive" -ne 1 ]; then
    bad "anti-wedge — the run had already exited before SIGTERM; this scenario proved nothing"
  else
    bad "anti-wedge — a killed run left .verify.lock behind; every later run in that checkout is WEDGED"
  fi
  rm -rf "$tmp"
}

# A stray regular file where the lock directory belongs. `mkdir` fails with
# EEXIST exactly as it does under contention, so without the `[ ! -d ]` guard
# the run would blame a concurrent process that does not exist and print a pid
# of "unknown" — sending the reader hunting nothing. Deterministic and
# root-proof, unlike chmod-based unwritability, which root bypasses.
check_lock_reports_unusable_lock_path() {
  local tmp out rc
  tmp="$(new_lock_sandbox)"
  printf 'not a lock directory\n' >"$tmp/.verify.lock"
  set +e
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] && has_text "$out" "cannot create .verify.lock" \
     && has_text "$out" "this is NOT a concurrent run"; then
    ok "single-run guard — an unusable lock path is diagnosed as itself, not as a phantom concurrent run"
  else
    bad "single-run guard — expected a non-zero 'cannot create .verify.lock' refusal; got exit $rc"
    dump_case_output "$out"
  fi
  rm -rf "$tmp"
}

# G1 — the stale-lock break is a READ-then-DESTROY sequence, and between the two
# there are three forks and a `warn`. If another run acquires the lock in that
# gap, an unguarded break destroys a LIVE lock while announcing "breaking it",
# and both runs then `tofu init` in the labs — the exact corruption this lane
# exists to prevent, with a confident message on top.
#
# `check_lock_breaks_stale_lock` is single-racer by construction and cannot see
# this. Making the race deterministic needs a controllable window, so this case
# stubs `cat` to sleep for exactly one path — the lock's pid file, which is the
# first thing acquire_verify_lock reads. Everything else is delegated untouched.
# A second acquirer is then interleaved by the clock, not by luck.
check_lock_break_is_not_a_race() {
  local tmp dead live a_pid rc real_cat lock_pid
  tmp="$(new_lock_sandbox)"
  ( exit 0 ) &
  dead=$!
  wait "$dead" 2>/dev/null || true
  plant_verify_lock "$tmp" "$dead"
  real_cat="$(command -v cat)"
  # The delay must come AFTER the read, not before it. A stub that sleeps first
  # hands verify.sh the pid as it stands at the END of the window — i.e. racer
  # B's live pid — so the guard correctly refuses and the case passes for the
  # wrong reason. (Observed: this test went green against the unfixed code.)
  # Emitting the STALE value and only then holding the pipe open reproduces the
  # real defect: a decision made on data that has since gone out of date.
  cat >"$tmp/test-bin/cat" <<STUB
#!/bin/sh
case "\$1" in
  */.verify.lock/pid)
    "$real_cat" "\$@"
    sleep 3
    exit 0
    ;;
esac
exec "$real_cat" "\$@"
STUB
  chmod +x "$tmp/test-bin/cat"
  PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" >"$tmp/racer.log" 2>&1 &
  a_pid=$!
  # Racer A is now inside the widened read. Racer B takes the lock underneath it,
  # exactly as a second lane start would after a SIGKILL left the stale lock.
  sleep 1
  sleep 30 &
  live=$!
  rm -rf "$tmp/.verify.lock"
  mkdir "$tmp/.verify.lock"
  printf '%s\n' "$live"       >"$tmp/.verify.lock/pid"
  printf '%s\n' "$(uname -n)" >"$tmp/.verify.lock/host"
  printf '%s\n' "racer B"     >"$tmp/.verify.lock/started"
  set +e
  wait "$a_pid"
  rc=$?
  set -e
  lock_pid="$("$real_cat" "$tmp/.verify.lock/pid" 2>/dev/null || true)"
  kill "$live" 2>/dev/null || true
  wait "$live" 2>/dev/null || true
  if [ "$rc" -ne 0 ] && [ "$lock_pid" = "$live" ]; then
    ok "concurrency guard — a stale-lock break does not destroy a lock re-acquired mid-break (two racers)"
  else
    bad "concurrency guard — the break DESTROYED a live lock re-acquired mid-break: racer A exited $rc, lock now held by '${lock_pid:-nobody}' (expected '$live')"
    dump_case_output "$("$real_cat" "$tmp/racer.log" 2>/dev/null || true)"
  fi
  rm -rf "$tmp"
}

# G4 — the host check was untested. Mutating `[ "$host" = "$VERIFY_HOST" ]` to
# always-true left the whole suite green, because plant_verify_lock only ever
# wrote this host's name.
#
# The pid here must be DEAD, and that is the whole design of the case. With a
# LIVE pid a broken host check still refuses — correctly, for the wrong reason —
# and the case passes while proving nothing. With a dead one, correct code
# refuses on the host mismatch and broken code breaks the lock and runs, so the
# two are distinguishable. (First draft of this case used a live pid and was
# mutation-blind; caught before it shipped.)
#
# Why the host must match at all: a pid recorded on another machine says nothing
# about any process here. Pid 4242 from a CI runner is, on this laptop, either
# nothing or something entirely unrelated — "is it alive?" is not even the right
# question. Shared checkouts over NFS/SMB and container-vs-host mounts are how
# a foreign-host lock actually arrives.
check_lock_refuses_foreign_host_lock() {
  local tmp dead out rc
  tmp="$(new_lock_sandbox)"
  ( exit 0 ) &
  dead=$!
  wait "$dead" 2>/dev/null || true
  plant_verify_lock "$tmp" "$dead" "some-other-machine.example"
  set +e
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] && has_text "$out" "$LOCK_REFUSAL_NEEDLE" \
     && has_text "$out" "some-other-machine.example" && [ -d "$tmp/.verify.lock" ]; then
    ok "concurrency guard — a lock recorded on another HOST is refused intact, never broken on a local pid"
  else
    bad "concurrency guard — a foreign-host lock was not refused intact; got exit $rc"
    dump_case_output "$out"
  fi
  rm -rf "$tmp"
}

# G5 — the pid-shape guard was untested too. Neutralising `'' | *[!0-9]*)` left
# the suite green.
#
# The guard's job is to treat anything that is not a plain number as "not
# provably dead, therefore refuse". A MALFORMED pid is what isolates it: the
# host matches, so the host check cannot produce the refusal, and `ps -p
# not-a-number` fails, so a missing guard reads that as "dead" and breaks a lock
# it knows nothing about. The neighbouring state — a holder that won the `mkdir`
# and has written no metadata AT ALL — is covered by the host check instead,
# since its host file is empty too; that one cannot isolate this guard, which is
# why this case plants garbage rather than nothing.
check_lock_refuses_malformed_pid() {
  local tmp out rc
  tmp="$(new_lock_sandbox)"
  plant_verify_lock "$tmp" "not-a-number"
  set +e
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] && has_text "$out" "$LOCK_REFUSAL_NEEDLE" \
     && [ -d "$tmp/.verify.lock" ]; then
    ok "concurrency guard — a lock with an unreadable pid is refused intact, never assumed dead"
  else
    bad "concurrency guard — a malformed-pid lock was not refused intact; got exit $rc"
    dump_case_output "$out"
  fi
  rm -rf "$tmp"
}

# --- the fmt DETECTOR must not be a mutator (US-F-GATEHYG, round 2) ----------
#
# `tofu fmt -check` is read-only only as long as nobody has set TF_CLI_ARGS or
# TF_CLI_ARGS_fmt. OpenTofu splices those in BEFORE user argv, so a value like
# `-recursive .` puts a POSITIONAL argument ahead of `-check`; the positional
# terminates flag parsing, `-check` is demoted to a path, and tofu recursively
# REWRITES `.` — which, since verify.sh cds to REPO_ROOT, is the whole checkout.
# It reports an error about the bogus path only afterwards, once the damage is
# done.
#
# Reproduced directly before this case was written (sha 13f0af5a -> d0b767a2 on
# the S13 fixture, identically for both the qualified and unqualified var). No
# repo edit and no maintainer error is needed: an exported shell variable, a
# direnv .envrc, or a CI env block is enough. That makes the detector — the
# read-only half of this gate's entire design — a destroyer of the S13 teaching
# fixture it exists to allowlist.
#
# The assertion is deliberately NOT "the file matches the git index". After a
# destructive run plus any `git add -A`, the index holds the DESTROYED copy and
# such a check would go green forever. This compares against a pristine copy
# taken before the run, and independently re-checks that the file is still
# non-canonical — the property that makes it a teaching fixture at all.
check_fmt_scan_survives_tf_cli_args() {
  local tmp out rc pristine fixture fmt_rc
  tmp="$(new_lock_sandbox)"
  fixture="$tmp/$S13_MESSY_FIXTURE_REL"
  pristine="$tmp.pristine"
  cp "$fixture" "$pristine"
  set +e
  out="$(TF_CLI_ARGS_fmt="-recursive ." TF_CLI_ARGS="-recursive ." \
         PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  # Is the fixture still exactly what it was? cmp, not a hash, so no dependency
  # on shasum/md5 differing between darwin and the CI runner.
  if cmp -s "$pristine" "$fixture"; then
    ok "fmt detector — TF_CLI_ARGS/TF_CLI_ARGS_fmt cannot turn 'tofu fmt -check' into a rewrite of the tree"
  else
    bad "fmt detector — running verify.sh under TF_CLI_ARGS_fmt REWROTE $S13_MESSY_FIXTURE_REL; the read-only gate is a mutator"
    dump_case_output "$out"
  fi
  # Independent of the byte comparison: the fixture must still be UNFORMATTED.
  # If it were silently canonicalised this returns 0 and the case fails, even
  # were the comparison above ever weakened to something index-based.
  set +e
  env -u TF_CLI_ARGS -u TF_CLI_ARGS_fmt tofu fmt -check "$fixture" >/dev/null 2>&1
  fmt_rc=$?
  set -e
  if [ "$fmt_rc" -ne 0 ]; then
    ok "fmt detector — the S13 teaching fixture is still deliberately unformatted after the run"
  else
    bad "fmt detector — the S13 teaching fixture is now canonically formatted; the lab's break->fix step is gone"
  fi
  # And the gate itself must still have reported honestly.
  if [ "$rc" -eq 0 ]; then
    ok "fmt detector — verify.sh still passes with those variables set (they are neutralised, not obeyed)"
  else
    bad "fmt detector — verify.sh exited $rc under TF_CLI_ARGS_fmt; expected the variables to be neutralised"
    dump_case_output "$out"
  fi
  rm -f "$pristine"
  rm -rf "$tmp"
}

check_fmt_scan_survives_tf_cli_args
check_lock_refuses_concurrent_run
check_lock_refuses_foreign_host_lock
check_lock_refuses_malformed_pid
check_lock_breaks_stale_lock
# F1 — TWO BREAKERS on the SAME stale lock. This is the case that covers the
# `mv`, and without it the arbitration had ZERO coverage: an independent
# reviewer reverted steps 2-3 to `rm -rf; mkdir` while KEEPING the step-1
# re-read, and the whole suite stayed 71/71 green with two verify.sh runs past
# the guard simultaneously. Reproduced here before writing this: with `mv`
# removed the suite was green, and the same mutant reds this case.
#
# Why check_lock_break_is_not_a_race does not cover it: there, racer B ACQUIRES
# the lock, so racer A's step-1 re-read sees a different pid and refuses. A
# never reaches the `mv`. That case also passes with step 1 deleted, so neither
# layer was distinguishable. Past step 1, the `mv` is the ONLY thing preventing
# two holders — this is not defence in depth.
#
# THE DISARMING TRAP, which caught the reviewer's first draft and is the third
# instance this session of a test being green against the very defect it
# targets: the counter that decides which `cat` invocation sleeps must live in
# an ENV VAR, not be keyed on $PPID. Command substitution forks a fresh subshell
# per read, so a $PPID-keyed counter never reaches 2, nobody sleeps, the racers
# never overlap, and the case passes without ever opening the window. Hence the
# hard "window armed on BOTH racers" assertion below: if either racer failed to
# sleep, this case proves nothing and says so.
#
# ARMING DEPENDS ON STEP 1 EXISTING, and that is deliberate rather than
# accidental coupling: the window is opened on the SECOND read of the pid file,
# which is step 1's re-read. Delete step 1 and this case reports itself DISARMED
# ("the window opened on only 1/2 racers") instead of passing vacuously —
# verified by mutation. If step 1 is ever legitimately refactored away, re-key
# the counter on whichever read still precedes the `mv`; do not simply lower the
# threshold to make the red go away.
#
# Step 1 itself is a courtesy, not a safety property, and the suite says so:
# with step 1 removed, 46e still passes, because step 3 catches the same
# situation after the fact. Only the `mv` prevents two holders.
#
# Assertions are LOG-based, deliberately. Sampling liveness with `ps` at a wall
# clock offset — the obvious way to count "runs past the guard" — reports an
# exited-but-unreaped child as alive, and that flaked 1 run in 3 against correct
# code while writing this. What each racer DID is recorded in its own log and is
# not timing-sensitive after the fact.
check_lock_two_breakers_single_winner() {
  local tmp dead real_cat b c b_rc c_rc refusals breaks armed
  tmp="$(new_lock_sandbox)"
  ( exit 0 ) &
  dead=$!
  wait "$dead" 2>/dev/null || true
  plant_verify_lock "$tmp" "$dead"
  real_cat="$(command -v cat)"
  # Sleep on the SECOND read of the pid file — that is the step-1 re-read inside
  # break_stale_lock_and_acquire — so both racers are held there and arrive at
  # the `mv` together, each still holding the same dead pid.
  cat >"$tmp/test-bin/cat" <<STUB
#!/bin/sh
case "\$1" in
  */.verify.lock/pid)
    n_file="\${CATCOUNT:-$tmp/catcount.default}"
    n=0
    [ -f "\$n_file" ] && n="\$("$real_cat" "\$n_file")"
    n=\$((n + 1))
    printf '%s' "\$n" >"\$n_file"
    "$real_cat" "\$@"
    if [ "\$n" -eq 2 ]; then
      : >"\${n_file}.armed"
      sleep 3
    fi
    exit 0
    ;;
esac
exec "$real_cat" "\$@"
STUB
  chmod +x "$tmp/test-bin/cat"

  CATCOUNT="$tmp/cnt.b" PATH="$tmp/test-bin:$PATH" \
    bash "$tmp/scripts/verify.sh" >"$tmp/b.log" 2>&1 &
  b=$!
  CATCOUNT="$tmp/cnt.c" PATH="$tmp/test-bin:$PATH" \
    bash "$tmp/scripts/verify.sh" >"$tmp/c.log" 2>&1 &
  c=$!
  set +e
  wait "$b"; b_rc=$?
  wait "$c"; c_rc=$?
  set -e

  armed=0
  [ -f "$tmp/cnt.b.armed" ] && armed=$((armed + 1))
  [ -f "$tmp/cnt.c.armed" ] && armed=$((armed + 1))
  refusals=0
  grep -q 'refusing to start' "$tmp/b.log" && refusals=$((refusals + 1))
  grep -q 'refusing to start' "$tmp/c.log" && refusals=$((refusals + 1))
  breaks=0
  grep -q 'breaking it' "$tmp/b.log" && breaks=$((breaks + 1))
  grep -q 'breaking it' "$tmp/c.log" && breaks=$((breaks + 1))

  if [ "$armed" -eq 2 ]; then
    ok "two-breaker race — the window opened on BOTH racers (the case is armed)"
  else
    bad "two-breaker race — the window opened on only $armed/2 racers; this case is DISARMED and proves nothing"
  fi
  # Exactly one racer may move the lock aside, so exactly one may announce a
  # break. Two breaks means two runs decided the lock was theirs to destroy.
  if [ "$breaks" -eq 1 ]; then
    ok "two-breaker race — exactly one racer broke the stale lock"
  else
    bad "two-breaker race — $breaks racers broke the SAME stale lock; the arbitration is not single-winner"
  fi
  if [ "$refusals" -eq 1 ]; then
    ok "two-breaker race — exactly one racer was refused"
  else
    bad "two-breaker race — $refusals refusals (expected exactly 1); rc were $b_rc/$c_rc"
    dump_case_output "$("$real_cat" "$tmp/b.log" "$tmp/c.log" 2>/dev/null || true)"
  fi
  # Exit 2 is "declined to run"; exactly one racer must have been turned away
  # and exactly one must have proceeded.
  if { [ "$b_rc" -eq 2 ] && [ "$c_rc" -ne 2 ]; } || { [ "$c_rc" -eq 2 ] && [ "$b_rc" -ne 2 ]; }; then
    ok "two-breaker race — exactly one racer got past the guard (rc $b_rc / $c_rc)"
  else
    bad "two-breaker race — both racers got past the guard or both were refused (rc $b_rc / $c_rc)"
  fi
  if [ ! -d "$tmp/.verify.lock" ]; then
    ok "two-breaker race — the winner released the lock on exit, no wedge"
  else
    bad "two-breaker race — a lock survived both racers; the next run in that checkout is WEDGED"
  fi
  rm -rf "$tmp"
}

# F2 — `holder_is_alive` must not read EPERM as "dead". `kill -0` cannot tell
# "no such process" from "alive, but not yours to signal", so a lock held by a
# root-owned run (`sudo bash scripts/verify.sh`, a CI runner that switches user)
# would be broken while its owner was still working in the labs. `ps -p` asks
# the question actually being asked.
#
# pid 1 is the portable EPERM holder: alive on every unix, owned by root,
# unsignalable by an ordinary user. The precondition is ASSERTED rather than
# assumed — as root, or in a container whose pid 1 belongs to this uid, the
# asymmetry does not exist and the case would pass vacuously against either
# implementation, so it reports itself as not applicable instead of green.
check_lock_treats_eperm_holder_as_alive() {
  local tmp out rc
  if kill -0 1 2>/dev/null || ! ps -p 1 >/dev/null 2>&1; then
    note "EPERM holder case not applicable here (uid $(id -u): pid 1 is signalable, or absent) — skipped, not passed"
    return 0
  fi
  tmp="$(new_lock_sandbox)"
  plant_verify_lock "$tmp" 1
  set +e
  out="$(PATH="$tmp/test-bin:$PATH" bash "$tmp/scripts/verify.sh" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] && has_text "$out" "$LOCK_REFUSAL_NEEDLE" \
     && ! has_text "$out" "breaking it" && [ -d "$tmp/.verify.lock" ]; then
    ok "concurrency guard — a holder this user cannot signal (EPERM) counts as ALIVE, so its lock is refused intact"
  else
    bad "concurrency guard — an unsignalable but LIVE holder was treated as dead; got exit $rc"
    dump_case_output "$out"
  fi
  rm -rf "$tmp"
}

check_lock_break_is_not_a_race
check_lock_two_breakers_single_winner
check_lock_treats_eperm_holder_as_alive
check_lock_reports_unusable_lock_path
check_lock_released_after_kill

run_case "clean fixture"        pass "no drift: labs/fixtures/drift-demo/main.tf matches" m_clean
check_case_tmp_cleaned "pass path — an ordinary green case"
run_case "LF-authored drift"    fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_lf
run_case "CRLF-authored drift"  fail "drift: block in labs/fixtures/drift-demo.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_drift_crlf
run_case "pages magic-move clean" pass "no drift: labs/fixtures/drift-demo/main.tf matches its block in index.md" m_pages_clean
run_case "pages LF-authored drift" fail "drift: block in pages/S99-drift-selftest/index.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_pages_drift_lf
run_case "pages CRLF-authored drift" fail "drift: block in pages/S99-drift-selftest/index.md does NOT match source file: labs/fixtures/drift-demo/main.tf" m_pages_drift_crlf
run_case "templates magic-move clean" pass "no drift: labs/fixtures/templates-demo/selftest.tf matches its block in slides-templates.md" m_templates_clean
run_case "templates LF-authored drift" fail "drift: block in slides-templates.md does NOT match source file: labs/fixtures/templates-demo/selftest.tf" m_templates_drift_lf
run_case "cross-deck tier mismatch (S05)" fail "tier drift: S05 is 'recommended' in slides.md but 'core' in slides-3day.md" m_tier_mismatch
run_case "hide-invariant violation (S18)" fail "hide invariant: S18 is 'optional' but hide='false' in slides-3day.md" m_hide_violation
run_case "README navigation contract" pass "README navigation contract" m_clean
run_case "deleted README route" fail "README route 'Lab 00' is missing: labs/day-1/00-setup.md" m_missing_lab_route
run_case "unknown README task" fail "README task command does not exist: task dev:ghost" m_unknown_readme_task
run_case "missing Day-2/3 tool skips" pass "tflint unavailable — skipping tool-dependent checks for S13 static analysis" m_clean
run_case "exact S13 messy fixture allowlisted" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_clean
run_case "adjacent S13 file is not allowlisted" fail "labs/day-2/13-static-analysis/messy/adjacent.tf" m_unformatted_beside_fixture
run_case "unformatted file outside allowlist" fail "modules/unformatted-regression/main.tf" m_unformatted_outside_allowlist
run_case "unformatted under .claude/worktrees ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_unformatted_under_claude_worktree
run_case "unformatted under node_modules ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_unformatted_under_node_modules
run_case "unformatted under .terraform ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_unformatted_under_dot_terraform
run_case "unformatted under .worktrees ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_unformatted_under_worktrees "$FIND_SCAN_HEADING"
run_case "git mode: sibling worktree ignored" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_git_mode_worktree_ignored "$GIT_SCAN_HEADING"
run_case "git mode: tracked unformatted file still armed" fail "modules/unformatted-regression/main.tf" m_git_mode_tracked_unformatted "$GIT_SCAN_HEADING"
run_case "git mode: broken git index does not fake a green fmt gate" fail "refusing to report a green gate" m_git_mode_scan_broken "$GIT_SCAN_HEADING"
run_case "git mode: empty index does not fake a green fmt gate" fail "refusing to report a green gate" m_git_mode_empty_index "$GIT_SCAN_HEADING"
run_case "git mode: exact S13 messy fixture allowlisted" pass "all tracked .tf files outside the S13 messy fixture are canonically formatted" m_git_mode_s13_only "$GIT_SCAN_HEADING"
run_case "git mode: adjacent S13 file is not allowlisted" fail "labs/day-2/13-static-analysis/messy/adjacent.tf" m_git_mode_adjacent_s13 "$GIT_SCAN_HEADING"
run_case "git mode: tracked-but-absent path is warned not silently passed" pass "absent from the worktree" m_git_mode_absent_tracked "$GIT_SCAN_HEADING"
run_case "day-2 lab unit tftest gated" pass "labs/day-2/99-lab-tftest-selftest: tofu test (plan/mock)" m_lab_tftest_clean
run_case "day-2 lab unit tftest failure armed" fail "labs/day-2/99-lab-tftest-selftest: tofu test" m_lab_tftest_fail
run_case "day-2 lab integration tftest deferred" pass "labs/day-2/99-lab-tftest-selftest: only integration test(s) — deferred to task verify:integration / CI verify-integration" m_lab_integration_only
run_case "day-1 lab workdir validated" pass "$DAY1_VALIDATE_DIR: validate" m_lab_validate_day1_clean "$VALIDATE_SCOPE_HEADING"
run_case "day-1 dangling reference armed" fail "$DAY1_VALIDATE_DIR: validate" m_lab_validate_day1_broken "$VALIDATE_SCOPE_HEADING"
run_case "day-3 nested stack dangling reference armed" fail "$DAY3_VALIDATE_DIR: validate" m_lab_validate_day3_nested_broken "$VALIDATE_SCOPE_HEADING"
run_case "day-2 nested workdir without tftest swept and armed" fail "$DAY2_SWEEP_NESTED_DIR: validate" m_day2_sweep_nested_broken "$VALIDATE_SCOPE_HEADING"
run_case "day-2 messy fixtures excluded by path prefix" pass "$DAY2_SWEEP_DIR: validate" m_day2_messy_excluded "$VALIDATE_SCOPE_HEADING"
run_case "init failure names BOTH provider-cache causes" fail "a COLD or partial provider cache" m_init_provider_cache_failure "no package for registry.opentofu.org" "another process writing .terraform/"
# `also` pins the SURVIVAL half: exit non-zero alone would also be produced by
# the silent death this case exists to forbid. Reaching the summary proves the
# gate reported and kept going.
# Three needles, all load-bearing and none substitutable:
#   'tofu version probe failed'    — the failure is NAMED
#   'simulated toolchain probe...' — tofu's OWN words are echoed. This is the
#                                    whole reason `2>/dev/null` was dropped;
#                                    without it, deleting the `info "tofu said:"`
#                                    echo leaves the case green.
#   'verify FAILED'                — the run SURVIVED to its summary. Exit
#                                    non-zero alone would also be produced by
#                                    the silent death this case forbids.
run_case "tofu version probe failure is named, not a silent death" fail "tofu version probe failed" m_tofu_version_probe_fails "simulated toolchain probe failure" "verify FAILED"
# The other half of the same fix: a noisy-but-HEALTHY probe must parse cleanly.
# Pinning only the failure path would let the parse regress to stderr-first.
run_case "noisy tofu stderr does not corrupt the parsed version" pass "tofu v1.10.3 (>= 1.9)" m_tofu_version_stderr_noise
run_case "§5 prose fake module ref ignored" pass "no modules/|examples/ references in labs (all HCL is scratch/inline) — nothing to drift-check yet" m_smoke_prose_fake_module
run_case "§5 HCL source missing module armed" fail "lab ref missing on disk: modules/does-not-exist" m_smoke_hcl_missing_source
run_case "§5 chdir/cd/DIR missing example armed" fail "lab ref missing on disk: examples/does-not-exist" m_smoke_chdir_missing_example
run_case "toolchain pin drift clean" pass "toolchain pins: all listed consumers match versions.env" m_pin_clean
run_case "toolchain pin drift Dockerfile armed" fail "pin drift: TOFU_VERSION (Dockerfile default) in setup/terratest/Dockerfile does not match versions.env" m_pin_drift
run_case "toolchain pin drift compose LocalStack armed" fail "pin drift: LOCALSTACK_VERSION (compose image) in docker-compose.yml does not match versions.env" m_pin_compose_drift
run_case "toolchain pin drift ci.yml armed" fail "pin drift: TOFU_VERSION (ci.yml setup-opentofu) in .github/workflows/ci.yml does not match versions.env" m_pin_ci_drift
run_case "version floor clean" pass "version floor: consumers state" m_floor_clean
run_case "version floor bootstrap skew armed" fail "floor skew: bootstrap MIN_TOFU in setup/bootstrap.sh does not state the floor" m_floor_bootstrap_skew
run_case "version floor ceiling armed" fail "demands >= 99.0, above the workshop floor" m_floor_ceiling

# --- release script self-tests (US-P-REL) --------------------------------------
# Run against the live repo (not the temp verify.sh copy): CI verify-unit invokes
# this script before verify.sh, so wiring here keeps release regressions red.
printf '\n### release script self-tests (US-P-REL) ###\n'
for rel_script in release-tag-guard-selftest.sh release-notes-flags-selftest.sh; do
  if bash "$REPO_ROOT/scripts/$rel_script"; then
    ok "release self-test: $rel_script"
  else
    bad "release self-test: $rel_script"
  fi
done

printf '\n### lab inventory (US-P-VALDOCS) ###\n'
if node --test "$REPO_ROOT/scripts/lab-inventory.test.mjs"; then
  ok "lab-inventory unit tests"
else
  bad "lab-inventory unit tests"
fi
if node "$REPO_ROOT/scripts/lab-inventory.mjs" --check; then
  ok "lab-inventory --check (matrix ↔ JSON)"
else
  bad "lab-inventory --check (matrix ↔ JSON)"
fi

# --- OpenTofu SEC-4 offline pin (US-P-PINS) ------------------------------------
# Offline name lock only — no curl/fetch. Live SHA256SUMS verify remains in
# setup/terratest/Dockerfile (scanned separately; Dockerfile not a shell remote
# surface). Do not reintroduce a live fetch here or in *.test.mjs quarantine.
printf '\n### OpenTofu SEC-4 offline pin ###\n'
if node --test "$REPO_ROOT/scripts/opentofu-sec4-pin.test.mjs"; then
  ok "OpenTofu SEC-4 offline pin matches versions.env + Dockerfile verify path"
else
  bad "OpenTofu SEC-4 offline pin failed"
fi

printf '\n### temp + lock hygiene sweeps (US-F-GATEHYG) ###\n'
check_all_case_tmp_cleaned "run_case" "$RUN_CASE_TMP_TRACE" 42
check_all_case_tmp_cleaned "lock scenarios" "$LOCK_SANDBOX_TMP_TRACE" 5
check_no_case_left_lock

printf '\n'
if [ "$fail_n" -eq 0 ]; then
  # Denominator is pass+fail, NOT pass twice. `%d/%d "$pass_n" "$pass_n"` is
  # tautological: it renders "46/46" no matter what, so it can never expose a
  # miscount. (It hid a double-increment: four call sites incremented fail_n
  # after a `bad` that already increments, so one failure there reported as two.)
  printf '  enforcement self-test PASSED — %d/%d cases OK.\n' "$pass_n" "$((pass_n + fail_n))"
  exit 0
else
  printf '  enforcement self-test FAILED — %d case(s) failed, %d OK.\n' "$fail_n" "$pass_n"
  exit 1
fi
