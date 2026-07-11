#!/usr/bin/env bash
# setup/lib.sh — shared, sourceable helpers for the workshop tooling.
#
# Provides:
#   - gum-or-plain styled output (auto-degrades when `gum` is absent)
#   - interactivity detection (non-interactive / CI safe)
#   - tool + version detection helpers
#
# This file is sourced, not executed, so it must NOT set global shell options
# (that is the caller's job). Keep it side-effect free on source.

# ---------------------------------------------------------------------------
# Capability detection
# ---------------------------------------------------------------------------

# have <cmd> — true if a command is on PATH.
have() { command -v "$1" >/dev/null 2>&1; }

# HAS_GUM / INTERACTIVE are computed once and cached.
if have gum; then HAS_GUM=1; else HAS_GUM=0; fi

# Interactive means: a TTY is attached to stdin AND we are not in CI.
# `[ ! -t 0 ]` (no TTY) or CI=true both force non-interactive mode.
if [ -t 0 ] && [ "${CI:-}" != "true" ]; then
  INTERACTIVE=1
else
  INTERACTIVE=0
fi

# ---------------------------------------------------------------------------
# Plain-text color fallbacks (only when stdout is a TTY and gum is missing)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'
  C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_DIM=$'\033[2m'
else
  C_RESET=''; C_BOLD=''; C_GREEN=''; C_RED=''; C_YELLOW=''; C_BLUE=''; C_DIM=''
fi

# ---------------------------------------------------------------------------
# Output helpers — each prefers gum, falls back to plain echo.
# ---------------------------------------------------------------------------

# title <text> — a boxed banner.
title() {
  if [ "$HAS_GUM" = 1 ]; then
    gum style --border rounded --border-foreground 212 --padding "0 2" \
      --margin "1 0" --bold "$*"
  else
    printf '\n%s== %s ==%s\n\n' "$C_BOLD" "$*" "$C_RESET"
  fi
}

# heading <text> — a section heading.
heading() {
  if [ "$HAS_GUM" = 1 ]; then
    gum style --bold --foreground 45 "» $*"
  else
    printf '%s» %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"
  fi
}

ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$C_RED"   "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
info() { printf '  %s·%s %s\n' "$C_DIM"    "$C_RESET" "$*"; }

# note <text> — a dim aside.
note() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# confirm <prompt> — yes/no gate.
#   - gum + interactive → gum confirm
#   - plain + interactive → read
#   - non-interactive → return 1 (treated as "no", never blocks CI)
confirm() {
  local prompt="${1:-Proceed?}"
  if [ "$INTERACTIVE" != 1 ]; then
    return 1
  fi
  if [ "$HAS_GUM" = 1 ]; then
    gum confirm "$prompt"
  else
    printf '%s [y/N] ' "$prompt"
    local reply
    read -r reply || return 1
    case "$reply" in
      [yY] | [yY][eE][sS]) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# choose <item...> — pick one from a list on stdout.
#   - gum + interactive → gum choose
#   - otherwise → first item (deterministic, CI-safe)
choose() {
  if [ "$#" -eq 0 ]; then return 1; fi
  if [ "$HAS_GUM" = 1 ] && [ "$INTERACTIVE" = 1 ]; then
    printf '%s\n' "$@" | gum choose
  else
    printf '%s\n' "$1"
  fi
}

# spin <title> -- <command...> — run a command with a spinner (gum) or plainly.
spin() {
  local title="$1"; shift
  [ "${1:-}" = "--" ] && shift
  if [ "$HAS_GUM" = 1 ] && [ "$INTERACTIVE" = 1 ]; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    info "$title"
    "$@"
  fi
}

# min_version <have> <min> — true if <have> >= <min> (dotted numeric compare).
min_version() {
  local have="$1" min="$2"
  # Strip a leading v and anything after the numeric core (e.g. "1.8.0-rc1").
  have="${have#v}"; have="${have%%[!0-9.]*}"
  min="${min#v}"
  [ "$(printf '%s\n%s\n' "$min" "$have" | sort -V | head -n1)" = "$min" ]
}
