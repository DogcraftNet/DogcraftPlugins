# Dogcraft Logging

A data logging and anti-griefing plugin for Paper 1.21+ servers. Tracks block changes, container access, chat, commands, kills, sessions, signs, and more with full rollback and restore capabilities.

## Requirements

- Java 21+
- Paper 1.21+ (or any Paper fork; compatible with Minecraft 26.1)
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
| `/dcl inspect [a:<action>]` | Toggle block inspector mode — click blocks to see their history. Optional `a:` limits results to one category (`block`, `+block`, `-block`, `container`, `+container`, `-container`, `interaction`, `transfer`); useful for finding who placed a chest without wading through its access history. | `dogcraft.logging.inspect` |
| `/dcl lookup [params]` | Search logs with query parameters (blocks + containers) | `dogcraft.logging.lookup` |
| `/dcl page <N>` | Jump to page N of your last lookup or inspect (auto-detects which) | `dogcraft.logging.lookup` or `inspect` |
| `/dcl near [params]` | Shorthand for lookup with configurable radius | `dogcraft.logging.lookup` |
| `/dcl blockping <material>` | Search for a block type near your crosshair (alias: `/dcl bp`) | `dogcraft.logging.blockping` |
| `/dcl activity <player> [t:<time>]` | View player activity summaries from warm-tier data | `dogcraft.logging.lookup` |

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
| `/dcl rebuild-diffs [s:<server>\|s:#all]` | Backfill `dcl_container_item` from existing snapshots (one-shot upgrade tool) | `dogcraft.logging.admin` |

---

## Query Parameters

Parameters can be combined in any order on lookup, rollback, and restore commands.

| Parameter | Description | Example |
|---|---|---|
| `u:<user>` | Filter by player name | `u:Steve` |
| `t:<time>` | Actions within the last time period | `t:1h`, `t:7d`, `t:30d` |
| `r:<radius>` | Actions within radius of your location; `r:#global` removes the spatial filter; `r:#<worldname>` restricts to a whole world (e.g. `r:#world_nether`, `r:#world_the_end`). | `r:10`, `r:#global`, `r:#world_nether` |
| `a:<action>` | Filter by action type | `a:+block`, `a:-container` |
| `i:<material[,material…]>` | Include only these materials. Comma-separated, or repeat the param. | `i:diamond_ore`, `i:iron_ingot,gold_ingot,diamond`, `i:iron i:gold` |
| `e:<material[,material…]>` | Exclude these materials. Same syntax as `i:`. | `e:stone,dirt,gravel` |
| `s:<server>` | Server scope (lookup, audit, activity) | `s:lobby`, `s:#all`, `s:#current` |
| `p:<page>` | Jump straight to a specific result page (1-based) | `p:3` |
| `#cold` | Query cold storage instead of hot (lookup only, requires database mode) | `/dcl lookup u:Steve t:200d #cold` |
> **Default time limit:** When no user (`u:`) and no time (`t:`) are specified, lookups default to the last `lookup.default-time-limit` (default: `30d`) to prevent full-table scans. A notice is shown to the player. This is configurable in `config.yml`.
| `#container` | Restrict lookup to the last container you inspected (CoreProtect-style) | `/dcl inspect`, click chest, `/dcl lookup #container t:1d i:diamond` |
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
| `block` | Block place and break — including water/lava/powder-snow/mob-bucket placement and bucket fills, and all non-player world changes (see below) |
| `container` | Container inventory changes — combine with `i:<material>` to filter by item type. Covers placed blocks (chest/barrel/hopper/furnace/shulker/chiseled bookshelf/decorated pot/etc.) **and** entity inventories (chest minecart, hopper minecart, donkey, mule, llama, chest boat). |
| `+container` | Items **added** to a container (use with `i:<material>`) |
| `-container` | Items **removed** from a container (use with `i:<material>`) |
| `chat` | Chat messages |
| `command` | Commands executed |
| `session` | Player join/leave |
| `sign` | Sign placement and edits |
| `kill` | Entity kills |
| `drop` (or `item-drop`) | Player drops items on the ground |
| `pickup` (or `item-pickup`) | Player picks up items from the ground |
| `inventory` | Both drops and pickups |
| `beacon` | Beacon primary/secondary effect changes |
| `interactions` (or `interact`) | Right-clicks on doors, trapdoors, fence gates, buttons, levers, beds, bells, note blocks, lecterns, respawn anchors |
| `transfer` (or `hopper`) | Automated item transfers — hoppers, dispensers, droppers, hopper minecarts (coalesced per source/dest/material). Explicit-only. |
| `copper-golem` | Copper golem container targeting (which containers a golem validated as a transfer target). Explicit-only. |
| `plugin` (or `plugin:<source>`) | Generic events logged by other plugins via `logCustomAction`; `plugin:<source>` narrows to one source plugin. Explicit-only. |

