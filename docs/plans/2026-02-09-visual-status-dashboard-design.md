# Visual Status Dashboard Design

## Goal

Upgrade the `/status` skill to produce a visually rich, scannable dashboard using unicode progress bars, grouping headers, and clear visual hierarchy. Pure markdown + unicode — no ANSI, no shell dependencies.

## Rendering Context

Claude Code renders assistant text through CommonMark in a monospace terminal font. ANSI escape codes are stripped. Available tools: markdown formatting (headers, bold, code blocks, tables), unicode characters (box drawing, block elements, geometric shapes), and standard ASCII.

## Compact View (default)

The default view optimizes for quick scanning. Projects are grouped by status and sorted by progress within each group (highest first).

```
# ─── Status Dashboard ─── 2026-02-09

## ▸ Active

  claude-setup        ████████████████████████████░░  98%
  reminders-ai        ████████████████████████░░░░░░  80%
  homeserver          ████████████░░░░░░░░░░░░░░░░░░  40%
  career-os           ████████████░░░░░░░░░░░░░░░░░░  40%
  expensify-os        ████████████░░░░░░░░░░░░░░░░░░  40%
  inbox-co-pilot      ██████░░░░░░░░░░░░░░░░░░░░░░░░  20%
  auto-trading-bot    ███░░░░░░░░░░░░░░░░░░░░░░░░░░░  10%  ⚠ 1 dirty

## ▸ New

  talent-growth-agt   ███░░░░░░░░░░░░░░░░░░░░░░░░░░░  10%
  midi-controller     ███░░░░░░░░░░░░░░░░░░░░░░░░░░░  10%

## ▸ Stable

  homeassistant       █████████████████████████░░░░░░  85%
  bultot.nl           █████████████████████████░░░░░░  85%

## ▸ Done

  todo-voice          ██████████████████████████████  100%

────────────────────────────────────────
● Commit auto-trading-bot, then push claude-setup across the line.
```

### Layout Rules

- Bar width: 30 characters (fills with `█` and `░`)
- Project name column: 20 characters, left-aligned, truncated with ellipsis if needed
- Percentage: 4 characters, right-aligned after bar
- Flags after percentage: `⚠ N dirty`, `⏸ stale` (last commit >7 days)
- Groups sorted: Active > New > Stable > Done
- Within groups: sorted by percentage descending
- Group headers use `## ▸` prefix
- Bottom separator: `─` repeated 40 chars
- Single recommendation line with `●` bullet

### Flag Icons

| Condition | Icon | Example |
|-----------|------|---------|
| Dirty files | ⚠ | `⚠ 3 dirty` |
| Stale (>7 days) | ⏸ | `⏸ stale` |
| No STATUS.md | ◌ | `◌ needs STATUS.md` |
| No git | ○ | `○ no git` |

## Full View (`/status full`)

Same visual header and progress bars, then an expanded detail block per active project.

```
# ─── Status Dashboard ─── 2026-02-09

## ▸ Active

  claude-setup        ████████████████████████████░░  98%
  reminders-ai        ████████████████████████░░░░░░  80%
  ...

## ▸ New
  ...

## ▸ Stable
  ...

## ▸ Done
  ...

────────────────────────────────────────

### claude-setup — 98%
Phase 8 complete, disaster recovery added. Burn-in pending.
- [ ] 1-week burn-in: use VPS exclusively
- [ ] Pair Happy Coder on iPhone
- [ ] Test MCP servers end-to-end on LXC
Blockers: None

### homeserver — 40%
Proxmox + Docker-in-LXC, 7 services running.
- [ ] Caddy HTTPS with Cloudflare DNS challenge
- [ ] Uptime Kuma monitors
- [ ] Replace Nabu Casa Cloud
Blockers: None (RAM maxed at 12 GB)

...

────────────────────────────────────────
● Commit auto-trading-bot, then push claude-setup across the line.
```

### Full View Rules

- Show detail blocks only for Active projects
- Each block: 1-line focus, top 3 pending items, blockers
- Blocks sorted same as bar chart (by % descending)
- Use `### project — N%` as section header
- Pending items as markdown checkboxes `- [ ]`

## Single Project View (`/status <name>`)

Shows one project in full detail — no table, no other projects.

```
# ─── claude-setup ─── 2026-02-09

  ████████████████████████████░░  98%  Active

  Branch: main
  Last commit: 2 min ago — Add disaster recovery script
  Dirty files: 0

### Focus
Phase 8 complete. Ready for burn-in.

### Completed (15 items)
- [x] Phase 1-8 all done
- [x] Disaster recovery script
- [x] Rich welcome dashboard
  ...

### Pending
- [ ] 1-week burn-in
- [ ] Pair Happy Coder on iPhone
- [ ] Test MCP servers on LXC

### Blockers
None

### Notes
- Proxmox snapshots at each phase
- BambooHR MCP not migrated
```

## Progress Heuristic

When STATUS.md contains an explicit percentage (e.g., "98%", "60% complete"), use it directly. Otherwise, infer from keywords in the Progress and Current Focus fields.

### Keyword-to-Percentage Mapping

| Keywords / Patterns | Inferred % |
|---------------------|------------|
| `complete`, `done`, `finished`, `all phases` | 100% |
| `burn-in`, `validation`, `testing phase` | 95% |
| `daily use`, `functional`, `running`, `live` | 80% |
| `core built`, `architecture built`, `core stack` | 40% |
| `in progress`, `in development`, `plugins in dev` | 50% |
| `spec complete`, `designed`, `planned` | 20% |
| `phase 0`, `prototype`, `initial`, `new` | 10% |
| `paused`, `on hold` | keep last known % |

### Parsing Priority

1. Extract explicit `N%` from Progress field (regex: `\d+%`)
2. If no explicit %, scan Progress + Current Focus for keywords
3. If no keywords match, fall back to status-based default: `active=50%`, `stable=85%`, `complete=100%`, `new=10%`, `paused=last known`

### Special Cases

- `no-git` projects: show `○ no git` flag, default to 10%
- Projects without STATUS.md: show `◌ needs STATUS.md`, default to 0%
- `[stale]` flag when last commit >7 days ago (check via `git log -1 --format=%ar`)

## Caching

Caching behavior remains the same as current implementation:

1. Fingerprint all projects (hash + dirty count + STATUS.md mtime)
2. Compare with `~/.claude/cache/status-fingerprint.txt`
3. If unchanged, output cached dashboard with `> Cached — no changes since last run.`
4. If changed, refresh only changed projects, update cache

Cache files:
- `~/.claude/cache/status-fingerprint.txt` — project fingerprints
- `~/.claude/cache/status-dashboard.md` — rendered compact view (markdown)

## Implementation

The implementation lives entirely in the `/status` skill file (`~/.claude-shared/commands/status.md`). No new scripts needed. The skill instructs Claude to:

1. Run the fingerprint command
2. Compare with cache
3. Read STATUS.md files for changed projects
4. Render the visual dashboard using the layout rules above
5. Update the cache

### Changes Required

1. **`~/.claude-shared/commands/status.md`** — rewrite the output format section with the new visual layout rules, heuristic table, and flag icons
2. No other files need to change

## Out of Scope

- ANSI colors (not supported in Claude text output)
- Sparklines or charts beyond progress bars
- Interactive elements
- Changes to cc-dashboard (terminal script is separate)
