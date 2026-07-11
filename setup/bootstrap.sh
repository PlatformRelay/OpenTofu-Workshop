#!/usr/bin/env bash
# setup/bootstrap.sh — idempotent installer/verifier for the workshop toolchain.
#
# Detects the host OS, checks every tool the workshop needs, prints a styled
# status table, and (only with explicit confirmation) offers to install what is
# missing. Degrades gracefully with no `gum` and in non-interactive / CI shells.
#
# Safe to run repeatedly. Installs nothing without your say-so.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/lib.sh
. "$SCRIPT_DIR/lib.sh"

# ---------------------------------------------------------------------------
# Minimum versions
# ---------------------------------------------------------------------------
MIN_TOFU="1.8"
MIN_NODE="20"

# ---------------------------------------------------------------------------
# OS / package-manager detection
# ---------------------------------------------------------------------------
OS="unknown"; PKG=""
case "$(uname -s)" in
  Darwin) OS="macOS"; have brew && PKG="brew" ;;
  Linux)
    OS="Linux"
    if   have apt-get; then PKG="apt"
    elif have dnf;     then PKG="dnf"
    elif have pacman;  then PKG="pacman"
    elif have brew;    then PKG="brew"
    fi
    ;;
esac

# install_hint <tool> — echo the exact platform-appropriate install command.
install_hint() {
  local tool="$1"
  case "$tool:$OS" in
    tofu:macOS)   echo "brew install opentofu" ;;
    tofu:Linux)   echo "curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method standalone" ;;
    docker:macOS) echo "brew install --cask docker   # or: https://docs.docker.com/desktop/" ;;
    docker:Linux) echo "curl -fsSL https://get.docker.com | sh" ;;
    pnpm:*)       echo "corepack enable && corepack prepare pnpm@latest --activate   # or: npm i -g pnpm" ;;
    node:macOS)   echo "brew install node" ;;
    node:Linux)   echo "https://github.com/nvm-sh/nvm  (nvm install --lts)" ;;
    task:macOS)   echo "brew install go-task/tap/go-task" ;;
    task:Linux)   echo "sh -c \"\$(curl -fsSL https://taskfile.dev/install.sh)\" -- -d -b ~/.local/bin" ;;
    gum:macOS)    echo "brew install gum" ;;
    gum:Linux)    echo "https://github.com/charmbracelet/gum#installation" ;;
    awslocal:*)   echo "pipx install awscli-local   # or: pip install awscli-local" ;;
    aws:macOS)    echo "brew install awscli" ;;
    aws:Linux)    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" ;;
    *)            echo "(see the tool's documentation for $OS)" ;;
  esac
}

# brew_install_arg <tool> — the `brew install ...` argument for auto-install.
brew_install_arg() {
  case "$1" in
    tofu)   echo "opentofu" ;;
    docker) echo "--cask docker" ;;
    node)   echo "node" ;;
    task)   echo "go-task/tap/go-task" ;;
    aws)    echo "awscli" ;;
    *)      echo "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Version probes
# ---------------------------------------------------------------------------
tool_version() {
  case "$1" in
    tofu)   tofu version 2>/dev/null | head -n1 | awk '{print $2}' ;;
    docker) docker --version 2>/dev/null | awk '{gsub(/,/,"",$3); print $3}' ;;
    pnpm)   pnpm --version 2>/dev/null ;;
    node)   node --version 2>/dev/null ;;
    task)   task --version 2>/dev/null | awk '{print $3}' ;;
    gum)    gum --version 2>/dev/null | awk '{print $NF}' ;;
    awslocal) awslocal --version 2>/dev/null | head -n1 ;;
    aws)    aws --version 2>/dev/null | awk '{print $1}' ;;
    *)      echo "" ;;
  esac
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
title "OpenTofu Workshop · Toolchain Bootstrap"
heading "Environment"
info "OS:              $OS"
info "Package manager: ${PKG:-none detected}"
info "gum:             $([ "$HAS_GUM" = 1 ] && echo present || echo "absent (plain output)")"
info "Mode:            $([ "$INTERACTIVE" = 1 ] && echo interactive || echo "non-interactive (report only)")"
echo