> **Item frames, armor stands, boats and minecarts have no dedicated `a:` filter** — their place/break is logged under `block` and their item insert/remove/theft under `container`. Likewise `sign` covers sign placement and edits. Toggle their *logging* with the `hanging` / `armor-stand` / `vehicle` config keys, but query them as `block` / `container`.

#### Non-Player World Changes (`block-environment`)

These are tracked under the `block` action type with a `#`-prefixed pseudo-user identifying the cause. Each source can be toggled individually under `actions.block-environment.sources` in the config.

| Pseudo-user | Source |
|---|---|
| `#fire` | Fire consuming blocks (`block-burn`); fire spreading to adjacent blocks |
| `#tnt`, `#creeper`, `#ghast`, `#wither`, `#enderdragon` | Explosions (player-attributed when the source is a player-ignited TNT) |
| `#piston` | Pistons moving blocks — logs a break at the old position and a place at the new |
| `#water`, `#lava` | Fluid flow breaking torches, redstone, etc. |
| `#fallingblock` | Sand/gravel/anvil/concrete-powder landing |
| `#enderman`, `#sheep`, `#ravager`, `#silverfish`, `#zombie`, `#rabbit` | Mob-driven block changes (enderman pickup/place, sheep eating grass, ravager leaf breaking, silverfish into stone, zombie breaking doors, rabbit eating carrots) |
| `<player>` + `#bonemeal` chain, or `#nature` | Sapling → tree, mushroom → huge mushroom — attributes to the player when bonemeal-triggered |
| `#nature` | Lava+water cobble/obsidian, snow/ice forming, vine/kelp/mushroom/grass spread, ice/snow melt, copper oxidation, coral dying |
| `#leavesdecay` | Leaves falling after a tree is broken (high volume — ~30-100 events per chopped tree) |

---

## How Rollbacks Work

All rollbacks go through a **preview** phase first — they are never applied directly. The workflow is:

1. Run `/dcl rollback u:Griefer t:1h r:20`
2. Affected blocks are shown as a ghost preview (client-side only)
3. Review the preview, optionally `/dcl preview add <other_mod>` to share it
4. `/dcl confirm` to apply, or `/dcl cancel` to discard
5. Previews auto-cancel after 5 minutes (configurable)

### Filtering a Rollback

Rollback and restore accept the same `a:`, `i:`, and `e:` filters as lookup, so you can narrow exactly which logged actions get reverted:

| Filter | Effect on rollback / restore |
|---|---|
| `a:block` | Only block place + break rows |
| `a:+block` | Only block placements |
| `a:-block` | Only block breaks |
| `a:container` | Only container snapshots |
| `a:+container` / `a:-container` | Only container transactions that added / removed items (joins `dcl_container_item`) |
| `i:diamond_ore` | Only rows whose block type is diamond_ore (or container transactions touching it) |
| `e:dirt,gravel` | Excludes dirt and gravel rows |

Action types that aren't reversible — chat, command, kill, session, sign, beacon, interaction, item-drop/pickup, plugin events — are rejected with a clear error rather than silently ignored.

```
/dcl rollback u:Griefer t:1h a:-block i:cobblestone,stone   # re-place only stone/cobble breaks
/dcl rollback u:Bob t:6h a:+container i:diamond              # undo Bob putting diamonds in chests
/dcl rollback u:Eve t:30m e:dirt                             # undo everything except dirt
```

