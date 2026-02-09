# Claude Setup (Archived)

## Project Overview

This project documented and automated a remote Claude Code setup: an always-on environment running on a Proxmox LXC container, accessible from MacBook, iPhone, or browser via SSH/Zellij and Happy Coder over Tailscale.

**Archived Feb 2026**: Retired in favor of running Claude Code locally on MacBook with remote sessions for multi-device access. The scripts and documentation below are kept as historical reference.

## Owner

- **Name**: Robin Bultot

## Coding Guidelines

- All scripts must be idempotent (safe to run multiple times)
- Use `set -euo pipefail` in all bash scripts
- Sensitive values (API keys, tokens) must never be hardcoded
