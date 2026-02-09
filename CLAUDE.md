# CC Remote Workspace

## Project Overview

This project sets up a persistent Claude Code environment on a Proxmox LXC container, accessible from any device (MacBook, iPhone, browser) via Happy Coder and SSH/Zellij over Tailscale. The goal is to completely decouple Claude Code from the MacBook, making it an always-on service on the home server.

## Owner

- **Name**: Robin Bultot
- **Proxmox host**: Already running with existing LXC/VM infrastructure including Home Assistant, Docker services
- **Tailscale**: Already installed on MacBook and iPhone
- **Claude subscription**: Max plan (all Claude Code usage must go through Max, never API tokens)
- **Primary devices**: MacBook (Ghostty terminal), iPhone (Happy Coder + Blink Shell)
- **Knowledge vault**: Obsidian

## Architecture

```
Proxmox Host
└── LXC 200: claude-code (Ubuntu 24.04)
    ├── Claude Code (authenticated with Max subscription)
    ├── Happy Coder CLI (session relay to phone/mac)
    ├── Zellij (session persistence, OSC 52 clipboard)
    ├── Tailscale (encrypted P2P mesh networking)
    ├── Git repos (cloned from GitHub)
    ├── MCP servers (API-based: GitHub, Salesforce, etc.)
    └── Node.js 22.x runtime

Access paths:
  iPhone  → Happy Coder app  → relay → VPS
  iPhone  → Blink Shell/Mosh → Tailscale → VPS
  MacBook → Happy Coder Mac  → relay → VPS
  MacBook → Ghostty SSH      → Tailscale → VPS
  Browser → Happy Coder web  → relay → VPS

Shared config (synced via Syncthing):
  ~/.claude-shared/
  ├── CLAUDE.md, commands/, hooks/  → symlinked into ~/.claude/
  ├── starship.toml                 → symlinked to ~/.config/starship.toml
  ├── zshrc-shared.sh               → sourced by machine-specific .zshrc
  └── bin/cc-dashboard, cc-cache-refresh  → welcome dashboard scripts
```

## Tech Stack

- **Container**: Proxmox LXC (Ubuntu 24.04), 4 cores, 8GB RAM, 32GB disk
- **Runtime**: Node.js 22.x
- **Networking**: Tailscale (with Tailscale SSH enabled)
- **Session persistence**: Zellij (with OSC 52 clipboard, layout files for Claude/Happy sessions)
- **Mobile bridge**: Happy Coder (npm: happy-coder)
- **Shell**: zsh with Starship prompt, shared config via Syncthing
- **VPN tunnel device**: /dev/net/tun (required for Tailscale in LXC)

## Project Structure

```
cc-remote-workspace/
├── CLAUDE.md                 # This file — project context for Claude Code
├── ROADMAP.md                # Migration phases and task tracking
├── STATUS.md                 # Project status (powers /status dashboard)
├── scripts/
│   ├── setup-lxc.sh          # Proxmox LXC creation script
│   ├── provision.sh          # Inside-LXC provisioning (packages, node, tailscale)
│   ├── configure-user.sh     # Create user, shell config, Zellij, aliases
│   ├── install-claude.sh     # Claude Code + Happy Coder install and auth
│   ├── migrate-repos.sh      # Clone repos from GitHub to VPS
│   ├── migrate-config.sh     # Copy Claude settings, MCP configs, API keys
│   └── setup-macbook.sh      # MacBook thin-client SSH config and aliases
├── config/
│   ├── bashrc-additions.sh    # Shell aliases and auto-Zellij wrappers
│   ├── zshrc-lxc.sh           # LXC-specific .zshrc (sets CC_MACHINE, sources shared)
│   ├── ssh-config             # MacBook ~/.ssh/config additions
│   ├── happy-coder.service    # Systemd user service for persistent Happy Coder
│   └── mcp-servers.json       # MCP server configuration template
├── docs/
│   ├── quick-reference.md     # Cheat sheet for daily use
│   └── troubleshooting.md     # Common issues and fixes
└── tests/
    └── verify-setup.sh        # Post-install verification checklist script
```

## Coding Guidelines

- All scripts must be idempotent (safe to run multiple times)
- Scripts should check for prerequisites before executing
- Use `set -euo pipefail` in all bash scripts
- Include clear echo statements so Robin can follow progress
- Sensitive values (API keys, tokens) must never be hardcoded — use environment variables or prompt interactively
- Scripts that run ON the Proxmox host vs INSIDE the LXC must be clearly separated and labeled
- Test each phase independently before moving to the next
- Create Proxmox snapshots at key milestones

## Key Constraints

- LXC must have `nesting=1,keyctl=1` features enabled for Docker compatibility and Tailscale
- `/dev/net/tun` must be mounted for Tailscale to work inside LXC
- Claude Code must authenticate with Max subscription (not API key)
- Happy Coder wraps `claude` — use `happy` command instead of `claude` for sessions that need mobile access
- MCP servers that depend on macOS-local resources cannot be migrated — flag these during migration
- The LXC should auto-start on Proxmox boot (`onboot: 1`)
- Zellij sessions persist across SSH disconnects — use `zellij attach --create` for reconnection

## Workflow: Planning in Claude Chat → Executing in Claude Code

When Robin plans features or tasks in Claude Desktop/iOS chat:
1. Claude chat outputs a structured task spec in markdown
2. Robin saves it to `ROADMAP.md` or `tasks/` in the project repo
3. Claude Code reads it via this CLAUDE.md import and executes

@import ROADMAP.md

## Quick Commands Reference

```bash
# From MacBook
ssh cc                          # Jump into default Zellij session on VPS
cc-sessions                     # List all running Zellij sessions
cc-project <name>               # Jump into specific project session
cc-claude [dir]                 # Start Claude Code in project
cc-happy [dir]                  # Start Happy Coder (phone relay)

# On VPS
happy                           # Start Claude Code with Happy Coder relay
claude                          # Start Claude Code in Zellij (auto-wrapped)
sessions                        # Show all Zellij + Happy sessions
zellij list-sessions            # List Zellij sessions
zellij attach <name>            # Attach to specific session

# Dashboard
cc-dashboard --welcome          # Quick welcome banner (used by .zshrc)
cc-dashboard --full             # Full status dashboard with service health
cc-dashboard --compact          # Mobile-friendly compact view
cc-cache-refresh                # Force-refresh dashboard cache

# Maintenance
pct snapshot 200 <name>         # Snapshot LXC (run on Proxmox host)
pct rollback 200 <name>         # Rollback LXC (run on Proxmox host)
```