> **Container item filters select transactions, not items.** When you use `i:`, `e:`, `a:+container`, or `a:-container` and the preview includes container rows, the plugin shows a yellow notice clarifying that each matching transaction is restored from its full before/after snapshot — individual items within a transaction are not rolled back in isolation.

### Selective Rollback

Add `#selective` to cherry-pick individual actions:

```
/dcl rollback u:Griefer t:1h #selective
```

This opens a paginated chat GUI where you can toggle each action between Apply and Skip, then finish to execute only the selected ones.

### Two-Person Approval

When `approval.enabled: true` and a rollback exceeds `approval.block-threshold`, a second staff member must approve it. The requester sees a waiting message, and staff with `dogcraft.logging.approve` permission see clickable `[APPROVE]` / `[DENY]` buttons.

### What Rollback Actually Restores

Rollback isn't just "put the block back" — three layers of state are preserved so a restored block ends up identical to what was destroyed:

**1. BlockData properties.** Composter fill level, axis, age, facing, waterlogged state, etc. are stored on every block row as a serialized `BlockData` string and reapplied on rollback. This has always been the case.

**2. Block-entity NBT (TileState).** For blocks that hold inline state beyond BlockData, the relevant fields are captured at break/place time and reapplied on rollback:

| Block | What's preserved |
|---|---|
| Lectern | The book (full ItemStack — title, pages, generation, author) |
| Jukebox | The held disc / record |
| Decorated pot | The held item (sherds are BlockData and already covered) |
| Banner | All patterns and colors |
| Skull / player head | Owner UUID + name |
| Spawner | Mob type, spawn delays, range, count, max-nearby |

This lets you roll back the destruction of a banner with 6 patterns, or a librarian's lectern with a custom-named enchanted book, and get exactly what was there back. Captured for player breaks, player placements, fire burn, TNT/creeper/ghast/wither/dragon explosions, and fluid-flow destruction. Stored in `dcl_block.block_entity_nbt` (BLOB, NULL for plain blocks).

**3. Container snapshots.** When a player accesses a container, the before/after inventory is logged in `dcl_container` (with full ItemStack NBT per slot — shulker contents inside chests round-trip correctly). The after-snapshot is **reconstructed to reflect only that player's changes** — hopper transfers and other players' modifications that occurred during the same session are stripped out. This per-click diff tracking means:
- **Multi-player accuracy** — two players in the same chest get separate, correct diffs
- **Hopper isolation** — items flowing in/out via hoppers while a container is open are not attributed to the player
- **Clean rollback** — restoring a container snapshot undoes exactly what that player did, not what hoppers or other players did simultaneously

When a player **breaks** a container with items inside, a synthetic snapshot is captured at break time so the contents can be restored even though the items dropped as entities. Shulkers are skipped because their dropped item carries the inventory inline. Rollback applies block actions before container actions, so the chest reappears first and then the inventory is restored on top of it.

**Item drop/pickup NBT.** When `item-drop` / `item-pickup` are enabled, the full ItemStack NBT is stored in `dcl_inventory.nbt` (BLOB). This catches shulker contents, bundle contents, written-book text, custom names, lore, enchantments, and skull owners — so a "pick up shulker" log row tells you exactly what was inside, not just `shulker_box × 1`.

**What's still not perfectly preserved** — furnace/brewing-stand smelting progress (cosmetic; contents are in container snapshots) and beehive bees (entity respawn on rollback is non-trivial). Flag these if they become real grief vectors for you.

---

## Lookup & Inspect Results

Both lookup and inspect use the same rendering engine and display format. Results are merged into a single time-sorted, paginated view. Each result line includes:

- **Clickable coordinates** — click the `x, y, z` to teleport directly to that location (hover shows "Click to teleport")
- **Container snapshots** — container entries show clickable **[Before]** and **[After]** links that open a read-only inventory GUI of the exact items at that point in time

Example output:
```
 2m ago Steve broke DIAMOND_ORE at 100, 64, -200 (world)
 3m ago Steve accessed container at 100, 65, -200 (world) [Before] [After]
```

