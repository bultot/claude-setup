#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# install-claude.sh — Install Claude Code and Happy Coder
# =============================================================================
#
#   THIS SCRIPT RUNS INSIDE LXC 200 (as robin user)
#
#   Usage:  bash install-claude.sh
#
#   What it does:
#     1. Installs Claude Code globally via npm
#     2. Installs Happy Coder globally via npm
#     3. Guides through Claude Code authentication (Max subscription)
#
#   Idempotent: safe to run multiple times — skips already-installed packages.
# =============================================================================

# --- Helpers -----------------------------------------------------------------

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m  $*"; exit 1; }

# --- Step 0: Prerequisites ---------------------------------------------------

if [[ "$(id -u)" -eq 0 ]]; then
    fail "Do not run as root. Run as 'robin' user (npm global installs use sudo internally)"
fi

if ! command -v node &>/dev/null; then
    fail "Node.js not found. Run provision.sh first."
fi

if ! command -v npm &>/dev/null; then
    fail "npm not found. Run provision.sh first."
fi

ok "Prerequisites met (node $(node --version), npm $(npm --version))"

# --- Step 1: Install Claude Code ---------------------------------------------

info "Checking Claude Code installation..."

if command -v claude &>/dev/null; then
    ok "Claude Code already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
else
    info "Installing Claude Code globally..."
    sudo npm install -g @anthropic-ai/claude-code
    ok "Claude Code installed ($(claude --version 2>/dev/null || echo 'check version manually'))"
fi

# --- Step 2: Install Happy Coder ---------------------------------------------

info "Checking Happy Coder installation..."

if command -v happy &>/dev/null; then
    ok "Happy Coder already installed ($(happy --version 2>/dev/null || echo 'version unknown'))"
else
    info "Installing Happy Coder globally..."
    sudo npm install -g happy-coder
    ok "Happy Coder installed"
fi

# --- Step 3: Authentication --------------------------------------------------

info ""
info "============================================================"
info "  Claude Code Authentication"
info "============================================================"
info ""
info "  Claude Code needs to authenticate with your Max subscription."
info "  This is an interactive step — it will open a URL you need"
info "  to visit in your browser."
info ""
info "  Run this command manually in the LXC:"
info ""
info "    claude login"
info ""
info "  Then open the URL it prints, log in with your Max account,"
info "  and confirm authentication."
info ""
info "  After authenticating, test with:"
info ""
info "    claude --print \"Say hello\""
info ""
info "============================================================"

# --- Step 4: Summary ---------------------------------------------------------

echo ""
echo "============================================================"
echo "  LXC 200 — Claude Code Installation Complete"
echo "============================================================"
echo ""
echo "  Claude Code:  $(command -v claude 2>/dev/null && claude --version 2>/dev/null || echo 'installed (run claude --version to check)')"
echo "  Happy Coder:  $(command -v happy 2>/dev/null && echo 'installed' || echo 'not found')"
echo ""
echo "  Remaining manual steps:"
echo "    1. Run: claude login"
echo "    2. Open the auth URL in your browser"
echo "    3. Test: claude --print \"Say hello\""
echo "    4. Snapshot: pct snapshot 200 phase4-claude-installed"
echo ""
echo "============================================================"
