# Dogcraft Logging

A data logging and anti-griefing plugin for Paper 1.21+ servers. Tracks block changes, container access, chat, commands, kills, sessions, signs, and more with full rollback and restore capabilities.

## Requirements

- Java 21+
- Paper 1.21+ (or any Paper fork)
- SQLite (default, zero config) or MySQL 8.0+

### Optional

- **Vault** — for economy transaction logging
- **GriefPrevention / GriefDefender** — for claim-aware logging

## Installation

1. Download the latest JAR from releases or build with `mvn clean package`
2. Place `dogcraft-logging-1.0.0.jar` in your server's `plugins/` folder
3. Start the server — a default `config.yml` and SQLite database will be created
4. Configure as needed and `/dcl reload`

## Building from Source

```bash
git clone <repo-url>
cd Dogcraft-logging
mvn clean package
```

The shaded JAR is output to `target/dogcraft-logging-1.0.0.jar`.

---

## Commands

All commands use `/dcl` (alias: `/dogcraftlog`).

### Inspection & Lookup

| Command | Description | Permission |
|---|---|---|
| `/dcl inspect` | Toggle block inspector mode — click blocks to see their history | `dogcraft.logging.inspect` |
| `/dcl lookup [params]` | Search logs with query parameters | `dogcraft.logging.lookup` |

### Rollback & Restore

| Command | Description | Permission |
|---|---|---|
| `/dcl rollback [params]` | Preview a rollback (always previews first) | `dogcraft.logging.rollback` |
| `/dcl rollback [params] #selective` | Interactive cherry-pick rollback | `dogcraft.logging.rollback` |
| `/dcl restore [params]` | Preview a restore of rolled-back actions | `dogcraft.logging.restore` |
| `/dcl confirm` | Apply the active preview | rollback or restore perm |
| `/dcl cancel` | Cancel the active preview | — |
| `/dcl preview add <player>` | Share your preview with another staff member | `dogcraft.logging.rollback` |
| `/dcl preview remove <player>` | Remove a staff member from your preview | `dogcraft.logging.rollback` |
| `/dcl approve <id>` | Approve a large rollback (two-person mode) | `dogcraft.logging.approve` |
| `/dcl deny <id>` | Deny a large rollback | `dogcraft.logging.approve` |

### Administration

| Command | Description | Permission |
|---|---|---|
| `/dcl purge t:<time> [a:<action>]` | Purge old data (moves to cold storage if enabled, otherwise deletes) | `dogcraft.logging.purge` |
| `/dcl audit [u:<admin>] [t:<time>]` | View staff rollback/restore/purge audit log | `dogcraft.logging.admin` |
| `/dcl trust <player>` | View player trust tier and suspicion score | `dogcraft.logging.trust` |
| `/dcl snapshot <id> <before\|after>` | Open a view-only inventory snapshot | `dogcraft.logging.inspect` |
| `/dcl stats` | View queue depth, insert counts, database info | `dogcraft.logging.admin` |
| `/dcl reload` | Reload configuration | `dogcraft.logging.admin` |

---

## Query Parameters

Parameters can be combined in any order on lookup, rollback, and restore commands.

| Parameter | Description | Example |
|---|---|---|
| `u:<user>` | Filter by player name | `u:Steve` |
| `t:<time>` | Actions within the last time period | `t:1h`, `t:7d`, `t:30d` |
| `r:<radius>` | Actions within radius of your location | `r:10`, `r:#global` |
| `a:<action>` | Filter by action type | `a:+block`, `a:-container` |
| `i:<material>` | Include only this material | `i:diamond_ore` |
| `e:<material>` | Exclude this material | `e:stone` |
| `reason:<text>` | Attach a reason (rollback/restore only) | `reason:griefing` |

### Time Format

- `s` — seconds
- `m` — minutes
- `h` — hours
- `d` — days
- `w` — weeks

Combine them: `1d12h` = 1 day and 12 hours.

### Action Types

Use `+` prefix to include or `-` to exclude:

| Type | What it Logs |
|---|---|
| `block` | Block place and break |
| `container` | Container inventory changes |
| `chat` | Chat messages |
| `command` | Commands executed |
| `session` | Player join/leave |
| `sign` | Sign placement and edits |
| `kill` | Entity kills |

---

## How Rollbacks Work

All rollbacks go through a **preview** phase first — they are never applied directly. The workflow is:

1. Run `/dcl rollback u:Griefer t:1h r:20`
2. Affected blocks are shown as a ghost preview (client-side only)
3. Review the preview, optionally `/dcl preview add <other_mod>` to share it
4. `/dcl confirm` to apply, or `/dcl cancel` to discard
5. Previews auto-cancel after 5 minutes (configurable)