# Required tools gate the workshop; optional ones are nice-to-have.
REQUIRED="tofu docker pnpm node task"
OPTIONAL="gum awslocal aws"

MISSING=""       # required tools that are absent
VERSION_WARN=""  # tools present but below minimum

heading "Required tools"
for t in $REQUIRED; do
  if have "$t"; then
    v="$(tool_version "$t")"
    case "$t" in
      tofu)
        if min_version "$v" "$MIN_TOFU"; then ok "tofu   ${v:-?}  (>= $MIN_TOFU)"
        else bad "tofu   ${v:-?}  (needs >= $MIN_TOFU)"; VERSION_WARN="$VERSION_WARN tofu"; fi ;;
      node)
        if min_version "$v" "$MIN_NODE"; then ok "node   ${v:-?}  (>= $MIN_NODE)"
        else bad "node   ${v:-?}  (needs >= $MIN_NODE)"; VERSION_WARN="$VERSION_WARN node"; fi ;;
      *) ok "$(printf '%-6s %s' "$t" "${v:-present}")" ;;
    esac
  else
    bad "$(printf '%-6s missing' "$t")"
    MISSING="$MISSING $t"
  fi
done
echo

heading "Optional tools"
for t in $OPTIONAL; do
  if have "$t"; then ok "$(printf '%-9s %s' "$t" "$(tool_version "$t")")"
  else warn "$(printf '%-9s missing' "$t")   $(install_hint "$t")"; fi
done
echo

# awslocal OR aws is enough for LocalStack interaction; note if neither.
if ! have awslocal && ! have aws; then
  warn "Neither awslocal nor aws found — install one to poke LocalStack (awslocal recommended)."
  echo
fi

# ---------------------------------------------------------------------------
# Offer to install missing required tools
# ---------------------------------------------------------------------------
if [ -n "$MISSING" ]; then
  heading "Install commands for missing required tools"
  for t in $MISSING; do
    info "$(printf '%-7s → %s' "$t" "$(install_hint "$t")")"
  done
  echo

  # Only auto-install when interactive, brew is available, and the user agrees.
  if [ "$INTERACTIVE" = 1 ] && [ "$PKG" = "brew" ]; then
    if confirm "Attempt to install missing tools now with Homebrew?"; then
      for t in $MISSING; do
        [ "$t" = "pnpm" ] && { corepack enable && corepack prepare pnpm@latest --activate || true; continue; }
        heading "brew install $(brew_install_arg "$t")"
        # Word-splitting the brew args is intended (e.g. docker → "--cask docker").
        # shellcheck disable=SC2046
        brew install $(brew_install_arg "$t") || warn "Install of $t failed; run the command above manually."
      done
    else
      note "Skipped auto-install. Copy the commands above to install manually."
    fi
  else
    note "Auto-install is available only in an interactive shell with Homebrew. Run the commands above manually."
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Final verdict
# ---------------------------------------------------------------------------
heading "Summary"
# Re-check required tools after any install attempt.
STILL_MISSING=""
for t in $REQUIRED; do have "$t" || STILL_MISSING="$STILL_MISSING $t"; done

if [ -z "$STILL_MISSING" ] && [ -z "$VERSION_WARN" ]; then
  ok "READY — all required tools present and meet minimum versions."
  note "Next: 'task lab:up' to start LocalStack, then 'task lab' for the guided runner."
  exit 0
else
  [ -n "$STILL_MISSING" ] && bad "Missing:$STILL_MISSING"
  [ -n "$VERSION_WARN" ]  && bad "Below minimum version:$VERSION_WARN"
  bad "NOT READY — resolve the items above and re-run: bash setup/bootstrap.sh"
  # Non-zero so CI / task preconditions can gate on readiness.
  exit 1
fi
