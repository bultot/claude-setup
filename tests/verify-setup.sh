#!/usr/bin/env bash
set -uo pipefail
# Note: no set -e — checks are expected to fail and we handle it ourselves

# =============================================================================
# verify-setup.sh — Validate the complete CC Remote Workspace setup
# =============================================================================
#
#   Auto-detects whether it's running on the LXC or MacBook and runs the
#   appropriate checks. Run on BOTH machines for full verification.
#
#   Usage:
#     bash tests/verify-setup.sh          # auto-detect machine
#     bash tests/verify-setup.sh --lxc    # force LXC checks
#     bash tests/verify-setup.sh --mac    # force MacBook checks
#
#   Exit code: 0 if all checks pass, 1 if any fail
# =============================================================================

PASS=0
FAIL=0
WARN=0

pass()  { echo -e "\033[1;32m  ✓\033[0m $*"; ((PASS++)); }
fail()  { echo -e "\033[1;31m  ✗\033[0m $*"; ((FAIL++)); }
warn()  { echo -e "\033[1;33m  !\033[0m $*"; ((WARN++)); }
header() { echo -e "\n\033[1;36m━━━ $* ━━━\033[0m"; }

# --- Detect machine ----------------------------------------------------------

MODE="${1:-auto}"
if [[ "$MODE" == "auto" ]]; then
    if [[ "${CC_MACHINE:-}" == "lxc" ]] || [[ "$(hostname)" == "claude-code" ]]; then
        MODE="--lxc"
    else
        MODE="--mac"
    fi
fi

# =============================================================================
# LXC Checks
# =============================================================================