Use `a:container` to show only container results, or `a:block` for only block results.

### Searching Containers by Item

When the `container` action type is enabled, the plugin tracks the per-item delta on every chest/barrel/furnace/etc. access. This lets you ask questions like *"who took my iron ingots?"* directly:

```
/dcl lookup r:5 i:iron_ingot a:-container t:1d
   → all containers within 5 blocks where iron_ingot was REMOVED in the last 24h

/dcl lookup u:Steve i:diamond a:+container t:7d
   → every time Steve put diamonds into a container in the last week

/dcl lookup i:netherite_ingot a:container
   → any container access (add or remove) involving netherite ingots
```

The diff is computed by material only — enchantments, custom names and durability are ignored for search purposes (the full inventory snapshot is still saved and viewable via the `[Before]` / `[After]` clickable links).

## BlockPing (Xray Investigation)

`/dcl blockping <material>` (alias `/dcl bp`) searches for a specific block type in an 11x11x11 cube (radius 5) centered on the block you're looking at (20 block ray trace). Returns up to 64 matching blocks.

This is useful for investigating xray suspects — look at their mining tunnel and search for `diamond_ore` to see if there are exposed ores nearby that could explain their path.

When used, all staff with `dogcraft.logging.alerts` are notified (including across servers if cross-server messaging is enabled), so the team knows who is running block searches and for what.

---

## Multi-Server Setup

Dogcraft Logging supports running multiple game servers (e.g. `lobby`, `survival`, `creative`) against the same MySQL database. Every log row is tagged with a `server_id` so the data stays cleanly partitioned, but moderators can opt into cross-server queries when needed.

### How Server Identity Works

