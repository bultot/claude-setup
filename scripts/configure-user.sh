#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# configure-user.sh — Create robin user, shell config, Zellij, aliases
# =============================================================================
#
#   THIS SCRIPT RUNS INSIDE LXC 200 (as root)
#
#   Usage:  bash configure-user.sh
#
#   What it does:
#     1. Creates user 'robin' with sudo access
#     2. Installs Zellij config + layouts (catppuccin-mocha, OSC 52 clipboard)
#     3. Installs bash aliases and auto-Zellij wrappers
#     4. Generates SSH key for GitHub
#
#   Idempotent: safe to run multiple times.
# =============================================================================

# --- Helpers -----------------------------------------------------------------

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m  $*"; exit 1; }

USERNAME="robin"
HOME_DIR="/home/${USERNAME}"

# --- Step 0: Root check -----------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
    fail "This script must be run as root"
fi

# --- Step 1: Create user -----------------------------------------------------

info "Setting up user '${USERNAME}'..."

if id "${USERNAME}" &>/dev/null; then
    ok "User '${USERNAME}' already exists"
else
    useradd -m -s /usr/bin/zsh "${USERNAME}"
    ok "User '${USERNAME}' created"
fi

# Ensure sudo access
if groups "${USERNAME}" | grep -q sudo; then
    ok "User already in sudo group"
else
    usermod -aG sudo "${USERNAME}"
    ok "Added '${USERNAME}' to sudo group"
fi

# Allow passwordless sudo (convenience for a personal dev box)
SUDOERS_FILE="/etc/sudoers.d/${USERNAME}"
if [[ ! -f "${SUDOERS_FILE}" ]]; then
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_FILE}"
    chmod 440 "${SUDOERS_FILE}"
    ok "Passwordless sudo configured"
else
    ok "Sudoers file already exists"
fi

# --- Step 2: Install Zellij config + layouts ---------------------------------

info "Installing Zellij configuration..."

ZELLIJ_DIR="${HOME_DIR}/.config/zellij"
LAYOUT_DIR="${ZELLIJ_DIR}/layouts"
mkdir -p "${ZELLIJ_DIR}" "${LAYOUT_DIR}"

# Embed Zellij config directly (self-contained when piped via SSH)
cat > "${ZELLIJ_DIR}/config.kdl" << 'ZELLIJ_EOF'
// Zellij config — Claude Code VPS (catppuccin-mocha, OSC 52, zsh)

copy_on_select true
copy_clipboard "system"
scroll_buffer_size 50000
mouse_mode true
simplified_ui true
theme "catppuccin-mocha"
session_serialization true
pane_frames true
default_shell "zsh"

keybinds {
    unbind "Ctrl h"
    shared_except "locked" {
        bind "Alt d" { Detach; }
        bind "Alt n" { NewPane; }
        bind "Alt 1" { GoToTab 1; }
        bind "Alt 2" { GoToTab 2; }
        bind "Alt 3" { GoToTab 3; }
    }
}
ZELLIJ_EOF

# Claude Code layout — auto-starts Claude with --dangerously-skip-permissions
cat > "${LAYOUT_DIR}/claude.kdl" << 'LAYOUT_EOF'
layout {
    pane command="zsh" {
        args "-ic" "command claude --dangerously-skip-permissions; exec zsh"
    }
}
LAYOUT_EOF

# Happy Coder layout — auto-starts Happy Coder
cat > "${LAYOUT_DIR}/happy.kdl" << 'LAYOUT_EOF'
layout {
    pane command="zsh" {
        args "-ic" "command happy; exec zsh"
    }
}
LAYOUT_EOF

chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}/.config"
ok "Zellij config and layouts installed"

# --- Step 3: Install bashrc additions ----------------------------------------

info "Installing bash aliases and auto-Zellij wrappers..."

MARKER="# --- CC Remote Workspace additions ---"
BASHRC="${HOME_DIR}/.bashrc"

if grep -qF "${MARKER}" "${BASHRC}" 2>/dev/null; then
    ok "Bashrc additions already present"
else
    cat >> "${BASHRC}" << 'BASHRC_EOF'