run_lxc_checks() {
    header "LXC 200 — System"

    # Hostname
    if [[ "$(hostname)" == "claude-code" ]]; then
        pass "Hostname is claude-code"
    else
        warn "Hostname is $(hostname) (expected: claude-code)"
    fi

    # OS
    if grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
        pass "Ubuntu 24.04"
    else
        fail "Not Ubuntu 24.04"
    fi

    # Memory
    local mem_mb
    mem_mb=$(free -m | awk '/Mem:/{print $2}')
    if [[ "$mem_mb" -ge 7000 ]]; then
        pass "Memory: ${mem_mb}MB (≥ 7GB)"
    else
        warn "Memory: ${mem_mb}MB (expected ≥ 7GB)"
    fi

    # TUN device
    if [[ -e /dev/net/tun ]]; then
        pass "/dev/net/tun exists"
    else
        fail "/dev/net/tun missing (Tailscale won't work)"
    fi

    header "LXC 200 — Network"

    # Tailscale
    if command -v tailscale &>/dev/null; then
        if tailscale status &>/dev/null; then
            local ts_ip
            ts_ip=$(tailscale ip -4 2>/dev/null || echo "unknown")
            pass "Tailscale connected (${ts_ip})"
        else
            fail "Tailscale installed but not connected"
        fi
    else
        fail "Tailscale not installed"
    fi

    # Tailscale SSH
    if tailscale status --json 2>/dev/null | grep -q '"SSH":true'; then
        pass "Tailscale SSH enabled"
    else
        warn "Tailscale SSH status unknown (check: tailscale status)"
    fi

    header "LXC 200 — Core Tools"

    # Node.js
    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version)
        if [[ "$node_ver" == v22.* ]]; then
            pass "Node.js ${node_ver}"
        else
            warn "Node.js ${node_ver} (expected v22.x)"
        fi
    else
        fail "Node.js not installed"
    fi

    # Zellij
    if command -v zellij &>/dev/null; then
        pass "Zellij $(zellij --version 2>/dev/null || echo 'installed')"
    else
        fail "Zellij not installed"
    fi

    # Zellij config
    if [[ -f "$HOME/.config/zellij/config.kdl" ]]; then
        pass "Zellij config exists"
    else
        fail "Zellij config missing (~/.config/zellij/config.kdl)"
    fi

    # Zellij layouts
    if [[ -f "$HOME/.config/zellij/layouts/claude.kdl" ]]; then
        pass "Zellij claude.kdl layout exists"
    else
        fail "Zellij claude.kdl layout missing"
    fi
    if [[ -f "$HOME/.config/zellij/layouts/happy.kdl" ]]; then
        pass "Zellij happy.kdl layout exists"
    else
        fail "Zellij happy.kdl layout missing"
    fi

    # Git
    if command -v git &>/dev/null; then
        pass "git $(git --version | awk '{print $3}')"
    else
        fail "git not installed"
    fi

    # gh CLI
    if command -v gh &>/dev/null; then
        pass "gh CLI $(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
    else
        warn "gh CLI not installed"
    fi

    header "LXC 200 — Claude Code"

    # Claude Code
    if command -v claude &>/dev/null; then
        local claude_ver
        claude_ver=$(claude --version 2>/dev/null || echo "installed")
        pass "Claude Code ${claude_ver}"
    else
        fail "Claude Code not installed"
    fi

    # Claude authentication
    if [[ -f "$HOME/.claude/.credentials.json" ]] || [[ -f "$HOME/.claude/credentials.json" ]]; then
        pass "Claude Code credentials file exists"
    else
        warn "Claude Code credentials file not found (may need: claude login)"
    fi

    # Happy Coder
    if command -v happy &>/dev/null; then
        pass "Happy Coder installed"
    else
        fail "Happy Coder not installed"
    fi

    header "LXC 200 — Syncthing & Config Sync"

    # Syncthing
    if pgrep -x syncthing &>/dev/null; then
        pass "Syncthing running"
    else
        fail "Syncthing not running (start: systemctl --user start syncthing)"
    fi

    # Symlinks
    if [[ -L "$HOME/.claude/CLAUDE.md" ]]; then
        pass "CLAUDE.md is symlinked to ~/.claude-shared/"
    else
        fail "CLAUDE.md is NOT a symlink (run: ~/.claude-shared/restore-symlinks.sh)"
    fi
    if [[ -L "$HOME/.claude/commands" ]]; then
        pass "commands/ is symlinked"
    else
        fail "commands/ is NOT a symlink"
    fi
    if [[ -L "$HOME/.claude/hooks" ]]; then
        pass "hooks/ is symlinked"
    else
        fail "hooks/ is NOT a symlink"
    fi

    # Shared scripts
    if [[ -x "$HOME/.claude-shared/bin/cc-dashboard" ]]; then
        pass "cc-dashboard script exists and is executable"
    else
        fail "cc-dashboard missing or not executable"
    fi
    if [[ -x "$HOME/.claude-shared/bin/cc-cache-refresh" ]]; then
        pass "cc-cache-refresh script exists and is executable"
    else
        fail "cc-cache-refresh missing or not executable"
    fi

    header "LXC 200 — Git Repos"

    local repo_count=0
    local repo_fail=0
    for repo_dir in "$HOME"/projects/personal/*/; do
        [[ -d "${repo_dir}.git" ]] || continue
        ((repo_count++))
        local repo_name
        repo_name=$(basename "$repo_dir")
        if git -C "$repo_dir" remote get-url origin &>/dev/null; then
            pass "Repo: ${repo_name}"
        else
            fail "Repo: ${repo_name} — no remote origin"
            ((repo_fail++))
        fi
    done
    if [[ $repo_count -eq 0 ]]; then
        warn "No git repos found in ~/projects/personal/"
    else
        [[ $repo_fail -eq 0 ]] && pass "All ${repo_count} repos have remotes"
    fi

    header "LXC 200 — 1Password"

    if command -v op &>/dev/null; then
        pass "1Password CLI installed"
    else
        warn "1Password CLI not installed"
    fi

    header "LXC 200 — Shell & Welcome"

    # CC_MACHINE
    if grep -q 'CC_MACHINE' "$HOME/.bashrc" 2>/dev/null || grep -q 'CC_MACHINE' "$HOME/.zshrc" 2>/dev/null; then
        pass "CC_MACHINE=lxc configured in shell rc"
    else
        warn "CC_MACHINE not set in shell rc (welcome dashboard won't detect LXC)"
    fi

    # Dashboard path (check both current PATH and shell rc)
    if echo "$PATH" | grep -q '.claude-shared/bin'; then
        pass "~/.claude-shared/bin is in PATH"
    elif grep -q 'claude-shared/bin' "$HOME/.bashrc" 2>/dev/null || grep -q 'claude-shared/bin' "$HOME/.zshrc" 2>/dev/null; then
        pass "~/.claude-shared/bin configured in shell rc (available on interactive login)"
    else
        warn "~/.claude-shared/bin not in PATH"
    fi

    header "LXC 200 — Happy Coder Service"

    if [[ -f "$HOME/.config/systemd/user/happy-coder.service" ]]; then
        pass "Happy Coder systemd service installed"
        if systemctl --user is-active happy-coder &>/dev/null; then
            pass "Happy Coder service is running"
        else
            warn "Happy Coder service installed but not running"
        fi
        if systemctl --user is-enabled happy-coder &>/dev/null; then
            pass "Happy Coder service enabled (auto-starts on boot)"
        else
            warn "Happy Coder service not enabled"
        fi
    else
        warn "Happy Coder systemd service not installed"
    fi

    # Linger
    if loginctl show-user "$(whoami)" --property=Linger 2>/dev/null | grep -q "yes"; then
        pass "User linger enabled (services run without login)"
    else
        warn "User linger not enabled (sudo loginctl enable-linger $(whoami))"
    fi
}

# =============================================================================
# MacBook Checks
# =============================================================================

run_mac_checks() {
    header "MacBook — SSH Config"

    # SSH config
    if grep -q "Host cc" "$HOME/.ssh/config" 2>/dev/null; then
        pass "SSH 'cc' host configured"
    else
        fail "SSH 'cc' host not in ~/.ssh/config"
    fi
    if grep -q "Host cc-raw" "$HOME/.ssh/config" 2>/dev/null; then
        pass "SSH 'cc-raw' host configured"
    else
        fail "SSH 'cc-raw' host not in ~/.ssh/config"
    fi

    header "MacBook — Shell"

    # CC Remote Workspace block in .zshrc
    if grep -q "CC Remote Workspace" "$HOME/.zshrc" 2>/dev/null; then
        pass "CC Remote Workspace block in .zshrc"
    else
        fail "CC Remote Workspace block missing from .zshrc"
    fi

    # Check aliases exist
    if type cc &>/dev/null 2>&1; then
        pass "cc alias/function available"
    else
        warn "cc not available (source ~/.zshrc first?)"
    fi

    header "MacBook — Tailscale"

    # macOS Tailscale may be a GUI app without CLI in PATH
    local ts_cmd=""
    if command -v tailscale &>/dev/null; then
        ts_cmd="tailscale"
    elif [[ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]]; then
        ts_cmd="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    fi

    if [[ -n "$ts_cmd" ]]; then
        if $ts_cmd status &>/dev/null; then
            pass "Tailscale connected"
        else
            # GUI app may be running even if CLI status fails
            if ping -c 1 -W 3 claude-code &>/dev/null; then
                pass "Tailscale connected (GUI app, no CLI)"
            else
                fail "Tailscale installed but not connected"
            fi
        fi
    else
        fail "Tailscale not installed"
    fi

    header "MacBook — LXC Reachability"

    if ping -c 1 -W 3 claude-code &>/dev/null; then
        pass "LXC reachable via Tailscale (claude-code)"
    else
        fail "LXC not reachable (ping claude-code failed)"
    fi

    # SSH connectivity
    if ssh -o ConnectTimeout=5 -o BatchMode=yes cc-raw "echo ok" 2>/dev/null | grep -q "ok"; then
        pass "SSH to LXC works (ssh cc-raw)"
    else
        fail "SSH to LXC failed"
    fi

    header "MacBook — Syncthing"

    if pgrep -x syncthing &>/dev/null; then
        pass "Syncthing running"
    else
        warn "Syncthing not running (brew services start syncthing)"
    fi

    # Check shared config exists
    if [[ -d "$HOME/.claude-shared" ]]; then
        pass "~/.claude-shared/ directory exists"
    else
        fail "~/.claude-shared/ missing"
    fi

    # Check symlinks
    if [[ -L "$HOME/.claude/CLAUDE.md" ]]; then
        pass "CLAUDE.md symlinked"
    else
        fail "CLAUDE.md not symlinked (run: ~/.claude-shared/restore-symlinks.sh)"
    fi

    # Dashboard
    if [[ -x "$HOME/.claude-shared/bin/cc-dashboard" ]]; then
        pass "cc-dashboard available"
    else
        fail "cc-dashboard missing"
    fi

    header "MacBook — Zellij on LXC"

    if ssh -o ConnectTimeout=5 -o BatchMode=yes cc-raw "command -v zellij" &>/dev/null; then
        pass "Zellij installed on LXC"
    else
        fail "Zellij not found on LXC"
    fi

    # Check Claude Code on LXC
    if ssh -o ConnectTimeout=5 -o BatchMode=yes cc-raw "command -v claude" &>/dev/null; then
        pass "Claude Code installed on LXC"
    else
        fail "Claude Code not found on LXC"
    fi
}

# =============================================================================
# Run
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════╗"
if [[ "$MODE" == "--lxc" ]]; then
    echo "║   CC Remote Workspace — LXC Verification        ║"
else
    echo "║   CC Remote Workspace — MacBook Verification     ║"
fi
echo "╚══════════════════════════════════════════════════╝"

if [[ "$MODE" == "--lxc" ]]; then
    run_lxc_checks
else
    run_mac_checks
fi

# --- Summary -----------------------------------------------------------------

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  \033[1;32m${PASS} passed\033[0m  \033[1;31m${FAIL} failed\033[0m  \033[1;33m${WARN} warnings\033[0m"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo -e "  \033[1;31mSome checks failed.\033[0m Fix the issues above and re-run."
    echo ""
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo -e "  \033[1;33mAll critical checks passed, but some warnings.\033[0m"
    echo ""
    exit 0
else
    echo ""
    echo -e "  \033[1;32mAll checks passed!\033[0m"
    echo ""
    exit 0
fi
