#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# setup-macbook.sh — Configure MacBook as thin client for CC Remote Workspace
# =============================================================================
#
#   THIS SCRIPT RUNS ON THE MACBOOK (not on the Proxmox host or VPS)
#
#   What it does:
#     1. Appends SSH config for instant 'ssh cc' access (with backup)
#     2. Adds shell aliases/functions to ~/.zshrc (sources shared config)
#     3. Sets up Starship config symlink
#     4. Prints Happy Coder setup instructions
#
#   Idempotent: safe to run multiple times — skips already-installed sections.
# =============================================================================

# --- Constants ---------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
SSH_CONFIG="${HOME}/.ssh/config"
ZSHRC="${HOME}/.zshrc"
MARKER_START="# --- CC Remote Workspace ---"
MARKER_END="# --- End CC Remote Workspace ---"
VPS_HOST="claude-code"
VPS_USER="robin"

# --- Helpers -----------------------------------------------------------------

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m  $*"; exit 1; }

# Check if a block is already installed (by looking for the start marker)
is_installed() {
    local file="$1"
    [[ -f "${file}" ]] && grep -qF "${MARKER_START}" "${file}"
}

# =============================================================================
# Step 1: SSH Config
# =============================================================================

info "Setting up SSH config..."

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

if is_installed "${SSH_CONFIG}"; then
    ok "SSH config already contains CC Remote Workspace block — skipping"
else
    # Back up existing config
    if [[ -f "${SSH_CONFIG}" ]]; then
        cp "${SSH_CONFIG}" "${SSH_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
        ok "Backed up existing SSH config"
    fi

    # Append our config
    {
        echo ""
        echo "${MARKER_START}"
        cat "${CONFIG_DIR}/ssh-config"
        echo "${MARKER_END}"
    } >> "${SSH_CONFIG}"

    chmod 600 "${SSH_CONFIG}"
    ok "SSH config installed — 'ssh cc' now available"
fi

# =============================================================================
# Step 2: Shell Aliases & Functions
# =============================================================================

info "Setting up shell aliases..."

if is_installed "${ZSHRC}"; then
    ok "Shell aliases already installed in ${ZSHRC} — skipping"
else
    # Back up existing zshrc
    if [[ -f "${ZSHRC}" ]]; then
        cp "${ZSHRC}" "${ZSHRC}.bak.$(date +%Y%m%d%H%M%S)"
        ok "Backed up existing .zshrc"
    fi

    cat >> "${ZSHRC}" << 'ALIASES'

# --- CC Remote Workspace ---

# Source shared shell config (history, completion, Starship, aliases, wrappers, dashboard)
# Synced via Syncthing between MacBook and LXC
if [ -f "$HOME/.claude-shared/zshrc-shared.sh" ]; then
    source "$HOME/.claude-shared/zshrc-shared.sh"
fi

# MacBook-specific: Remote session management (LXC 200 via Tailscale)
alias cc="ssh cc"

cc-sessions() {
    ssh cc-raw "zellij list-sessions 2>/dev/null" || echo "No active sessions (or VPS unreachable)"
}

cc-project() {
    local name="${1:?Usage: cc-project <session-name>}"
    ssh -t cc-raw "zellij attach --create ${name}"
}

cc-claude() {
    local dir="${1:-}"
    if [[ -n "${dir}" ]]; then
        ssh -t cc-raw "cd ~/projects/${dir} && bash -ic 'claude'"
    else
        ssh -t cc-raw "bash -ic 'claude'"
    fi
}

cc-happy() {
    local dir="${1:-}"
    if [[ -n "${dir}" ]]; then
        ssh -t cc-raw "cd ~/projects/${dir} && bash -ic 'happy'"
    else
        ssh -t cc-raw "bash -ic 'happy'"
    fi
}

# --- End CC Remote Workspace ---
ALIASES

    ok "Shell aliases installed in ${ZSHRC}"
fi

# =============================================================================
# Step 3: Starship Config Symlink
# =============================================================================

info "Setting up Starship config symlink..."

STARSHIP_SOURCE="${HOME}/.claude-shared/starship.toml"
STARSHIP_LINK="${HOME}/.config/starship.toml"

if [[ -L "${STARSHIP_LINK}" ]]; then
    ok "Starship config already symlinked"
elif [[ -f "${STARSHIP_SOURCE}" ]]; then
    mkdir -p "${HOME}/.config"
    if [[ -f "${STARSHIP_LINK}" ]]; then
        cp "${STARSHIP_LINK}" "${STARSHIP_LINK}.bak.$(date +%Y%m%d%H%M%S)"
        rm -f "${STARSHIP_LINK}"
    fi
    ln -s "${STARSHIP_SOURCE}" "${STARSHIP_LINK}"
    ok "Starship config symlinked to shared config"
else
    warn "Starship shared config not found at ${STARSHIP_SOURCE} — skipping"
fi

# =============================================================================
# Step 4: Summary & Happy Coder Instructions
# =============================================================================

echo ""
echo "============================================================"
echo "  MacBook Thin Client — Configured"
echo "============================================================"
echo ""
echo "  Available commands (after: source ~/.zshrc):"
echo ""
echo "    cc                    SSH into VPS Zellij session"
echo "    cc-sessions           List active Zellij sessions on VPS"
echo "    cc-project <name>     Jump into named project session"
echo "    cc-claude [dir]       Start Claude Code on VPS"
echo "    cc-happy [dir]        Start Happy Coder on VPS"
echo ""
echo "  Prerequisites:"
echo "    - Tailscale running on MacBook (VPS reachable as '${VPS_HOST}')"
echo "    - Zellij + Claude Code installed on VPS"
echo "    - SSH key added to VPS (or Tailscale SSH enabled)"
echo ""
echo "------------------------------------------------------------"
echo "  Happy Coder Setup (Mac App)"
echo "------------------------------------------------------------"
echo ""
echo "  1. Install Happy Coder from the Mac App Store"
echo "     https://apps.apple.com/app/happy-coder/id6742500519"
echo ""
echo "  2. On the VPS, start a Happy Coder session:"
echo "     ssh cc-raw 'happy'"
echo ""
echo "  3. Scan the QR code shown in terminal with the"
echo "     Happy Coder app on your Mac or iPhone"
echo ""
echo "  4. Once paired, sessions appear in the Happy Coder app"
echo "     and you can interact with Claude Code from any device"
echo ""
echo "------------------------------------------------------------"
echo "  Quick Test"
echo "------------------------------------------------------------"
echo ""
echo "  Run these to verify (after sourcing ~/.zshrc):"
echo ""
echo "    source ~/.zshrc"
echo "    cc-sessions           # should list sessions (or say none)"
echo "    cc                    # should drop into Zellij on VPS"
echo ""
echo "============================================================"
