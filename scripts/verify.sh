#!/usr/bin/env bash
# scripts/verify.sh — the "tested workshop" gate.
#
# Unit lane (no Docker needed):
#   1. deps preflight (tofu present, version)
#   2. tofu fmt -check -recursive
#   3. per module/example that has *.tf: tofu init -backend=false + validate
#   4. per module/example that has *.tftest.hcl: tofu test (plan/mock lanes)
#   5. slide ↔ lab drift smoke check (modules/|examples/ paths cited in labs exist)
#   6. slide ↔ lab drift ENFORCEMENT (annotated ```hcl blocks diffed vs source)
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
  TOFU_VER="$(tofu version 2>/dev/null | head -n1 | awk '{print $2}')"
  if min_version "${TOFU_VER#v}" "1.8"; then
    pass "tofu ${TOFU_VER} (>= 1.8)"
  else
    fail "tofu ${TOFU_VER} is below the required 1.8"
  fi
else
  fail "tofu not found on PATH (install: brew install opentofu)"
  heading "Summary"
  bad "verify FAILED — tofu is required. $FAILURES failure(s)."
  exit 1
fi

# Collect module/example dirs that actually contain Terraform/OpenTofu code.
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
shopt -u nullglob

# ---------------------------------------------------------------------------
# 2. fmt -check (repo-wide; harmless on an empty tree)
# ---------------------------------------------------------------------------
heading "Formatting (tofu fmt -check -recursive)"
if tofu fmt -check -recursive >/dev/null 2>&1; then
  pass "all .tf files are canonically formatted"
else
  fail "unformatted files found — run 'task lab:fmt' (tofu fmt -recursive)"
  info "offending files:"
  tofu fmt -check -recursive 2>/dev/null | sed 's/^/    /' || true
fi

# ---------------------------------------------------------------------------
# 3 & 4. validate + test per code dir
# ---------------------------------------------------------------------------
heading "Validate & test"
if [ "${#CODE_DIRS[@]}" -eq 0 ]; then
  warn "no modules/* or examples/* with .tf files yet — nothing to validate."
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
    # LocalStack/Docker and belong to `task verify:integration` — exclude them
    # here and run each remaining file explicitly with -filter.
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
      info "$d: only integration test(s) — deferred to verify:integration"
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
#    We assert (b) and merely report (a), so the check is real but never fails
#    on legitimate scratch/inline HCL.
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
    # Extract every modules/... or examples/... path the lab references and
    # assert it exists (strip trailing punctuation/backticks the grep may grab).
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
    # -h: never prefix the filename onto the match (BSD/ugrep prefix even a
    # single file); trim trailing slashes so `dir/` and `dir` dedupe under sort.
    # Drop `<!-- source: PATH -->` annotation lines first: those paths are
    # already existence-checked and byte-diffed by the drift-enforcement section
    # above, and the `NN-modules/` workdir name would otherwise match the
    # `modules/` substring and manufacture phantom refs (e.g. modules/main.tf).
    done < <(grep -v '<!-- *source:' "$f" 2>/dev/null | grep -hoE '(modules|examples)/[A-Za-z0-9_./-]+' 2>/dev/null | sed 's:/*$::' | sort -u)
  done
  info "scanned ${#LAB_FILES[@]} lab file(s): ${HCL_BLOCKS} \`\`\`hcl block(s), ${CHECKED_REFS} shared-code reference(s)"
  if [ "$CHECKED_REFS" -eq 0 ]; then
    info "no modules/|examples/ references in labs (all HCL is scratch/inline) — nothing to drift-check yet"
  elif [ "$MISSING_REFS" -eq 0 ]; then
    pass "all shared-code references cited by labs exist on disk"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Slide ↔ lab drift ENFORCEMENT (annotated fenced blocks)
