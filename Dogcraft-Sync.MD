# Dogcraft-Sync

A Paper 1.21.4 plugin that synchronizes player data across multiple Minecraft servers using MySQL and Redis. Designed to make switching servers feel like changing dimensions — inventories, stats, advancements, maps, and more follow the player seamlessly.

## Features

- **Inventory sync** — main inventory, armor, offhand, and enderchest
- **Statistics sync** — all vanilla stats including block, item, and entity subtypes
- **Advancement sync** — full criteria-level progress, suppresses re-broadcast on load
- **Potion effect sync** — active effects preserved across servers
- **Player state sync** — health, hunger, saturation, XP, gamemode, flight, fire ticks, air, portal cooldown
- **Map sync** — pixel-perfect map data with central ID registry and per-server local ID translation
- **Cross-server chat** — death messages, advancements, and broadcasts forwarded to all servers
- **Admin inventory tools** — view or edit any player's inventory/enderchest, online or offline, local or remote
- **Distributed locking** — Redis-based locks prevent concurrent writes to the same player
- **Freeze on join** — players are frozen during data load to prevent actions before sync completes

## Requirements

- Java 21+
- Paper 1.21.4
- MySQL 8+
- Redis 7+

## Configuration

```yaml
server-id: "survival-1"  # Must be unique per server

mysql:
  host: "127.0.0.1"
  port: 3306
  database: "playersync"
  username: "sync_user"
  password: "your_password"
  pool-size: 10

redis:
  host: "127.0.0.1"
  port: 6379
  password: ""
  database: 0

sync:
  periodic-save-interval: 60   # seconds between background saves
  lock-timeout: 30             # distributed lock TTL in seconds
  load-retry-attempts: 5       # lock acquisition retries on join
  load-retry-delay-ms: 200     # delay between retries

features:
  sync-inventory: true
  sync-enderchest: true
  sync-stats: true
  sync-advancements: true
  sync-effects: true
```

## Commands

All commands use `/sync <subcommand>`. Each subcommand has its own permission.

| Command | Description |
|---------|-------------|
| `/sync reload` | Reload plugin configuration |
| `/sync save <player>` | Force-save a player's data |
| `/sync load <player>` | Force-load a player's data from the database |
| `/sync status <player>` | Show lock holder, TTL, and freeze state |
| `/sync unfreeze [player]` | Unfreeze a stuck player (or all players) |
| `/sync invsee <player>` | View a player's inventory (read-only) |
| `/sync invsee <player> edit` | Edit a player's inventory |
| `/sync ec <player>` | View a player's enderchest (read-only) |
| `/sync ec <player> edit` | Edit a player's enderchest |
| `/sync debug` | Toggle debug logging |

### Inventory Viewing

- **Read-only mode** opens the player's live inventory. The viewer sees real-time changes but cannot modify items.
- **Edit mode** on a local player opens the live inventory directly — changes are instant.
- **Edit mode** on a remote/offline player opens a virtual chest loaded from the database. Every click pushes changes via Redis pub/sub to the target's server in real time. On close, changes are persisted to MySQL.

## Permissions

```
dogcraftsync.*                (default: op — grants all below)
├── dogcraftsync.reload       (default: op)
├── dogcraftsync.save         (default: op)
├── dogcraftsync.load         (default: op)
├── dogcraftsync.status       (default: op)
├── dogcraftsync.unfreeze     (default: op)
├── dogcraftsync.invsee       (default: false — view inventory, read-only)
├── dogcraftsync.invsee.edit  (default: op — edit inventory)
├── dogcraftsync.enderchest   (default: false — view enderchest, read-only)
├── dogcraftsync.enderchest.edit (default: op — edit enderchest)
└── dogcraftsync.debug        (default: op)
```

View permissions (`invsee`, `enderchest`) default to `false` so they can be granted to moderators independently of the edit permissions.

## Architecture

### Data Flow

```
Player Join:
  freeze player → acquire lock (retry 5x) → load from MySQL → apply on main thread → unfreeze

Player Quit:
  collect data on main thread → async save to MySQL → mark offline → release lock

Periodic Save (every 60s):
  collect all online players on main thread → async batch save → refresh locks

Server Switch:
  quit flow on old server → join flow on new server (lock handoff via TTL)
```

### Database Schema

**MySQL** stores all persistent data across 8 tables:

| Table | Purpose |
|-------|---------|
| `player_data` | Core record — UUID, username, server ID, online status, version |
| `player_inventories` | Base64-encoded inventory, armor, offhand, enderchest |
| `player_stats` | All vanilla statistics (untyped, block, item, entity subtypes) |
| `player_advancements` | Criteria-level progress as JSON |
| `player_effects` | Active potion effects |
| `player_state` | Health, hunger, XP, gamemode, flight, fire ticks, air, portal cooldown |
| `map_registry` | Central map registry — auto-increment IDs, pixel data, origin server |
| `map_id_mapping` | Per-server mapping of central ID to local map ID |

