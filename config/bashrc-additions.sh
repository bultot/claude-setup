# =============================================================================
# bashrc-additions.sh — Shell aliases and auto-tmux wrappers for Claude Code
# =============================================================================

# --- Auto-tmux wrappers ------------------------------------------------------

# claude() — Run Claude Code inside a tmux session (auto-creates if needed)
claude() {
    local dir_name
    dir_name=$(basename "$PWD")
    local session_name="claude-${dir_name}"

    if [ -n "$TMUX" ]; then
        # Already in tmux — just run claude directly
        command claude "$@"
    else
        # Outside tmux — create/attach session, then run claude
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
        # Already in tmux — just run happy directly
        command happy "$@"
    else
        # Outside tmux — create/attach session, then run happy
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

# --- Aliases -----------------------------------------------------------------

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# --- End CC Remote Workspace additions ---------------------------------------