# --- CC Remote Workspace additions ---

# claude() — Run Claude Code inside a Zellij session (auto-creates if needed)
claude() {
    local dir_name
    dir_name=$(basename "$PWD")
    local session_name="claude-${dir_name}"

    if [ -n "$ZELLIJ" ]; then
        command claude "$@"
    else
        if zellij list-sessions 2>/dev/null | grep -q "^${session_name}"; then
            zellij attach "$session_name"
        else
            if [ -f "$HOME/.config/zellij/layouts/claude.kdl" ]; then
                zellij --session "$session_name" --new-session-with-layout "$HOME/.config/zellij/layouts/claude.kdl"
            else
                zellij attach --create "$session_name"
            fi
        fi
    fi
}

# happy() — Run Happy Coder inside a Zellij session (auto-creates if needed)
happy() {
    local dir_name
    dir_name=$(basename "$PWD")
    local session_name="happy-${dir_name}"

    if [ -n "$ZELLIJ" ]; then
        command happy "$@"
    else
        if zellij list-sessions 2>/dev/null | grep -q "^${session_name}"; then
            zellij attach "$session_name"
        else
            if [ -f "$HOME/.config/zellij/layouts/happy.kdl" ]; then
                zellij --session "$session_name" --new-session-with-layout "$HOME/.config/zellij/layouts/happy.kdl"
            else
                zellij attach --create "$session_name"
            fi
        fi
    fi
}

# sessions() — Show all Zellij and Happy Coder sessions
sessions() {
    echo "=== Zellij sessions ==="
    zellij list-sessions 2>/dev/null || echo "  (none)"
    echo ""
    echo "=== Happy Coder sessions ==="
    command happy sessions 2>/dev/null || echo "  (none or happy not installed)"
}

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# --- Machine identity (used by cc-dashboard and Starship) ---
export CC_MACHINE="lxc"
export PATH="$HOME/.claude-shared/bin:$HOME/.local/bin:$PATH"

# --- Welcome dashboard (shared with MacBook via Syncthing) ---
if [[ $- == *i* ]] && [[ -x "$HOME/.claude-shared/bin/cc-dashboard" ]]; then
    "$HOME/.claude-shared/bin/cc-dashboard" --welcome
fi

# --- End CC Remote Workspace additions ---
BASHRC_EOF

    ok "Bashrc additions installed"
fi

# --- Step 4: Generate SSH key for GitHub -------------------------------------

info "Setting up SSH key for GitHub..."

SSH_DIR="${HOME_DIR}/.ssh"
SSH_KEY="${SSH_DIR}/id_ed25519"

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [[ -f "${SSH_KEY}" ]]; then
    ok "SSH key already exists"
else
    ssh-keygen -t ed25519 -C "robin@claude-code" -f "${SSH_KEY}" -N ""
    ok "SSH key generated"
fi

chown -R "${USERNAME}:${USERNAME}" "${SSH_DIR}"

# --- Step 5: Fix locale warnings ---------------------------------------------

info "Fixing locale settings..."
locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true
ok "Locale configured"

# --- Step 6: Summary ---------------------------------------------------------

PUB_KEY=$(cat "${SSH_KEY}.pub")

echo ""
echo "============================================================"
echo "  LXC 200 — User Configuration Complete"
echo "============================================================"
echo ""
echo "  User:       ${USERNAME} (sudo, passwordless)"
echo "  Shell:      /usr/bin/zsh"
echo "  Zellij:     ~/.config/zellij/config.kdl (catppuccin-mocha, OSC 52)"
echo "  Layouts:    claude.kdl, happy.kdl"
echo "  Aliases:    claude, happy, sessions, ll, la"
echo ""
echo "  SSH public key (add to GitHub):"
echo "  ${PUB_KEY}"
echo ""
echo "  Next steps:"
echo "    1. Add the SSH key above to https://github.com/settings/keys"
echo "    2. Snapshot: pct snapshot 200 phase3-user-configured"
echo "    3. Run Phase 4: bash scripts/install-claude.sh"
echo ""
echo "============================================================"
