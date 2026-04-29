# Dogcraft PlayerBuffs

A server-wide buff system for Paper servers. Players can purchase temporary potion effects that apply to everyone on the server. Active buffs sync across a BungeeCord network using Redis, so buying a buff on one server activates it everywhere.

The system works like a Minecraft beacon — there's a clean registry of active effects that continuously apply to all eligible players. Redis TTL keys handle expiry automatically, and all servers read from the same source of truth.

## How It Works

1. A player opens the buff menu (via command or NPC) and purchases a buff with DCD currency
2. The buff is stored in Redis with a TTL matching the buff duration
3. Every 10 seconds, all servers sync from Redis and apply active effects to online players
4. When the TTL expires, the buff disappears from Redis and all servers stop applying it
5. Players can opt out of receiving buffs — this preference syncs across servers via Redis Pub/Sub

## For Players

### Buying Buffs
- Right-click the **McBuffy** NPC or run `/playerbuffs` to open the buff shop
- Click a buff to purchase it — the cost is shown on each item
- Buffs with an **enchantment glow** are already active
- Purchasing the same effect type again **extends the duration** — the new time is added onto whatever is remaining (e.g. 30s left + buying 5m = 5m 30s total)
- The GUI shows `(extends active)` on buffs that would add time to a running effect
- When a buff is extended the broadcast message shows the new total: `(extended! 7 min total)`

### Toggling Buffs
- When a buff activates, you'll see a broadcast message with a clickable **[Disable]** button
- Click it to stop receiving buffs, or run `/playerbuffs toggle`
- If you join with buffs disabled, you'll see a clickable **[Enable]** button
- Your preference is saved across servers and restarts

### Suffix Rewards
Purchasing buffs earns you suffixes via the Dogcraft SuffixManager. Two independent tracks:

| Track | Milestones |
|-------|-----------|
| **Buffs Purchased** | 1 / 10 / 100 / 500 / 1,000 individual purchases |
| **Buff Time Purchased** | 1h / 5h / 10h / 50h / 100h of total buff time |

Progress is tracked per-player in Redis and carries over server restarts. Suffixes unlock automatically when a milestone is reached. Thresholds, display text, descriptions, and icons are all configurable.

## Commands

| Command | Description |
|---------|-------------|
| `/playerbuffs` | Open the buff purchase menu |
| `/playerbuffs toggle` | Toggle receiving buffs for yourself |
| `/playerbuffs toggle <player>` | Toggle receiving buffs for another player |
| `/playerbuffs npc` | Spawn the buff NPC at your location |
| `/playerbuffs reload` | Reload the plugin configuration |

## Permissions

| Permission | Description |
|-----------|-------------|
| `serverbuff.command` | Use `/playerbuffs` to open the menu and reload config |
| `serverbuff.toggleother` | Toggle buffs for other players |
| `serverBuffs.admin` | Spawn the buff NPC |

## Configuration

### General Settings

```yaml
# Potion effect amplifier (0 = level 1, 1 = level 2, etc.)
Effect_Power: 1

# How often (in ticks) to apply effects and sync from Redis. 200 = every 10 seconds
Update_Time: 200

# Duration (in ticks) each effect application lasts. Should match Update_Time
Effect_Time: 200

# Enchantment used to indicate active buffs in the GUI
Enchantment: vanishing_curse

# Message broadcast when a buff is purchased (MiniMessage format)
# Placeholders: %Name% (buyer), %Buff% (buff name), %Time% (duration in minutes)
# Extensions automatically append "(extended! X min total)" after this message
Broadcast: '<aqua>Thanks %Name% for %Buff%, %Time% minute(s)'
```

### Redis

```yaml
Redis:
  Host: 'localhost'
  Port: 6379
  Password: ''
  KeyPrefix: 'playerbuffs:'
```

All servers in the network should point to the same Redis instance. If Redis is unavailable, the plugin falls back to BungeeCord plugin messaging for buff sync and local file storage for opt-out preferences.

### Admin Server

```yaml
# Set to true on ONE server - this server manages buff definitions for the network
AdminServer: false
```