Schema is auto-created and auto-migrated on startup.

### Redis Usage

**Channels:**
| Channel | Purpose |
|---------|---------|
| `playersync:channel:sync` | Player sync, inventory edits, map sync messages |
| `playersync:channel:chat` | Cross-server death, advancement, and broadcast messages |

**Keys:**
| Key Pattern | Purpose |
|-------------|---------|
| `playersync:lock:{uuid}` | Distributed lock (SET NX EX) |
| `playersync:invsee:{uuid}:{type}` | Temporary inventory data during admin edits (TTL 300s) |

**Pub/Sub Message Types:**
| Type | Direction | Purpose |
|------|-----------|---------|
| `FORCE_SAVE` | → target server | Force-save a player before loading their data elsewhere |
| `PLAYER_LEAVING` / `PLAYER_ARRIVED` | broadcast | Movement notifications |
| `INVALIDATE_CACHE` | → target server | Full data reload from MySQL |
| `RELOAD_INVENTORY` | → target server | Reload inventory or enderchest from MySQL |
| `INVSEE_UPDATE` | → target server | Apply live admin edits from Redis |
| `MAP_CREATED` | broadcast | Pre-create local maps on all servers |
| `MAP_DATA_UPDATED` | broadcast | Refresh map pixel data from MySQL |
| `DEATH_MESSAGE` / `ADVANCEMENT_MESSAGE` / `BROADCAST_MESSAGE` | broadcast | Cross-server chat |

### Map Sync

Maps use a central ID registry to handle the fact that each server assigns its own local map IDs:

1. When a map is created on any server, it's registered in `map_registry` with an auto-increment central ID
2. A `MAP_CREATED` message tells other servers to pre-create a local map for it
3. Pixel data (128x128 byte array) is extracted via NMS reflection and stored in the DB
4. On receiving servers, pixel data is written directly to the NMS color buffer and the map is **locked** to prevent vanilla rendering from overwriting it
5. On the **originating server**, maps are never locked — they continue to update normally from world exploration
6. Pixel data is only saved/published when it actually changes (hash-based deduplication)

Map IDs in inventories are remapped between local and central on save/load.

### Serialization

| Data | Method |
|------|--------|
| Inventories | `ItemStack.serializeAsBytes()` → Base64 |
| Statistics | `Statistic` enum + subtype key → `Map<String, Long>` |
| Advancements | Criteria names → JSON array per advancement key |
| Potion effects | Type + amplifier + duration → relational rows |

### Project Structure

```
net.dogcraft.dogcraftSync/
├── DogcraftSync.java              # Main plugin — wires everything together
├── config/
│   └── SyncConfig.java            # Configuration loader
├── data/
│   └── PlayerData.java            # DTO for all player data
├── database/
│   ├── MySQLManager.java          # HikariCP pool, schema, queries
│   └── RedisManager.java          # Jedis pool, pub/sub
├── serializers/
│   ├── InventorySerializer.java   # ItemStack[] ↔ Base64
│   ├── StatsSerializer.java       # Statistics ↔ Map
│   ├── AdvancementSerializer.java # Advancement criteria ↔ JSON
│   └── EffectSerializer.java      # Potion effects ↔ records
├── sync/
│   ├── SaveManager.java           # Collect + save player data
│   ├── LoadManager.java           # Load + apply player data
│   ├── LockManager.java           # Redis distributed locks
│   ├── MapSyncManager.java        # Central map registry + pixel sync
│   ├── SyncedMapRenderer.java     # Fallback renderer for synced maps
│   └── PeriodicSaveTask.java      # Background save timer
├── listeners/
│   ├── PlayerJoinListener.java    # Freeze → load → apply → unfreeze
│   ├── PlayerQuitListener.java    # Save → release lock
│   ├── SyncFreezeListener.java    # Block all actions during sync
│   ├── InvSeeListener.java        # Admin inventory view/edit GUI
│   ├── MapListener.java           # Auto-register new maps
│   ├── CrossServerChatListener.java  # Publish deaths/advancements/broadcasts
│   └── CrossServerBroadcast.java  # ThreadLocal flag to prevent re-broadcast loops
├── messaging/
│   └── SyncMessageHandler.java    # Redis pub/sub message router
└── commands/
    └── SyncCommand.java           # /sync command with subcommands
```

## Building

```bash
mvn clean package
```

The shaded JAR will be in `target/`. Copy it to each server's `plugins/` folder.

## Deployment

1. Set a unique `server-id` in each server's `config.yml`
2. Ensure all servers can reach MySQL and Redis
3. Place the plugin JAR on all servers
4. Start one server first — it will auto-create the schema
5. Start remaining servers
6. Monitor logs on the first few player joins to confirm sync is working
