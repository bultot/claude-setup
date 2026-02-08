#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# configure-user.sh — Create robin user, shell config, tmux, aliases
# =============================================================================
#
#   THIS SCRIPT RUNS INSIDE LXC 200 (as root)
#
#   Usage:  bash configure-user.sh
#
#   What it does:
#     1. Creates user 'robin' with sudo access
#     2. Installs tmux.conf (mobile-friendly)
#     3. Installs bash aliases and auto-tmux wrappers
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
    useradd -m -s /bin/bash "${USERNAME}"
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

# --- Step 2: Install tmux.conf -----------------------------------------------

info "Installing tmux configuration..."

# Embed tmux.conf directly (so this script is self-contained when piped via SSH)
cat > "${HOME_DIR}/.tmux.conf" << 'TMUX_EOF'
# =============================================================================
# tmux.conf — Mobile-friendly tmux config for Claude Code VPS
# =============================================================================

# --- General settings --------------------------------------------------------

# 256-color terminal
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# Large scrollback for long Claude Code outputs
set -g history-limit 50000

# Window/pane numbering from 1 (easier to reach on keyboard)
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Don't auto-rename windows (keep meaningful names)
setw -g automatic-rename off
set -g allow-rename off

# Faster escape time (better for vim/editors)
set -sg escape-time 10

# Enable focus events (useful for editors)
set -g focus-events on

# --- Mouse support (critical for mobile) ------------------------------------

set -g mouse on

# --- Mobile-friendly copy mode -----------------------------------------------

# Enter copy mode without prefix key — PageUp and F1
bind -n PageUp copy-mode -u
bind -n F1 copy-mode

# Vi-style keys in copy mode
setw -g mode-keys vi

# --- Status bar --------------------------------------------------------------

set -g status-position bottom
set -g status-interval 10

set -g status-style "bg=colour235,fg=colour248"

set -g status-left-length 30
set -g status-left "#[fg=colour39,bold] #h #[fg=colour245]│ "

set -g status-right-length 40
set -g status-right "#[fg=colour245]│ #[fg=colour248]%H:%M #[fg=colour245]│ #[fg=colour248]%d-%b"

# Window status
setw -g window-status-format " #I:#W "
setw -g window-status-current-format "#[fg=colour39,bold] #I:#W "

# --- Pane borders ------------------------------------------------------------

set -g pane-border-style "fg=colour238"
set -g pane-active-border-style "fg=colour39"

# --- Quality of life ---------------------------------------------------------

# Reload config with prefix-r
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Split panes with | and - (more intuitive)
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# New window in current path
bind c new-window -c "#{pane_current_path}"
TMUX_EOF

chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.tmux.conf"
ok "tmux.conf installed"

# --- Step 3: Install bashrc additions ----------------------------------------

info "Installing bash aliases and auto-tmux wrappers..."

MARKER="# --- CC Remote Workspace additions ---"
BASHRC="${HOME_DIR}/.bashrc"

if grep -qF "${MARKER}" "${BASHRC}" 2>/dev/null; then
    ok "Bashrc additions already present"
else
    cat >> "${BASHRC}" << 'BASHRC_EOF'

# --- CC Remote Workspace additions ---

# claude() — Run Claude Code inside a tmux session (auto-creates if needed)
claude() {
    local dir_name
    dir_name=$(basename "$PWD")
    local session_name="claude-${dir_name}"

    if [ -n "$TMUX" ]; then
        command claude "$@"
    else
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux attach-session -t "$session_name"
        else
            tmux new-session -d -s "$session_name" -c "$PWD"
            tmux send-keys -t "$session_name" "command claude $*" Enter
            tmux attach-session -t "$session_name"
        fi
    fi
}

# happy() — Run Happy Coder inside a tmux session (auto-creates if needed)
happy() {
    local dir_name
    dir_name=$(basename "$PWD")
    local session_name="happy-${dir_name}"

    if [ -n "$TMUX" ]; then
        command happy "$@"
    else
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux attach-session -t "$session_name"
        else
            tmux new-session -d -s "$session_name" -c "$PWD"
            tmux send-keys -t "$session_name" "command happy $*" Enter
            tmux attach-session -t "$session_name"
        fi
    fi
}

# sessions() — Show all tmux and happy sessions
sessions() {
    echo "=== tmux sessions ==="
    tmux list-sessions 2>/dev/null || echo "  (none)"
    echo ""
    echo "=== Happy Coder sessions ==="
    happy sessions 2>/dev/null || echo "  (none or happy not installed)"
}

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

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
echo "  Shell:      /bin/bash"
echo "  tmux:       ~/.tmux.conf installed (mobile-friendly)"
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
