#!/usr/bin/env zsh
# =============================================================================
# zshrc-lxc.sh — LXC-specific .zshrc for Claude Code VPS
# =============================================================================
# Deploy to ~/.zshrc on the LXC container.
# Sources the shared config from ~/.claude-shared/zshrc-shared.sh

# --- Machine identity (shown in Starship prompt) ----------------------------
export CC_MACHINE="lxc"

# --- 1Password service account -----------------------------------------------
# Loaded from environment — set by systemd or .env file
# Do NOT hardcode the token here

# --- Zsh plugins (apt paths) ------------------------------------------------
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# --- Source shared config (history, aliases, wrappers, dashboard) ------------
if [ -f "$HOME/.claude-shared/zshrc-shared.sh" ]; then
    source "$HOME/.claude-shared/zshrc-shared.sh"
fi