### Selective Rollback

Add `#selective` to cherry-pick individual actions:

```
/dcl rollback u:Griefer t:1h #selective
```

This opens a paginated chat GUI where you can toggle each action between Apply and Skip, then finish to execute only the selected ones.

### Two-Person Approval

When `approval.enabled: true` and a rollback exceeds `approval.block-threshold`, a second staff member must approve it. The requester sees a waiting message, and staff with `dogcraft.logging.approve` permission see clickable `[APPROVE]` / `[DENY]` buttons.

---

## Container Snapshots

When looking up container actions (chests, barrels, shulker boxes, etc.), results include clickable links to view inventory snapshots:

- **[Before]** — the container contents before the action
- **[After]** — the container contents after the action

Clicking opens a read-only inventory GUI showing the exact items at that point in time.

---

## Configuration

The default config is generated on first run. Here is a breakdown of each section.

### Database

```yaml
database:
  type: sqlite          # "sqlite" or "mysql"
  sqlite:
    file: plugins/Dogcraft-logging/data.db
  mysql:
    host: localhost
    port: 3306
    database: dogcraft_logging
    username: root
    password: ''
    pool:
      maximum-pool-size: 10
      minimum-idle: 2
      connection-timeout: 5000
      max-lifetime: 1800000
```

SQLite works out of the box. For servers with more than ~20 players, MySQL is recommended.

### Action Types

Each action type can be independently enabled/disabled and assigned a retention period:

```yaml
actions:
  block-place:
    enabled: true
    retention-days: 90
  block-break:
    enabled: true
    retention-days: 90
  container:
    enabled: true
    retention-days: 60
  chat:
    enabled: true
    retention-days: 30
  command:
    enabled: false        # disabled by default
    retention-days: 30
  session:
    enabled: true
    retention-days: 45
  sign:
    enabled: true
    retention-days: 60
  kill:
    enabled: true
    retention-days: 14
  inventory:
    enabled: false        # disabled by default
    retention-days: 14
```

- `enabled: false` means the event listener is not registered at all (zero overhead)
- `retention-days: -1` means data is kept forever
- When `cold-storage.enabled: true`, expired data is moved to cold storage instead of deleted

### Consumer Queue

```yaml
queue:
  flush-interval-ms: 1000    # How often the consumer flushes to DB
  max-batch-size: 500        # Max rows per batch insert
  capacity: 100000           # Queue size before dropping events
```

The queue uses adaptive batch sizing automatically:
- Queue depth < 1,000: normal batch (500)
- Queue depth 1,000-10,000: double batch (1,000)
- Queue depth > 10,000: max batch (5,000) + warning
- TPS below 18: flush interval doubles to reduce server load

### Rollback Preview

```yaml
preview:
  timeout-seconds: 300     # 5 minutes before auto-cancel
```

### Two-Person Approval

```yaml
approval:
  enabled: false
  block-threshold: 10000     # Actions above this require second approval
  timeout-seconds: 300       # How long an approval request stays open
```

### Cold Storage

```yaml
cold-storage:
  enabled: false
  type: database             # "database" or "file"
  cold-retention-days: -1    # -1 = keep cold data forever
  database:
    host: localhost
    port: 3306
    name: dogcraft_logging_cold
    username: dcl
    password: ''
  file:
    path: plugins/Dogcraft-logging/cold/
```

When enabled, expired data (past its `retention-days`) is moved to cold storage instead of deleted. Supports either a separate database or gzipped JSON files on disk.

### Auto-Maintenance

```yaml
maintenance:
  enabled: true
  time: "04:00"              # 24h format, runs daily
```

The daily maintenance task:
1. Aggregates expiring rows into warm-tier daily summaries
2. Moves expired rows to cold storage (if enabled) or deletes them
3. Cleans up old warm-tier summaries past `retention.warm-tier-days`

### Audit Settings

```yaml
audit:
  require-reason: false       # Require reason: parameter on rollbacks
```

### Warm-Tier Retention

```yaml
retention:
  warm-tier-days: 365          # How long daily summaries are kept
```

Daily summaries provide long-term trend data (e.g., "PlayerX broke 500 blocks last Tuesday") even after the full-detail rows are gone.

### Trust & Suspicion Scoring

```yaml
trust:
  enabled: true
  check-interval-minutes: 5
  scoring-window-minutes: 10
  alert-threshold: 50.0
  new-player-hours: 10
  new-player-multiplier: 1.5
  rules:
    rapid-break:
      threshold: 200
      weight: 20.0
    xray:
      accuracy-threshold: 0.3
      weight: 30.0
    container-snoop:
      threshold: 20
      weight: 15.0
    place-break-cycle:
      threshold: 10
      weight: 10.0
```

