#!/usr/bin/env bash
# setup/lab.sh — gum-driven interactive lab runner.
#
# Flow:
#   1. Pick a lab from labs/**/*.md (gum choose; first entry when non-interactive).
#   2. Start LocalStack via `task lab:up` (gum spin).
#   3. Show the lab path and how to open it.
#   4. Offer a one-key panic reset: `task lab:down` + `tofu destroy` in the
#      lab's tracked workdir (sibling `labs/day-N/NN-topic/` per ADR 0009).
#
# Degrades gracefully with no gum and is safe in non-interactive shells.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=setup/lib.sh
. "$SCRIPT_DIR/lib.sh"

cd "$REPO_ROOT"

title "OpenTofu Workshop · Lab Runner"

# ---------------------------------------------------------------------------
# 1. Discover labs
# ---------------------------------------------------------------------------
shopt -s nullglob globstar
LABS=(labs/**/*.md)
shopt -u nullglob globstar

if [ "${#LABS[@]}" -eq 0 ]; then
  warn "No labs found under labs/ yet."
  note "Lab content is authored separately (labs/day-1, day-2, day-3)."
  note "Once labs exist as Markdown files, this runner will list them here."
  exit 0
fi

heading "Choose a lab"
if [ -n "${LAB_SH_LAB_CHOICE:-}" ]; then
  LAB_CHOICE="$LAB_SH_LAB_CHOICE"
else
  LAB_CHOICE="$(choose "${LABS[@]}")"
fi
[ -n "$LAB_CHOICE" ] || { warn "No lab selected."; exit 0; }
ok "Selected: $LAB_CHOICE"
echo

# ---------------------------------------------------------------------------
# 2. Start LocalStack
# ---------------------------------------------------------------------------
if [ "${LAB_SH_SKIP_UP:-0}" = "1" ]; then
  note "Skipping LocalStack start (LAB_SH_SKIP_UP)."
elif have task; then
  heading "Starting LocalStack"
  if spin "Bringing up LocalStack (task lab:up)…" -- task lab:up; then
    ok "LocalStack is up on http://localhost:4566"
  else
    bad "Failed to start LocalStack. Is Docker running? Try: task lab:up"
    exit 1
  fi
else
  warn "'task' not found — start LocalStack manually: docker compose up -d localstack"
fi
echo

# ---------------------------------------------------------------------------
# 3. Guide the learner
# ---------------------------------------------------------------------------
heading "Your lab"
info "Path: $REPO_ROOT/$LAB_CHOICE"
if have gum && [ "${HAS_GUM:-0}" = 1 ]; then
  note "Open it with:  gum pager < \"$LAB_CHOICE\"   (or your editor)"
else
  note "Open it in your editor, or:  less \"$LAB_CHOICE\""
fi
# Resolve the tracked workdir (ADR 0009 sibling dir, with capstone carve-out).
ACTIVE_WORKDIR=""
if ACTIVE_WORKDIR="$(lab_workdir_for "$LAB_CHOICE")"; then
  info "Working directory for this lab: $ACTIVE_WORKDIR"
  note "Run there:  cd $ACTIVE_WORKDIR && tofu init && tofu apply"
else
  note "No sibling workdir yet — follow the lab's own instructions."
fi
echo

# ---------------------------------------------------------------------------
# 4. Panic reset
# ---------------------------------------------------------------------------
if [ "$INTERACTIVE" = 1 ]; then
  heading "Panic reset"
  if confirm "Reset environment? (tofu destroy + stop LocalStack)"; then
    lab_panic_reset "$ACTIVE_WORKDIR"
    ok "Environment reset. Re-run 'task lab' to start again."
  else
    note "Leaving the environment running. Reset any time with 'task lab:down'."
  fi
else
  note "Non-interactive: skipping panic-reset prompt. Reset with 'task lab:down'."
fi