The admin server loads buff definitions from its `config.yml` and pushes them to Redis. All other servers pull definitions from Redis automatically. When the admin server reloads (`/playerbuffs reload`), changes propagate to all servers within 10 seconds.

If no admin server is configured, each server uses its own local `config.yml`.

### NPC

```yaml
NPC:
  EntityType: 'ZOMBIE_HORSE'
  Name: '<yellow>McBuffy'
  Invulnerable: true
  Silent: true
  AI: false
```

The `EntityType` field accepts any valid Bukkit entity type. Change it to `SNIFFER`, `VILLAGER`, `ARMOR_STAND`, etc. — no code changes needed.

### Buff Definitions

```yaml
Buff_List:
  - Haste
  - Haste2

Haste:
  Item: 'WOODEN_PICKAXE'        # Material shown in the GUI
  Description: 'Haste for 1 minute'  # Item lore
  PotionEffect: 'haste'         # Minecraft potion effect key
  Slot: 0                       # GUI slot position
  Time: 1                       # Duration in minutes
  Cost: 100                     # Price in DCD
  Name: 'Haste 1m'              # Display name used in broadcasts

Haste2:
  Item: 'GOLDEN_PICKAXE'
  Description: 'Haste for 5 minutes'
  PotionEffect: 'haste'
  Slot: 1
  Time: 5
  Cost: 500
  Name: 'Haste 5m'
```

Multiple buffs can share the same `PotionEffect` (e.g. different durations of Haste). Only one effect of each type is active at a time. Purchasing the same effect type again appends the new duration onto the remaining time rather than replacing it. Remaining time survives server restarts because it is stored as a Redis TTL.

**Potion effect keys** use Minecraft namespaced keys: `haste`, `strength`, `resistance`, `invisibility`, `glowing`, `fire_resistance`, `water_breathing`, `speed`, `regeneration`, etc.

### Default Buffs

| Buff | Effect | Durations | Costs |
|------|--------|-----------|-------|
| Haste | `haste` | 1m / 5m / 1h | 100 / 500 / 5,000 DCD |
| Strength | `strength` | 1m / 5m / 1h | 100 / 500 / 5,000 DCD |
| Resistance | `resistance` | 1m / 5m / 1h | 100 / 500 / 5,000 DCD |
| Invisibility | `invisibility` | 1m | 250 DCD |
| Glowing | `glowing` | 1m | 250 DCD |
| Fire Resistance | `fire_resistance` | 1m | 250 DCD |
| Water Breathing | `water_breathing` | 1m | 100 DCD |

### Suffix Rewards