The scorer runs periodically for all online players and computes a suspicion score (0-100) based on:

| Rule | What it Detects |
|---|---|
| `rapid-break` | Breaking more than N blocks in the scoring window |
| `xray` | High ore-to-total break ratio (diamond, emerald, ancient debris) |
| `container-snoop` | Opening many different containers quickly |
| `place-break-cycle` | Repeatedly placing and breaking at the same location |

Players are assigned trust tiers: `new`, `normal`, `trusted`, `suspicious`, `flagged`. When scores cross the alert threshold, online staff with `dogcraft.logging.alerts` are notified.

### Optional Integrations

```yaml
claims:
  enabled: false              # Enable claim plugin integration

economy:
  enabled: false              # Enable Vault economy logging
  check-interval-seconds: 30
```

Both are disabled by default. When `claims.enabled: true`, the plugin auto-detects GriefPrevention or GriefDefender and attaches claim ownership data to block logs.

### Sign Notifications

When a player places or edits a sign, staff with `dogcraft.logging.signnotify` receive a message showing who placed it and its contents. This is always active when the `sign` action type is enabled.

---

## Permissions

| Permission | Description | Default |
|---|---|---|
| `dogcraft.logging.*` | All permissions | op |
| `dogcraft.logging.inspect` | `/dcl inspect` | op |
| `dogcraft.logging.lookup` | `/dcl lookup` | op |
| `dogcraft.logging.rollback` | `/dcl rollback`, `/dcl confirm` | op |
| `dogcraft.logging.restore` | `/dcl restore` | op |
| `dogcraft.logging.purge` | `/dcl purge` | op |
| `dogcraft.logging.admin` | `/dcl stats`, `/dcl reload`, `/dcl audit` | op |
| `dogcraft.logging.trust` | `/dcl trust` | op |
| `dogcraft.logging.alerts` | Receive suspicion alerts | op |
| `dogcraft.logging.approve` | Approve/deny large rollbacks | op |
| `dogcraft.logging.signnotify` | Receive sign placement notifications | op |

---

## Database Schema

All tables are prefixed with the configured `table-prefix` (default: `dcl_`).

### Core Tables

| Table | Purpose |
|---|---|
| `dcl_user` | Player UUID to numeric ID mapping |
| `dcl_world` | World name to numeric ID mapping |
| `dcl_material` | Material name to numeric ID mapping |
| `dcl_username_log` | Username change history |

### Log Tables

| Table | Purpose |
|---|---|
| `dcl_block` | Block place/break/environment actions |
| `dcl_container` | Container inventory snapshots (before/after) |
| `dcl_chat` | Chat messages |
| `dcl_command` | Commands executed |
| `dcl_session` | Player join/leave with location |
| `dcl_sign` | Sign text (4 lines) |
| `dcl_kill` | Entity kills |
| `dcl_inventory` | Player inventory changes |
| `dcl_economy` | Economy transactions (requires Vault) |

### System Tables

| Table | Purpose |
|---|---|
| `dcl_rollback_log` | Record of all rollback/restore operations |
| `dcl_audit` | Staff action audit trail |
| `dcl_player_trust` | Trust tiers and suspicion scores |
| `dcl_daily_summary` | Warm-tier aggregated daily counts |
| `dcl_schema_version` | Migration version tracking |

---

## Migrating from CoreProtect

Dogcraft Logging is designed as a replacement for CoreProtect. The database schema is different, so there is no automatic migration. However, both can run side-by-side during a transition period:

1. Install Dogcraft Logging alongside CoreProtect
2. Run both for your desired overlap period
3. Verify Dogcraft Logging is capturing all events correctly
4. Remove CoreProtect

---

## Developer API

See [api.md](api.md) for the complete developer API documentation, including:

- Dependency setup (Maven/Gradle with `repo.dogcraft.net`)
- Querying logs programmatically
- Logging custom actions from other plugins
- Rollback/restore via API
- Exclusion zones for minigame arenas
- Pre-log event listening
- Claim plugin integration guide

### Quick Start

```java
// Get the API
DogcraftLoggingAPI api = Bukkit.getServicesManager()
    .getRegistration(DogcraftLoggingAPI.class).getProvider();

// Query logs
LookupParams params = LookupParams.builder()
    .player("Steve")
    .time(Duration.ofHours(1))
    .build();
api.performLookup(params).thenAccept(results -> { /* ... */ });

// Log a custom action
api.logCustomAction("#my-plugin", location, "custom-event",
    Map.of("key", "value"));

// Set an exclusion zone
api.setExclusionZone("arena-1", world, boundingBox);
```

---

## License

Internal Dogcraft project.