#    Contract (see AGENT.md · "Lab workdir & drift contract"): a fenced ```hcl
#    block may be tied to a tracked source file by an HTML comment marker on the
#    line immediately above the fence:
#
#        <!-- source: labs/fixtures/drift-demo/main.tf -->
#        ```hcl
#        ...exact file contents...
#        ```
#
#    Rules:
#      · annotated block  → its content is diffed against the named file;
#        drift OR a missing file FAILS the build, naming the file (criterion #2).
#      · unannotated block → ignored (only counted/warned) so partially-authored
#        labs never block unrelated lanes (criterion #3).
#      · a lab that has ```hcl block(s) but ZERO annotated ones → warn, not fail.
# ---------------------------------------------------------------------------
heading "Slide ↔ lab drift enforcement (annotated blocks)"
if [ "${#LAB_FILES[@]}" -eq 0 ]; then
  warn "no lab Markdown under labs/ yet — nothing to enforce. (pass)"
else
  ANNOTATED=0
  DRIFTED=0
  # awk emits one record per annotated block:
  #   \x01<source-path>\n<block-body...>\x02\n
  # It only arms on a `<!-- source: PATH -->` line that is IMMEDIATELY followed
  # by an opening ```hcl fence; a marker not hugging a fence is ignored. Using
  # \x01/\x02 sentinels avoids any collision with HCL/Markdown content. Written
  # with plain awk (not multiline `grep -o`) to stay portable on macOS/BSD.
  # NOTE (F1): the file is piped through `tr -d '\r'` BEFORE awk (see the loop
  # below), so a CRLF-authored lab can never disarm the selectors. The `\r?`
  # anchors here are belt-and-suspenders in case awk is ever fed raw bytes.
  extract='
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t\r]+$/,"",s); return s }
    /^[ \t]*<!--[ \t]*source:[ \t]*.*-->[ \t]*\r?$/ {
      p=$0
      sub(/^[ \t]*<!--[ \t]*source:[ \t]*/,"",p); sub(/[ \t]*-->[ \t]*\r?$/,"",p)
      pending=trim(p); next
    }
    pending!="" && /^[ \t]*```hcl[ \t]*\r?$/ { printf "\x01%s\n", pending; incode=1; pending=""; next }
    pending!="" { pending="" }   # marker not immediately hugging a fence → drop
    incode && /^[ \t]*```[ \t]*\r?$/ { printf "\x02\n"; incode=0; next }
    incode { print }
  '
  for f in "${LAB_FILES[@]}"; do
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
# 7. Deck tier consistency (slides.md ↔ slides-3day.md) + hide invariant
#    Each section import block in both content decks starts with a header:
#        # SNN · <Title> · <tier> · Day N
#    where tier ∈ {core, recommended, optional}, followed by `src:` and
#    `hide: <bool>`. Two invariants make "tiers do the cut" actually true:
#      (a) deck↔deck: for every SNN present in BOTH decks, the tier token is
#          identical across slides.md and slides-3day.md;
#      (b) 3-day cut: in slides-3day.md, `hide: true` ⟺ tier == optional.
#    We parse structurally in awk (split on '·', tier = field NF-1 so a future
#    '·' in a Title can't shift it; that also dodges the prior BSD `grep -o`
#    bug) and read ONLY the two tracked decks by literal path — never anything
#    under agent-context/ (gitignored/absent in CI). A section present in only
#    one deck is reported (warn) and skipped for the identity check, not failed.
# ---------------------------------------------------------------------------
heading "Deck tier consistency (slides.md ↔ slides-3day.md)"