Suffix rewards require [Dogcraft-SuffixManager](https://dogcraft.net) to be installed. The plugin soft-depends on it — if it is absent, everything else continues to work normally.

```yaml
Suffixes:
  # Set to true to enable suffix rewards (requires Dogcraft-SuffixManager)
  Enabled: false
  # Namespace registered with SuffixManager — must be unique across all plugins
  Namespace: 'playerbuffs'

  # Milestones by number of individual buff purchases
  BuffCount:
    - Id: 'buff_buyer'          # Unique ID within the namespace
      Threshold: 1              # Purchases required to unlock
      DisplayText: '<yellow>[Buff Buyer]</yellow>'   # MiniMessage suffix text
      Description: 'Purchase your first server buff'
      IconMaterial: 'WOODEN_PICKAXE'
      FrameType: 'task'         # task / goal / challenge
    - Id: 'buff_supporter'
      Threshold: 10
      DisplayText: '<green>[Buff Supporter]</green>'
      Description: 'Purchase 10 server buffs'
      IconMaterial: 'IRON_PICKAXE'
      FrameType: 'task'
    # ... (see config.yml for remaining milestones)

  # Milestones by total minutes of buff time purchased
  BuffTime:
    - Id: 'time_patron'
      Threshold: 60             # Minutes required (60 = 1 hour)
      DisplayText: '<yellow>[Buff Patron]</yellow>'
      Description: 'Purchase 1 hour of server buff time'
      IconMaterial: 'CLOCK'
      FrameType: 'task'
    # ... (see config.yml for remaining milestones)
```

Cumulative purchase counts and total minutes are stored in Redis per-player with no expiry, so stats persist across restarts and network server changes.

## Architecture

### Redis Key Structure

| Key | Type | Purpose |
|-----|------|---------|
| `playerbuffs:active:<effect>` | String + TTL | Active buff state. Value: `buffName\|purchaser`. Expires automatically. |
| `playerbuffs:config` | Hash | Buff definitions pushed by admin server |
| `playerbuffs:config:version` | String | Version counter. Incremented on admin reload. Non-admin servers watch this. |
| `playerbuffs:optout` | Set | UUIDs of players who have disabled buffs |
| `playerbuffs:optout:channel` | Pub/Sub | Real-time opt-out sync. Messages: `add\|uuid` or `remove\|uuid` |
| `playerbuffs:stats:<uuid>:count` | String | Cumulative buff purchases for a player. No TTL. |
| `playerbuffs:stats:<uuid>:minutes` | String | Cumulative buff minutes purchased for a player. No TTL. |

### Sync Layers

1. **Redis (primary)** — Active buffs use TTL keys. Config uses a versioned hash. Opt-outs use Set + Pub/Sub. Player stats use persistent counters.
2. **BungeeCord Plugin Messaging (fallback)** — Buff activations are also sent via BungeeCord's `Forward` channel so servers without Redis still receive them.
3. **Save.yml (local fallback)** — Player opt-out preferences are saved to disk on shutdown in case Redis is unavailable on next startup.

### Class Overview

| Class | Responsibility |
|-------|---------------|
| `BuffRegistry` | Central authority on active buffs. Reads/writes Redis, maintains local cache, broadcasts activations. |
| `BuffManager` | Loads buff definitions from config or Redis. Pure catalog — no state. |
| `BuffEffect` | Data class for a single buff definition (item, cost, effect type, duration). |
| `ActiveBuff` | Data class for a currently-running buff (buff, purchaser, expiry time). |
| `EffectUpdater` | Repeating task that syncs from Redis and applies active effects to players. Also polls for admin config version changes. |
| `RedisManager` | Lettuce Redis client wrapper. Handles connections, TTL keys, hashes, sets, Pub/Sub, and player stat counters. |
| `GUI` | InventoryGui-based purchase menu with pagination and enchantment glow on active buffs. Handles extend-vs-new-purchase routing at click time. |
| `NPC` | Spawns and validates the configurable buff vendor entity. Entity type is read from config. |
| `NPCListener` | Opens GUI when players right-click the NPC. |
| `PluginMessage` | BungeeCord plugin messaging fallback for cross-server buff activation. |
| `PlayerJoin` | Notifies opted-out players on join with a clickable enable button. |
| `PlayerStatsManager` | Reads and increments per-player buff purchase counters in Redis. |
| `SuffixManagerHook` | Pure-reflection hook for Dogcraft-SuffixManager. No compile-time dependency. Registers suffix provider and pushes progress updates. |
| `SaveYML` | Manages the Save.yml file for local opt-out persistence. |

## Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| [Paper API](https://papermc.io) | 1.20.1+ | Server API (requires Java 17) |
| [DogcraftEconomy](https://repo.dogcraft.net) | 1.0.3+ | Currency system (hard depend) |
| [InventoryGui](https://repo.minebench.de) | 1.4.1 | GUI framework (shaded) |
| [Lettuce](https://lettuce.io) | 6.3.2 | Redis client (shaded) |
| [Dogcraft-SuffixManager](https://dogcraft.net) | — | Suffix rewards (soft depend — optional) |

InventoryGui and Lettuce are shaded into the plugin jar. Paper and DogcraftEconomy must be present on the server. SuffixManager is optional — suffix features are silently disabled when it is absent.

## Building

Requires **Java 17** or newer.

```bash
mvn clean package
```

The shaded jar will be at `target/serverbuffs-3.0.0-SNAPSHOT.jar`.