The plugin reads `server_id.conf` from the **server root directory** (next to `server.properties`). This file is created by [NetworkSwitch](https://github.com/dogcraft/networkswitch) and contains:

```properties
uuid=550e8400-e29b-41d4-a716-446655440000
name=lobby
```

- `uuid` is stable across restarts and identifies this server permanently.
- `name` is populated once Velocity maps the UUID to a server name. It may be `null` on first boot — Dogcraft Logging auto-updates it on the first player join.

If `server_id.conf` is absent (e.g. running a single standalone server), the plugin generates and persists its own UUID in `plugins/Dogcraft-logging/server_id_fallback.conf`.

### Default Scope

All queries default to **the current server only**:

- `/dcl lookup u:Steve t:1d` → only this server's actions
- `/dcl trust Steve` → only this server's trust score
- `/dcl audit` → only this server's staff actions
- `/dcl activity Steve` → only this server's daily summaries

To search across servers, add the `s:` parameter:

| Form | Meaning |
|---|---|
| `s:lobby` | Query a specific server by name |
| `s:#all` | Query every server in the database |
| `s:#current` | Explicit current server (same as omitting `s:`) |

### What's Per-Server vs Global

| Per-Server | Global |
|---|---|
| Block / container / chat / command / session / sign / kill / inventory / economy logs | Player UUIDs (`dcl_user`) |
| World definitions (`dcl_world`) — `world` on lobby ≠ `world` on survival | Username history (`dcl_username_log`) |
| Trust scores and tiers (`dcl_player_trust`) | Material map (`dcl_material_map`) |
| Daily summaries (`dcl_daily_summary`) | |
| Staff audit log (`dcl_audit`) | |

### What's Always Local

- **Rollbacks and restores** — always act on the current server. There is no cross-server rollback by design (you can only modify the world you're in).
- **Inspect** — clicking a block only shows that server's history.
- **Auto-maintenance** — each server runs its own purge/aggregation cycle; servers don't touch each other's data.
- **Trust scoring** — runs only against the current server's data. A player's xray score on `lobby` doesn't affect their score on `survival`.

### Operational Notes

- Each server should have a **unique `server_id.conf`**. Copying a server folder including `server_id.conf` will cause two servers to fight over one identity — delete the file on the copy and let it regenerate.
- Run `/dcl reload` after the file changes; the plugin re-reads identity on each enable.
- The `dcl_server` table grows by exactly one row per distinct server. Use the web search interface or `SELECT * FROM dcl_server;` to see the full network.

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
  block-environment:
    enabled: true
    retention-days: 90
    sources:
      fire-burn: true        # Fire consuming blocks
      explosion: true        # TNT/creeper/ghast/wither/dragon
      piston: true           # Pistons moving blocks
      fluid-flow: true       # Water/lava breaking torches/redstone/etc.
      entity-change: true    # Falling blocks, endermen, sheep, ravagers, silverfish, zombies
      structure-grow: true   # Saplings → trees, mushrooms → huge mushrooms
      block-form: true       # Lava+water cobble/obsidian, snow/ice forming
      block-spread: true     # Fire spreading, vine/kelp/mushroom/grass spread
      block-fade: true       # Ice/snow melt, copper oxidation, coral dying
      leaves-decay: true     # Leaves falling after tree breaks (highest volume)
  container:
    enabled: true
    retention-days: 60
  hopper:                  # hopper/dispenser/dropper transfers (coalesced)
    enabled: true
    retention-days: 7
    coalesce-seconds: 10
  copper-golem:            # copper golem container targeting
    enabled: true
    retention-days: 7
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
  beacon:                  # beacon primary/secondary effect changes
    enabled: true
    retention-days: 90
  interaction:             # doors, buttons, levers, beds, bells, lecterns, ...
    enabled: true
    retention-days: 30
  hanging:                 # item frames / paintings (rows land in block/container/interaction)
    enabled: true
  armor-stand:             # stand place + equip/unequip (block/container)
    enabled: true
  vehicle:                 # boat / minecart place + destroy + contents (block/container)
    enabled: true
  inventory:
    enabled: false        # disabled by default
    retention-days: 14
  item-drop:
    enabled: false        # disabled — high volume on busy servers
    retention-days: 7
  item-pickup:
    enabled: false        # disabled — high volume on busy servers
    retention-days: 7
  plugin-event:            # generic events written by other plugins via the API
    enabled: true          # only gates auto-purge — no listener to disable
    retention-days: 30
```

- `enabled: false` means the event listener is not registered at all (zero overhead)
- `retention-days: -1` means data is kept forever
- When `cold-storage.enabled: true`, expired data is moved to cold storage instead of deleted

> Note on `block-place` / `block-break`: water/lava/powder-snow buckets and mob buckets (axolotl, fish, tadpole — they place water) are tracked under these flags. The bucket events fire `PlayerBucket{Empty,Fill}Event` rather than `BlockPlaceEvent`, but they're routed to the same logs.

> Note on `block-environment.sources`: configs predating this subsection default every source to `true`, matching prior behavior. Disable individually if any source dominates your write volume — `leaves-decay` is the usual suspect since chopping a tree fires ~30-100 events.

> Note on `item-drop` / `item-pickup`: pickups are filtered to only count real player pickups (not hopper minecarts or similar entities). Both are disabled by default — they fire frequently on servers with mob farms or sorters and can fill the database quickly.

### Config Auto-Updater

On every plugin start, the config file is checked against the bundled defaults:

- **Missing keys** from the default config are added automatically with their default values and comments.
- **Deprecated keys** that no longer exist in the defaults are tagged with a `# [DEPRECATED]` comment but kept in place (in case you want to migrate the value somewhere else).
- **All your existing values and comments are preserved.**

A backup of the previous config is saved to `config.yml.bak` before any changes are written.

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

### Cross-Server Messaging

```yaml
messaging:
  cross-server: false          # Enable BungeeCord cross-server alerts
  cross-server-secret: ''      # Shared HMAC secret — same long random string on every server
  alert-types:
    blockping: true            # BlockPing search alerts
    sign: true                 # Sign placement alerts
    suspicion: true            # Suspicion score alerts
```

When enabled, staff alerts (blockping searches, sign placements, suspicion scores) are forwarded to all servers in the BungeeCord network. Staff with `dogcraft.logging.alerts` on any server will see the alerts. Each alert type can be toggled independently. Every server in the network must also share the same non-empty `cross-server-secret`: alerts are authenticated with HMAC-SHA256, and the channel fails closed — while the secret is empty or mismatched, inbound alerts are rejected and nothing is sent.

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

**Cold-storage retention.** The `cold-retention-days` value sets how long data lives in cold storage before it is permanently deleted:

- `-1` (default) — keep cold data forever
- `> 0` — delete cold data older than this many days during the daily auto-maintenance run

In **database mode**, cleanup runs `DELETE FROM cold_<table> WHERE server_id = ? AND time < ?` scoped to the current server. In **file mode**, gzipped exports older than the threshold (by file modification time) are deleted from `cold-storage.file.path`.

**Querying cold storage.** When cold storage is in **database mode**, moderators can search archived data with the `#cold` flag:

```
/dcl lookup u:Griefer t:200d #cold
```

This swaps the query to `cold_<table>` instead of the hot table. File-mode cold storage is not searchable in-game — those gzipped JSON files are intended for cold archival only and need to be unpacked manually if you need to retrieve them.

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
4. Cleans up cold-storage data past `cold-storage.cold-retention-days` (if enabled and not `-1`)

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

Daily summaries provide long-term trend data even after the full-detail rows are purged. Query them with `/dcl activity <player> [t:<time>]`:

```
--- Activity: Steve (last 7d) ---
 Totals: Blocks broken: 1523, Blocks placed: 890, Container accesses: 45
 2026-03-28: broken=234, placed=120, containers=8
 2026-03-27: broken=310, placed=180, chats=45
 ...
```

Defaults to the last 7 days. Use `t:30d` for a wider range. Output is capped at 14 days of breakdown to avoid chat spam.

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

The scorer runs asynchronously every `check-interval-minutes` for all online players. It queries the last `scoring-window-minutes` of activity and computes a suspicion score (0–100) based on four detection rules.

#### How Scoring Works

Each rule produces a score independently. If a player's value for that rule exceeds its threshold, the score for that rule is:

```
rule_score = weight × (actual_value / threshold)
```

For example, if a player broke 400 blocks and the threshold is 200 with a weight of 20:
```
rapid-break score = 20.0 × (400 / 200) = 40.0
```

All rule scores are summed. If the player qualifies as "new" (under `new-player-hours` of playtime), the total is multiplied by `new-player-multiplier`. The final score is capped at 100.

#### Detection Rules — Detailed

| Rule | What it Measures | Score Calculation | When it Triggers |
|---|---|---|---|
| **rapid-break** | Total blocks broken in the scoring window | `weight × (blocks_broken / threshold)` | Player broke more than `threshold` blocks in the window. Catches strip-mining bots, nuker hacks, and mass griefing. |
| **xray** | Ratio of valuable ores to total blocks broken | `weight × (ore_accuracy / accuracy-threshold)` | Player broke >20 blocks total AND >3 ores AND ore/total ratio exceeds `accuracy-threshold` (default 30%). Tracked ores: diamond, deepslate diamond, emerald, deepslate emerald, ancient debris, gold, deepslate gold. **Breaks of blocks the same player previously placed at the same coordinates are excluded from both the numerator and denominator**, so placing and re-breaking your own ore (for decoration or testing) won't inflate the score. |
| **container-snoop** | Count of **distinct container locations** opened | `weight × (containers_opened / threshold)` | Player opened more than `threshold` unique containers. Catches base raiders systematically looting chests. |
| **place-break-cycle** | Locations where the same player both placed AND broke the same block type | `weight × (cycle_locations / threshold)` | More than `threshold` locations with place+break of the same material. Catches grief patterns like placing lava then breaking, or cobble-monster builders. |

#### Trust Tiers

Players are assigned a tier based on their score and playtime:

| Tier | Color | Condition |
|---|---|---|
| **new** | Aqua | Playtime < `new-player-hours` (regardless of score) |
| **flagged** | Red | Score ≥ 70 |
| **suspicious** | Gold | Score ≥ 40 |
| **trusted** | Green | Playtime > 100 hours AND score < 10 |
| **normal** | Gray | Everyone else |

#### Alerts

When a player's score crosses `alert-threshold` (default 50), all online staff with `dogcraft.logging.alerts` receive a message:

```
[DCL Alert] PlayerName suspicion score: 62.5 [rapid-break, xray-indicator]
```

If cross-server messaging is enabled, alerts are forwarded to all servers.

#### The `/dcl trust` Command

Running `/dcl trust <player>` shows:
- Current tier and score
- Total playtime on this server
- Last scoring timestamp
- Active triggers (which rules are currently firing)
- **Category breakdown** — raw values, thresholds, and weighted scores per rule, so staff can see exactly why a player is flagged

Example output:
```
--- Trust Info: Steve ---
Tier: SUSPICIOUS
Suspicion Score: 45.2 / 100
Playtime: 3h 20m
Last Scored: 2026-05-14 22:30
Active Triggers: xray-indicator, container-snoop
--- Category Breakdown ---
  Rapid Break: 85 / 200 blocks → 0.0 pts
  X-ray: 12 ore / 45 total (27% / 30% threshold) → 0.0 pts
  Container Snoop: 28 / 20 containers → 21.0 pts
  Place/Break Cycle: 3 / 10 locations → 0.0 pts
```

#### Important Notes

- Scoring is **per-server** — a player's xray score on `lobby` doesn't affect their score on `survival`.
- The scoring window is a **rolling window** (last N minutes of activity), not cumulative. A player's score drops to 0 as soon as they stop the suspicious behavior.
- Playtime is computed from session join/leave events on this server.
- Trust data is stored in `dcl_player_trust` and persists across restarts.
- The category breakdown uses a **live query** — it recomputes from current data, not the stored snapshot.

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
| `dogcraft.logging.alerts` | Receive suspicion and cross-server alerts | op |
| `dogcraft.logging.blockping` | Use `/dcl blockping` to search for block types | op |
| `dogcraft.logging.approve` | Approve/deny large rollbacks | op |
| `dogcraft.logging.signnotify` | Receive sign placement notifications | op |

---

## Database Schema

All tables are prefixed with the configured `table-prefix` (default: `dcl_`).

### Core Tables

| Table | Purpose |
|---|---|
| `dcl_server` | Server UUID + name mapping (one row per game server in the network) |
| `dcl_user` | Player UUID to numeric ID mapping (global) |
| `dcl_world` | World name to numeric ID mapping (per-server) |
| `dcl_material_map` | Material name to numeric ID mapping (global) |
| `dcl_username_log` | Username change history |

> Every log table has a `server_id INT NOT NULL` column. The leading composite index column is also `server_id`, so single-server queries hit the index efficiently.

### Log Tables

| Table | Purpose |
|---|---|
| `dcl_block` | Block place/break/environment actions. Carries `block_data` (BlockData string) and `block_entity_nbt` (BLOB, nullable — TileState NBT for lecterns, banners, skulls, jukeboxes, decorated pots, spawners). |
| `dcl_container` | Container inventory snapshots (before/after). Synthetic break-snapshots are emitted when a non-shulker container is broken with items inside, so chest-break thefts are recoverable. |
| `dcl_container_item` | Per-(container access, material) item-delta index. Powers `i:` / `e:` / `a:+container` / `a:-container` filtering. |
| `dcl_chat` | Chat messages |
| `dcl_command` | Commands executed |
| `dcl_session` | Player join/leave with location |
| `dcl_sign` | Sign text (4 lines) |
| `dcl_kill` | Entity kills |
| `dcl_inventory` | Player drops and pickups. Carries `nbt` (BLOB, nullable — full ItemStack NBT including shulker contents, bundle contents, named/enchanted items, written books). |
| `dcl_economy` | Economy transactions (requires Vault) |
| `dcl_beacon` | Beacon primary/secondary effect changes |
| `dcl_interaction` | Right-click interactions (doors, trapdoors, fence gates, buttons, levers, beds, bells, note blocks, lecterns, respawn anchors) |
| `dcl_plugin_event` | Generic plugin-defined events from `logCustomAction` |

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
