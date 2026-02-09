# CC Remote Workspace — Troubleshooting

> Fixes for common issues with the always-on Claude Code environment.

---

## Tailscale

### "Connection refused" or "Host not found"

```bash
# MacBook: check Tailscale is running
ping claude-code

# LXC: check Tailscale status
ssh cc-raw "tailscale status"
```

**Fixes:**
- MacBook: Open the Tailscale app and ensure it's connected
- iPhone: Open Tailscale app → toggle on if disconnected
- LXC: `sudo tailscale up --ssh` (if expired or disconnected)

### Tailscale authentication expired

Tailscale keys expire periodically. If the LXC can't connect:

```bash
# On Proxmox host
pct enter 200
tailscale up --ssh
```

Follow the auth URL to re-authenticate the node.

---

## Zellij

### Session not found / "no sessions" after reboot

Zellij sessions survive SSH disconnects but **not LXC reboots**. After a reboot:

```bash
cc           # creates a new 'main' session automatically
cc-sessions  # verify sessions
```

### Stuck or frozen session

```bash
# List sessions from MacBook
ssh cc-raw "zellij list-sessions"

# Kill a stuck session
ssh cc-raw "zellij kill-session <name>"

# Kill all sessions
ssh cc-raw "zellij kill-all-sessions"
```

### Clipboard not working (OSC 52)

Select text in Zellij → should auto-copy to MacBook clipboard.

**Requirements:**
- Ghostty terminal on MacBook (supports OSC 52)
- Zellij config: `copy_on_select true` and `copy_clipboard "system"`
- No `copy_command` set (this overrides OSC 52)

**Verify config:**
```bash
ssh cc-raw "grep copy ~/.config/zellij/config.kdl"
```

Expected output:
```
copy_on_select true
copy_clipboard "system"
```

If `copy_command` is set, remove it — it pipes clipboard to a command instead of using OSC 52.

### Wrong theme / colors look off

```bash
ssh cc-raw "grep theme ~/.config/zellij/config.kdl"
```

Expected: `theme "catppuccin-mocha"`. If different, update the config.

---

## Claude Code

### Authentication expired

```bash
ssh cc-raw "claude login"
```

Follow the browser link to re-authenticate with your Max subscription.

### Claude Code updated and broke symlinks

After a Claude Code update, symlinks may be overwritten with regular files:

```bash
# Check if symlinks are intact
ssh cc-raw "ls -la ~/.claude/CLAUDE.md ~/.claude/commands ~/.claude/hooks"

# If any show as regular files instead of symlinks:
ssh cc-raw "~/.claude-shared/restore-symlinks.sh"
```

### "command not found: claude"

```bash
# Check Node.js and npm
ssh cc-raw "node --version && npm --version"

# Reinstall if needed
ssh cc-raw "npm install -g @anthropic-ai/claude-code"
```

---

## Happy Coder

### Not showing sessions on phone

1. Ensure Happy Coder is running on the LXC:
   ```bash
   ssh cc-raw "systemctl --user status happy-coder"
   ```

2. If not running, start it:
   ```bash
   ssh cc-raw "systemctl --user start happy-coder"
   ```

3. If you need to re-pair (new QR code):
   ```bash
   ssh -t cc-raw "screen -r happy-relay"
   # Scan QR code with phone
   # Ctrl-A D to detach
   ```

### Happy Coder service won't start

```bash
# Check logs
ssh cc-raw "journalctl --user -u happy-coder --no-pager -n 50"

# Reinstall service
ssh cc-raw "cp ~/projects/personal/claude-setup/config/happy-coder.service ~/.config/systemd/user/"
ssh cc-raw "systemctl --user daemon-reload"
ssh cc-raw "systemctl --user enable --now happy-coder"
```

### Phone can't connect (Tailscale)

Both iPhone and LXC must be on the same Tailscale network. Open the Tailscale app on your phone and ensure it's connected.

---

## Syncthing

### Config sync not working

```bash
# MacBook: check Syncthing is running
pgrep -x syncthing || echo "Not running — start with: brew services start syncthing"

# LXC: check Syncthing
ssh cc-raw "pgrep -x syncthing || echo 'Not running — start with: systemctl --user start syncthing'"

# Check sync status via web UI
# MacBook: http://127.0.0.1:8384
# LXC: ssh -L 8385:127.0.0.1:8384 cc-raw  →  http://127.0.0.1:8385
```

### Files not syncing

```bash
# Check Syncthing REST API for errors
ssh cc-raw "curl -s http://127.0.0.1:8384/rest/system/errors | python3 -m json.tool"
```

Common fixes:
- Restart Syncthing: `systemctl --user restart syncthing` (LXC) or `brew services restart syncthing` (Mac)
- Check folder config: the `claude-shared` folder should sync `~/.claude-shared/` on both machines

### Symlinks broken after sync

If files appear as regular files instead of symlinks:

```bash
# Run on the affected machine
~/.claude-shared/restore-symlinks.sh
```

---

## LXC Container

### LXC not starting after Proxmox reboot

```bash
# On Proxmox host
ssh beelink
pct status 200        # check status
pct start 200         # start if stopped
pct config 200 | grep onboot  # should show: onboot: 1
```

### Out of disk space

```bash
ssh cc-raw "df -h /"
```

If disk is full:
- Clean npm cache: `ssh cc-raw "npm cache clean --force"`
- Clean old Zellij sessions: `ssh cc-raw "rm -rf /tmp/zellij-*"`
- Check for large files: `ssh cc-raw "du -sh ~/projects/personal/*/"`

### Too many Proxmox snapshots (thin pool warning)

```bash
# On Proxmox host
ssh beelink
pct listsnapshot 200

# Remove old snapshots (keep last 3-5)
pct delsnapshot 200 <snapshot-name>
```

### Container resources need adjustment

```bash
# On Proxmox host — edit while running
pct set 200 -memory 16384    # increase to 16GB RAM
pct set 200 -cores 8         # increase to 8 cores
```

Disk resize requires the container to be stopped:
```bash
pct stop 200
pct resize 200 rootfs 64G
pct start 200
```

---

## Dashboard

### Welcome banner not showing

```bash
# Check the script exists and is executable
ls -la ~/.claude-shared/bin/cc-dashboard

# Test it manually
~/.claude-shared/bin/cc-dashboard --welcome

# Check it's called in your shell rc
grep cc-dashboard ~/.bashrc ~/.zshrc 2>/dev/null
```

### Dashboard shows stale data

```bash
# Force a cache refresh
~/.claude-shared/bin/cc-cache-refresh

# Check when cache was last refreshed
cat ~/.cache/cc-dashboard/last-refresh | xargs -I{} date -d @{} 2>/dev/null || \
  cat ~/.cache/cc-dashboard/last-refresh | xargs -I{} date -r {} 2>/dev/null
```

### Dashboard cache errors

```bash
# Clear the cache and rebuild
rm -rf ~/.cache/cc-dashboard
mkdir -p ~/.cache/cc-dashboard
~/.claude-shared/bin/cc-cache-refresh
```

---

## Verification

Run the verification script to check the entire setup:

```bash
# On MacBook
bash tests/verify-setup.sh

# On LXC (via SSH)
ssh cc-raw "bash -s" < tests/verify-setup.sh
```

The script reports pass/fail/warning for each component and gives a summary at the end.
