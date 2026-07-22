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
    tflint:macOS) echo "brew install tflint" ;;
    tflint:Linux) echo "https://github.com/terraform-linters/tflint#installation" ;;
    trivy:macOS)  echo "brew install trivy" ;;
    trivy:Linux)  echo "https://trivy.dev/latest/getting-started/installation/" ;;
    checkov:macOS) echo "brew install checkov   # or: pipx install checkov" ;;
    checkov:Linux) echo "pipx install checkov" ;;
    conftest:macOS) echo "brew install conftest" ;;
    conftest:Linux) echo "https://www.conftest.dev/install/" ;;
    terramate:macOS) echo "brew install terramate" ;;
    terramate:Linux) echo "https://terramate.io/docs/cli/installation" ;;
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
    tflint) echo "tflint" ;;
    trivy) echo "trivy" ;;
    checkov) echo "checkov" ;;
    conftest) echo "conftest" ;;
    terramate) echo "terramate" ;;
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
    tflint) tflint --version 2>/dev/null | head -n1 | awk '{print $NF}' ;;
    trivy) trivy --version 2>/dev/null | head -n1 | awk '{print $NF}' ;;
    checkov) checkov --version 2>/dev/null | head -n1 ;;
    conftest) conftest --version 2>/dev/null | head -n1 | awk '{print $NF}' ;;
    terramate) terramate version 2>/dev/null | head -n1 | awk '{print $NF}' ;;
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
DAY_TOOLS="tflint trivy checkov conftest terramate"

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

# Required by their respective Day-2/3 labs. Always inspect the whole set so a
# single run reports every gap instead of failing at the first missing tool.
DAY_MISSING=""
heading "Day-2/3 lab tools"
for t in $DAY_TOOLS; do
  if have "$t"; then
    v="$(tool_version "$t" || true)"
    if [ -n "$v" ]; then
      ok "$(printf '%-10s %s' "$t" "$v")"
    else
      bad "$(printf '%-10s unusable' "$t")  (version probe failed)"
      DAY_MISSING="$DAY_MISSING $t"
    fi
  else
    bad "$(printf '%-10s missing' "$t")"
    DAY_MISSING="$DAY_MISSING $t"
  fi
done
echo

affected_labs() {
  case "$1" in
    tflint) echo "S13 static analysis" ;;
    trivy|checkov|conftest) echo "S14 security and policy scanners" ;;
    terramate) echo "S20-S25 Terramate labs" ;;
  esac
}

if [ -n "$DAY_MISSING" ]; then
  heading "Missing Day-2/3 tools"
  for t in $DAY_MISSING; do
    warn "$(printf '%-10s affects %s' "$t" "$(affected_labs "$t")")"
    info "$(printf '%-10s → %s' "$t" "$(install_hint "$t")")"
  done
  note "Other tools were still checked; install failures do not stop the report early."
  echo
fi

# ---------------------------------------------------------------------------
# Offer to install missing required tools
# ---------------------------------------------------------------------------
ALL_MISSING="$MISSING$DAY_MISSING"
if [ -n "$ALL_MISSING" ]; then
  heading "Install commands for missing tools"
  for t in $ALL_MISSING; do
    info "$(printf '%-7s → %s' "$t" "$(install_hint "$t")")"
  done
  echo

  # Homebrew installs require either interactive confirmation or the explicit
  # BOOTSTRAP_AUTO_INSTALL=always opt-in (useful for managed setup runners).
  SHOULD_INSTALL=0
  if [ "$PKG" = "brew" ]; then
    if [ "${BOOTSTRAP_AUTO_INSTALL:-ask}" = "always" ]; then
      SHOULD_INSTALL=1
    elif [ "${BOOTSTRAP_AUTO_INSTALL:-ask}" != "never" ] && [ "$INTERACTIVE" = 1 ] && \
      confirm "Attempt to install missing tools now with Homebrew?"; then
      SHOULD_INSTALL=1
    fi
  fi
  if [ "$SHOULD_INSTALL" = 1 ]; then
      for t in $ALL_MISSING; do
        [ "$t" = "pnpm" ] && { corepack enable && corepack prepare pnpm@latest --activate || true; continue; }
        heading "brew install $(brew_install_arg "$t")"
        # Word-splitting the brew args is intended (e.g. docker → "--cask docker").
        # shellcheck disable=SC2046
        brew install $(brew_install_arg "$t") || warn "Install of $t failed; run the command above manually."
      done
  else
    note "Skipped auto-install. Homebrew can install after confirmation; other platforms use the commands above."
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
DAY_STILL_MISSING=""
for t in $DAY_TOOLS; do
  if ! have "$t" || [ -z "$(tool_version "$t" || true)" ]; then
    DAY_STILL_MISSING="$DAY_STILL_MISSING $t"
  fi
done

if [ -z "$STILL_MISSING" ] && [ -z "$DAY_STILL_MISSING" ] && [ -z "$VERSION_WARN" ]; then
  ok "READY — all required tools present and meet minimum versions."
  ok "Day-2/3 tools ready — tflint, Trivy, Checkov, Conftest, and Terramate."
  note "Next: 'task lab:up' to start LocalStack, then 'task lab' for the guided runner."
  exit 0
else
  [ -n "$STILL_MISSING" ] && bad "Missing:$STILL_MISSING"
  [ -n "$DAY_STILL_MISSING" ] && bad "Missing Day-2/3 tools:$DAY_STILL_MISSING"
  [ -n "$VERSION_WARN" ]  && bad "Below minimum version:$VERSION_WARN"
  bad "NOT READY — resolve the items above and re-run: bash setup/bootstrap.sh"
  # Non-zero so CI / task preconditions can gate on readiness.
  exit 1
fi
