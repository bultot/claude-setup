#!/usr/bin/env zsh
# =============================================================================
# zshrc-lxc.sh — LXC-specific .zshrc for Claude Code VPS
# =============================================================================
# Deploy to ~/.zshrc on the LXC container.
# Sources the shared config from ~/.claude-shared/zshrc-shared.sh

# --- Machine identity (shown in Starship prompt and cc-dashboard) -----------
export CC_MACHINE="lxc"

# --- PATH -------------------------------------------------------------------
export PATH="$HOME/.claude-shared/bin:$HOME/.local/bin:$PATH"

# --- 1Password service account -----------------------------------------------
if [ -f "$HOME/.config/mcp-env/.op-token" ]; then
    export OP_SERVICE_ACCOUNT_TOKEN="$(cat "$HOME/.config/mcp-env/.op-token")"
fi

# --- Zsh plugins (apt paths) ------------------------------------------------
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# --- Zellij wrappers --------------------------------------------------------
# claude() and happy() auto-create Zellij sessions with layout files

claude() {
    local session_name="claude-$(basename "$PWD")"
    if [ -n "$ZELLIJ" ]; then
        command claude --dangerously-skip-permissions "$@"
    else
        if zellij list-sessions 2>/dev/null | grep -q "^${session_name}"; then
            zellij attach "$session_name"
        elif [ -f "$HOME/.config/zellij/layouts/claude.kdl" ]; then
            zellij --session "$session_name" --new-session-with-layout "$HOME/.config/zellij/layouts/claude.kdl"
        else
            zellij attach --create "$session_name"
        fi
    fi
}

happy() {
    local session_name="happy-$(basename "$PWD")"
    if [ -n "$ZELLIJ" ]; then
        command happy "$@"
    else
        if zellij list-sessions 2>/dev/null | grep -q "^${session_name}"; then
            zellij attach "$session_name"
        elif [ -f "$HOME/.config/zellij/layouts/happy.kdl" ]; then
            zellij --session "$session_name" --new-session-with-layout "$HOME/.config/zellij/layouts/happy.kdl"
        else
            zellij attach --create "$session_name"
        fi
    fi
}

# --- Source shared config (history, aliases, sessions(), dashboard) ----------
if [ -f "$HOME/.claude-shared/zshrc-shared.sh" ]; then
    source "$HOME/.claude-shared/zshrc-shared.sh"
fi
