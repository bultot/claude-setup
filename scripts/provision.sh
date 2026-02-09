#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# provision.sh — Install base packages, Node.js 22.x, and Tailscale
# =============================================================================
#
#   THIS SCRIPT RUNS INSIDE LXC 200 (not on the Proxmox host)
#
#   Usage:  bash provision.sh
#
#   What it does:
#     1. Updates system packages
#     2. Installs base tools (git, mosh, htop, etc.) + Zellij
#     3. Installs Node.js 22.x via NodeSource
#     4. Installs Tailscale and starts it with SSH enabled
#
#   Idempotent: safe to run multiple times — skips already-installed packages.
# =============================================================================

# --- Helpers -----------------------------------------------------------------

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m  $*"; exit 1; }

# --- Step 0: Root check -----------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
    fail "This script must be run as root"
fi

# --- Step 1: System update ---------------------------------------------------

info "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
ok "System packages updated"

# --- Step 2: Base packages ---------------------------------------------------

info "Installing base packages..."

BASE_PACKAGES=(
    curl
    wget
    git
    mosh
    htop
    build-essential
    python3
    python3-pip
    unzip
    jq
    openssh-server
    ca-certificates
    gnupg
    sudo
)

apt-get install -y -qq "${BASE_PACKAGES[@]}"
ok "Base packages installed"

# --- Step 3a: Zellij (terminal multiplexer) ----------------------------------

info "Checking Zellij installation..."

if command -v zellij &>/dev/null; then
    ok "Zellij already installed: $(zellij --version)"
else
    info "Installing Zellij from GitHub releases..."
    ZELLIJ_VERSION="v0.43.1"
    ARCH=$(dpkg --print-architecture)
    case "$ARCH" in
        amd64) ZELLIJ_ARCH="x86_64" ;;
        arm64) ZELLIJ_ARCH="aarch64" ;;
        *) fail "Unsupported architecture: $ARCH" ;;
    esac
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-${ZELLIJ_ARCH}-unknown-linux-musl.tar.gz" \
        | tar xz -C /usr/local/bin
    chmod +x /usr/local/bin/zellij
    ok "Zellij $(zellij --version) installed"
fi

# --- Step 3b: Node.js 22.x via NodeSource -----------------------------------

info "Checking Node.js installation..."

if command -v node &>/dev/null && node --version | grep -q "^v22\."; then
    ok "Node.js $(node --version) already installed"
else
    info "Installing Node.js 22.x via NodeSource..."

    # Add NodeSource GPG key and repository
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes

    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list

    apt-get update -qq
    apt-get install -y -qq nodejs

    ok "Node.js $(node --version) installed"
fi

info "Node.js version: $(node --version)"
info "npm version:     $(npm --version)"

# --- Step 4: Tailscale -------------------------------------------------------

info "Checking Tailscale installation..."

if command -v tailscale &>/dev/null; then
    ok "Tailscale already installed"
else
    info "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    ok "Tailscale installed"
fi

# Enable and start tailscaled
systemctl enable --now tailscaled 2>/dev/null || true

# Check if already connected
if tailscale status &>/dev/null; then
    ok "Tailscale already connected"
    tailscale status
else
    info "Starting Tailscale with SSH enabled..."
    info ""
    info "  ┌─────────────────────────────────────────────────────────┐"
    info "  │  Tailscale will print an auth URL below.               │"
    info "  │  Open it in your browser to authenticate this node.    │"
    info "  └─────────────────────────────────────────────────────────┘"
    info ""
    tailscale up --ssh
    ok "Tailscale connected"
fi

TS_IP=$(tailscale ip -4 2>/dev/null || echo "pending")
TS_HOSTNAME=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null | sed 's/\.$//' || echo "pending")

# --- Step 5: Summary --------------------------------------------------------

echo ""
echo "============================================================"
echo "  LXC 200 — Provisioning Complete"
echo "============================================================"
echo ""
echo "  System packages:  installed"
echo "  Node.js:          $(node --version)"
echo "  npm:              $(npm --version)"
echo "  git:              $(git --version)"
echo "  Zellij:           $(zellij --version)"
echo "  Tailscale IP:     ${TS_IP}"
echo "  Tailscale host:   ${TS_HOSTNAME}"
echo ""
echo "  Next steps:"
echo "    1. Verify Tailscale: ping ${TS_HOSTNAME} from MacBook"
echo "    2. Snapshot: pct snapshot 200 phase2-provisioned"
echo "    3. Run Phase 3: bash scripts/configure-user.sh"
echo ""
echo "============================================================"
