# =============================================================================
# bashrc-additions.sh — Shell aliases and auto-Zellij wrappers for Claude Code
# =============================================================================

# --- Auto-Zellij wrappers ---------------------------------------------------

# claude() — Run Claude Code inside a Zellij session (auto-creates if needed)
claude() {
    local dir_name
    dir_name=$(basename "$PWD")
    local session_name="claude-${dir_name}"

    if [ -n "$ZELLIJ" ]; then
        # Already in Zellij — just run claude directly
        command claude "$@"
    else
        # Outside Zellij — create/attach session
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
        # Already in Zellij — just run happy directly
        command happy "$@"
    else
        # Outside Zellij — create/attach session
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
    happy sessions 2>/dev/null || echo "  (none or happy not installed)"
}

# --- Aliases -----------------------------------------------------------------

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

# --- End CC Remote Workspace additions ---------------------------------------