# emit_sections DECK — one "SNN<TAB>tier<TAB>hide" line per section block.
# Header sets snn+tier; the FIRST `hide:` after a header carries that section's
# flag (blank "-" if a block has no hide line). '\r?' guards CRLF-authored decks.
emit_sections() {
  awk '
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t\r]+$/,"",s); return s }
    /^#[ \t]*S[0-9][0-9]+[ \t]*·/ {
      if (snn != "") { print snn "\t" tier "\t" (hide=="" ? "-" : hide) }
      n = split($0, f, /·/)
      snn = f[1]; sub(/^#[ \t]*/, "", snn); snn = trim(snn)
      tier = trim(f[n-1])          # ·<tier>· Day N  → tier is second-to-last
      hide = ""
      next
    }
    snn != "" && hide == "" && /^[ \t]*hide:[ \t]*/ {
      h = $0; sub(/^[ \t]*hide:[ \t]*/, "", h); hide = trim(h)
    }
    END { if (snn != "") print snn "\t" tier "\t" (hide=="" ? "-" : hide) }
  ' "$1"
}

if [ ! -f slides.md ] || [ ! -f slides-3day.md ]; then
  warn "one or both content decks missing (slides.md / slides-3day.md) — skipping tier check."
else
  declare -A SUPER_TIER=()
  declare -A CUT_TIER=()
  declare -A CUT_HIDE=()

  while IFS=$'\t' read -r snn tier _hide; do
    [ -n "$snn" ] && SUPER_TIER["$snn"]="$tier"
  done < <(emit_sections slides.md)

  while IFS=$'\t' read -r snn tier hide; do
    [ -n "$snn" ] || continue
    CUT_TIER["$snn"]="$tier"
    CUT_HIDE["$snn"]="$hide"
  done < <(emit_sections slides-3day.md)

  if [ "${#SUPER_TIER[@]}" -eq 0 ] || [ "${#CUT_TIER[@]}" -eq 0 ]; then
    warn "no '# SNN · … · <tier> · Day N' headers parsed from a deck — nothing to check. (pass)"
  else
    # (a) deck↔deck tier identity over the intersection of SNNs.
    TIER_MISMATCH=0
    CHECKED_SECTIONS=0
    for snn in "${!SUPER_TIER[@]}"; do
      if [ -z "${CUT_TIER[$snn]+set}" ]; then
        warn "tier check: $snn present in slides.md but not slides-3day.md — skipping identity for it"
        continue
      fi
      CHECKED_SECTIONS=$((CHECKED_SECTIONS + 1))
      if [ "${SUPER_TIER[$snn]}" != "${CUT_TIER[$snn]}" ]; then
        fail "tier drift: $snn is '${SUPER_TIER[$snn]}' in slides.md but '${CUT_TIER[$snn]}' in slides-3day.md"
        TIER_MISMATCH=$((TIER_MISMATCH + 1))
      fi
    done
    for snn in "${!CUT_TIER[@]}"; do
      if [ -z "${SUPER_TIER[$snn]+set}" ]; then
        warn "tier check: $snn present in slides-3day.md but not slides.md — skipping identity for it"
      fi
    done
    if [ "$CHECKED_SECTIONS" -gt 0 ] && [ "$TIER_MISMATCH" -eq 0 ]; then
      pass "tier tokens identical across both decks for all ${CHECKED_SECTIONS} shared section(s)"
    fi

    # (b) 3-day cut hide invariant: hide==true ⟺ tier==optional.
    HIDE_VIOLATION=0
    for snn in "${!CUT_TIER[@]}"; do
      tier="${CUT_TIER[$snn]}"
      hide="${CUT_HIDE[$snn]}"
      if [ "$tier" = "optional" ] && [ "$hide" != "true" ]; then
        fail "hide invariant: $snn is 'optional' but hide='$hide' in slides-3day.md (must be true)"
        HIDE_VIOLATION=$((HIDE_VIOLATION + 1))
      elif [ "$tier" != "optional" ] && [ "$hide" = "true" ]; then
        fail "hide invariant: $snn is '$tier' (not optional) but hide=true in slides-3day.md"
        HIDE_VIOLATION=$((HIDE_VIOLATION + 1))
      fi
    done
    if [ "$HIDE_VIOLATION" -eq 0 ]; then
      pass "slides-3day.md hide flags satisfy hide:true ⟺ optional (${#CUT_TIER[@]} section(s))"
    fi
  fi
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
