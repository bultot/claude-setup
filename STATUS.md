# Claude Setup

**Status**: archived
**Last Updated**: 2026-02-09
**Progress**: Retired — replaced by MacBook-local + remote sessions

## Current Focus

Archived. Claude Code now runs locally on MacBook. Remote sessions (`&` prefix, `claude --remote`) used for phone access.

## Completed

- [x] Phase 1-8: Full remote LXC setup (documented, scripted, verified)
- [x] Syncthing config sync between MacBook and LXC
- [x] Rich welcome dashboard with activity, usage, suggestions
- [x] Disaster recovery script for full LXC rebuild
- [x] Migration to MacBook-local: config moved from ~/.claude-shared/ to ~/.claude/ (git-versioned)

## Pending

None — project archived.

## Blockers

None.

## Notes

- LXC 200 cleaned up, Claude/projects/config removed
- MacBook config migrated from ~/.claude-shared/ to ~/.claude/ (git-versioned, pushed to GitHub)
- Syncthing stopped for claude-shared folder
- Dashboard, shell config, and starship prompt updated for MacBook-only
