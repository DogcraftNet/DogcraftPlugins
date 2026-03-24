# DogcraftHomes

A feature-rich home and teleportation plugin for Paper (1.21.1–1.21.4) with Velocity proxy support, economy integration, and inventory GUIs.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Commands](#commands)
  - [Player Commands](#player-commands)
  - [Teleport Commands](#teleport-commands)
  - [Admin Commands](#admin-commands)
- [Permissions](#permissions)
- [GUI Systems](#gui-systems)
  - [Inventory GUI](#inventory-gui)
  - [Chat Interface](#chat-interface)
- [Economy & Pricing](#economy--pricing)
  - [Pricing Formula](#pricing-formula)
  - [Discount Tiers](#discount-tiers)
  - [Refunds](#refunds)
- [Teleportation](#teleportation)
  - [Warmup & Portal Effects](#warmup--portal-effects)
  - [Last Location Tracking (/back)](#last-location-tracking-back)
  - [Cross-Server Teleporting](#cross-server-teleporting)
  - [Vanish Integration](#vanish-integration)
- [Home Sharing](#home-sharing)
- [Favorites & Default Home](#favorites--default-home)
- [Configuration](#configuration)
  - [config.yml](#configyml)
  - [MessageConfig.yml](#messageconfigyml)
  - [Config Auto-Update](#config-auto-update)
- [Storage & Caching](#storage--caching)
  - [Redis Pub/Sub Channels](#redis-pubsub-channels)
- [Proxy Setup (Velocity)](#proxy-setup-velocity)
  - [Server Identity (server_id.conf)](#server-identity-server_idconf)
  - [Velocity Config](#velocity-config-configconf)
  - [Paper Redis Config](#paper-redis-config)

---

## Features

- **Unlimited homes** with dynamic pricing — no hard limits, price scales per home
- **Public & private homes** — share locations with the server or keep them personal
- **Inventory GUIs** — clean chest-based interfaces for managing homes
- **Full chat interface** — every action can be done via clickable chat messages
- **Player teleportation** — `/tpa`, `/tpahere`, `/back`, and admin `/tp`, `/tphere`, `/tppos` with cross-server support
- **Last location tracking** — `/back` returns you to your pre-teleport location, even across servers. Tracks teleports from other plugins too
- **Cross-server teleporting** — teleport to homes or players on other servers via Velocity proxy
- **Redis pub/sub messaging** — primary cross-server transport; plugin messages as fallback
- **Teleport warmup** with portal animation (blue for homes, purple for TPA), movement cancellation, and bypass permission
- **Vanish-aware effects** — integrates with vanish plugins to suppress particles, sounds, and portal visuals for vanished players
- **Economy integration** — configurable pricing with exponential scaling and discount tiers
- **Deletion refunds** — configurable percentage refund when deleting homes
- **Favorites & default home** — mark homes as favorites, set a default for `/home`
- **One-time home sharing** — send clickable teleport invites to other players
- **Redis caching** — optional Redis layer for multi-server cache sync and pub/sub messaging
- **Admin tools** — view, search, teleport to, and delete any player's homes

---

## Requirements

| Dependency | Required | Notes |
|---|---|---|
| **Paper** 1.21.1–1.21.4 | Yes | Not compatible with Spigot — uses Paper API |
| **MySQL/MariaDB** | Yes | For home storage |
| **Velocity** | Optional | For cross-server home teleporting |
| **DogcraftEconomy** | Optional | For home pricing, discounts, and refunds |
| **Redis** | Recommended | For cross-server messaging, cache sync, and vanish state relay. Without Redis, plugin messages are used as fallback (requires players online on target servers) |

---

## Installation

1. Place `DogcraftHomes.jar` in your Paper server's `plugins/` folder
2. Start the server to generate config files
3. Edit `plugins/DogcraftHomes/config.yml` with your database credentials
4. (Optional) Install DogcraftEconomy and set `UseEconomy: true`
5. (Optional) Configure Redis for caching and cross-server pub/sub messaging
6. (Multi-server) Place the same jar in your Velocity proxy `plugins/` folder — see [Proxy Setup](#proxy-setup-velocity)
7. Restart the server

---

## Commands

### Player Commands

#### `/sethome [name]`

Create a new home at your current location.

| Usage | Behavior |
|---|---|
| `/sethome` | Opens the creation GUI |
| `/sethome MyBase` | Chat-based creation with clickable `[Confirm]` `[Cancel]` `[Open GUI]` buttons |
| `/sethome confirm` | Confirms a pending chat-based home creation |
| `/sethome cancel` | Cancels a pending chat-based home creation |
| `/sethome gui` | Opens the GUI for a pending home creation |

> **Reserved names:** `bed` and `respawn` cannot be used as home names.

#### `/home [name]`

Teleport to a home.

| Usage | Behavior |
|---|---|
| `/home` | Teleport to your **default home** (⌂). If none set and `DefaultHome: true`, teleports to your bed/respawn point |
| `/home MyBase` | Teleport to the home named "MyBase" |
| `/home bed` | Always teleport to your bed/respawn location (ignores default home) |
| `/home respawn` | Same as `/home bed` |

#### `/homes [option]`

View your homes.

| Usage | Behavior |
|---|---|
| `/homes` | Opens the homes GUI |
| `/homes chat` | Shows a clickable list of your homes in chat |
| `/homes --chat` | Same as above |
| `/homes public` | Shows a clickable list of public homes in chat |

#### `/phome <name>`

Teleport to a public home by exact name.

#### `/edithome <name>`

Opens the edit GUI for a home. Available options:
- **Rename** — type a new name in chat
- **Change icon** — hold an item and click the icon slot
- **Update location** — set to your current position
- **Toggle favorite** (★)
- **Set as default** (⌂)
- **Delete** — with confirmation prompt

#### `/delhome <name>`

Delete a home. Shows a confirmation prompt with clickable `[Confirm]` and `[Cancel]` buttons. If a refund is configured, the refund amount is displayed before confirming.

#### `/homeshare <home> <player>`

Send a one-time teleport invite for one of your homes to another online player. See [Home Sharing](#home-sharing).

---

### Teleport Commands

Player-to-player teleportation with cross-server support. Uses a purple portal theme to distinguish from home teleports (blue).

#### `/tpa <player>`

Request to teleport to another player. The target player receives a clickable `[Accept]` `[Deny]` prompt. Requests expire after 60 seconds.

If the target is on another server, the request is delivered via Redis pub/sub. When accepted, the sender goes through the warmup/portal sequence and is transferred to the target's server automatically.

> **Vanish:** Vanished players are hidden from tab completion and cannot receive TPA requests unless the sender has `dogcrafthomes.vanish.see`.

#### `/tpahere <player>`

Request another player to teleport to you. Works the same as `/tpa` but the target player is the one who teleports after accepting.

#### `/tpaccept`

Accept a pending teleport request.

#### `/tpdeny`

Deny a pending teleport request.

#### `/back`

Teleport to your last location before a teleport. Uses the same warmup and purple portal as TPA commands.

- Tracks location before **every** teleport: `/home`, `/tpa`, `/tp`, `/tppos`, `/tphere` (target), cross-server arrivals, and teleports from other plugins
- **Same-server:** Standard warmup + portal sequence, then teleports to the saved location
- **Cross-server:** Requires both `Bungee: true` and Redis. Warmup runs locally, then transfers you to the other server and teleports to the saved coordinates
- Last locations are stored in Redis with a 24-hour TTL, so `/back` works even after disconnecting and rejoining
- Without Redis, only same-server `/back` is available

> **External teleport tracking:** DogcraftHomes also listens for `PlayerTeleportEvent` with causes `COMMAND`, `PLUGIN`, `SPECTATE`, and `UNKNOWN`. This means if another plugin (essentials, minigames, WorldGuard, etc.) teleports you, your pre-teleport location is saved for `/back`. Trivial teleports (less than 1 block) are ignored to avoid noise from look-direction changes.

---

### Admin Commands

Base command: `/homeadmin` — requires `dogcrafthomes.admin` permission.

All admin commands accept **player names** or **UUIDs**. Offline player data is loaded from the database automatically.

| Command | Permission | Description |
|---|---|---|
| `/homeadmin list <player>` | `dogcrafthomes.admin.info` | View all homes for a player. Each entry has clickable `[I]nfo` `[T]eleport` `[X]Delete` buttons |
| `/homeadmin info <id>` | `dogcrafthomes.admin.info` | Detailed view of a single home — owner, location, world, server, public status, favorite, default, icon |
| `/homeadmin delete <id>` | `dogcrafthomes.admin.delete` | Delete any home by database ID. Players get a confirmation prompt; console deletes immediately |
| `/homeadmin tp <id>` | `dogcrafthomes.admin.tp` | Teleport to any home by ID. **Skips warmup and cost** |
| `/homeadmin search <player> <name>` | `dogcrafthomes.admin.info` | Search a player's homes by partial name (case-insensitive) |
| `/tp <player>` | `dogcrafthomes.admin.tp` | Teleport to a player with warmup + purple portal. Supports cross-server — finds and transfers you automatically |
| `/tppos <x> <y> <z> [world]` | `dogcrafthomes.admin.tp` | Teleport to exact coordinates with warmup + purple portal. Supports `~` relative notation |
| `/tphere <player>` | `dogcrafthomes.admin.tp` | **Instantly** pull a player to your location (no warmup). Cross-server: transfers them to your server |
| `/tpahereall [local]` | `dogcrafthomes.admin.tp` | Send a TPA-here request to all players. With `local`, only players on your server |

All admin commands have tab completion for subcommands and online player names.

---

## Permissions

### Player Permissions

| Permission | Description | Default |
|---|---|---|
| `dogcrafthomes.back` | Use `/back` to return to last pre-teleport location | true |
| `dogcrafthome.teleport.bypass` | Skip teleport warmup and cooldown timers | op |
| `dogcrafthomes.vanish.see` | See vanished players in tab completion and send them TPA requests | op |
| `dogcrafthomes.discount.Tier1` | 5% discount on home pricing | false |
| `dogcrafthomes.discount.Tier2` | 10% discount on home pricing | false |
| `dogcrafthomes.discount.Tier3` | 25% discount on home pricing | false |
| `dogcrafthomes.discount.Tier4` | 50% discount on home pricing | false |

### Admin Permissions

| Permission | Description | Default |
|---|---|---|
| `dogcrafthomes.admin` | Parent — grants all admin sub-permissions below | op |
| `dogcrafthomes.admin.info` | View, list, and search any player's homes | op |
| `dogcrafthomes.admin.delete` | Delete any home by ID | op |
| `dogcrafthomes.admin.tp` | Teleport to any home or player. Also grants `/tp`, `/tppos`, `/tphere`, `/tpahereall` | op |

---

## GUI Systems

DogcraftHomes has two ways to interact with homes: inventory GUIs and clickable chat messages.

### Inventory GUI

The default GUI system using standard Minecraft chest inventories.

**Private Homes GUI** (`/homes`):
- 6-row inventory with a bordered layout
- Player head in the header showing home count
- Up to 28 homes per page with pagination arrows
- **Left-click** a home to teleport
- **Right-click** a home to open the edit GUI
- **Middle-click** a home to toggle favorite (★)
- **Sort button** — cycles through: Alphabetical → Most Recent → By Server → Favorites First
- **Switch View** button to jump to Public Homes

**Public Homes GUI**:
- Same layout as private homes
- Shows owner name on each home
- Left-click to teleport (read-only, no edit/delete)

**Home Creation GUI** (`/sethome`):
- Name input via chat
- Icon selection — hold any item and click the icon slot
- Public/Private toggle
- Live price display (red if you can't afford it)
- Confirm and Cancel buttons

**Home Edit GUI** (`/edithome <name>`):
- Rename, change icon, update location
- Favorite toggle (Nether Star / Coal)
- Default home toggle (Diamond / Iron Ingot)
- Delete button with confirmation

### Chat Interface

Every action can be performed entirely through chat with clickable text — no GUI required.

- `/sethome <name>` — shows a creation prompt with `[Confirm]` `[Cancel]` `[Open GUI]`
- `/homes chat` — clickable list of all your homes with teleport links
- `/homes public` — clickable list of public homes
- `/delhome <name>` — clickable `[Confirm]` and `[Cancel]` with refund preview
- Home info displays include `[Teleport]` `[Edit]` `[Delete]` action buttons

---

## Economy & Pricing

Requires **DogcraftEconomy** plugin and `UseEconomy: true` in config.

When economy is disabled, all homes are free.

### Pricing Formula

Homes get progressively more expensive the more you have. There are no hard home limits — the price curve is the natural limit.

**Private Homes** (exponential scaling):
```
price = baseCost × multiplier^(homeCount) × (1 - discount)
```

| Homes Owned | Price (base=100, mult=2) | Price (base=100, mult=1) |
|---|---|---|
| 0 (buying 1st) | 100 | 100 |
| 1 (buying 2nd) | 200 | 100 |
| 2 (buying 3rd) | 400 | 100 |
| 3 (buying 4th) | 800 | 100 |
| 4 (buying 5th) | 1,600 | 100 |

> With `IncrementalMultiplier: 1`, all homes cost the same flat rate. With `IncrementalMultiplier: 2`, each home costs double the previous.

**Public Homes** (linear scaling):
```
price = baseCost × (publicHomeCount + 1) × (1 - discount)
```

| Public Homes | Price (base=5000) |
|---|---|
| 0 (buying 1st) | 5,000 |
| 1 (buying 2nd) | 10,000 |
| 2 (buying 3rd) | 15,000 |

**Edit Cost:** A flat fee (`EditCost`) is charged each time a home is edited via `/edithome`.

### Discount Tiers

Discounts are granted via permissions. If a player has multiple discount permissions, the **highest tier** applies.

| Permission | Discount | Example (100 base) |
|---|---|---|
| `dogcrafthomes.discount.Tier1` | 5% | 95 |
| `dogcrafthomes.discount.Tier2` | 10% | 90 |
| `dogcrafthomes.discount.Tier3` | 25% | 75 |
| `dogcrafthomes.discount.Tier4` | 50% | 50 |

Custom tiers can be added in `config.yml` under `Discounts:` with any name. The permission becomes `dogcrafthomes.discount.<name>`.

### Refunds

When a player deletes a home, they can receive a partial refund. Controlled by `RefundPercent` in config (0.0–1.0, default 0.0 = no refund).

**How refunds are calculated:**

The refund uses the **marginal cost** approach — the cost of the player's most expensive (last) home slot at their current count. This means the refund is always fair regardless of which specific home is deleted.

```
refund = costOfLastHomeSlot × RefundPercent
```

| Example (base=100, mult=2, 95% refund) | Homes | Last Slot Cost | Refund |
|---|---|---|---|
| Player has 1 home, deletes it | 1 | 100 | 95 |
| Player has 3 homes, deletes one | 3 | 400 | 380 |
| Player has 5 homes, deletes one | 5 | 1,600 | 1,520 |

The delete confirmation prompt shows the refund amount in green before the player confirms. Refunds are logged as transactions in DogcraftEconomy.

> Admin deletions (`/homeadmin delete`) do **not** trigger refunds.

---

## Teleportation

### Warmup & Portal Effects

When a player teleports to a home, the following sequence occurs:

1. **Warmup countdown** — configurable duration (default 5 seconds), shown in the action bar
2. **Portal construction** — a 5-wide × 5-tall visual portal frame appears around the player (client-side only, no actual blocks placed)
   - Frame: Crying Obsidian (configurable)
   - **Home teleports (blue theme):** Randomly cycling blue, light blue, and cyan stained glass panes
   - **TPA teleports (purple theme):** Randomly cycling purple, magenta, and pink stained glass panes
   - Double helix spiral particles spin around the player (color matches the theme)
   - If portal visual is disabled: particle-only fallback with colored dust
   - Only the teleporting player can see the portal — other players are unaffected
3. **Movement check** — moving more than 0.5 blocks during warmup cancels the teleport
4. **Teleport** — fade-out screen effect, teleport, fade-in with arrival sound and particles
5. **Portal cleanup** — the fake blocks are removed from the player's view after teleport

**Bypass:** Players with `dogcrafthome.teleport.bypass` skip both the warmup and cooldown.

**Cooldown:** After teleporting, players must wait a configurable number of seconds (`CooldownSeconds`) before teleporting again. This applies to **all** teleport commands including admin commands (`/tp`, `/tphere`, etc.) — moderators with admin permissions but without the bypass permission will still be subject to cooldowns.

### Last Location Tracking (/back)

Every teleport saves the player's current location before moving them. This powers the `/back` command.

**What triggers a save:**
- All DogcraftHomes teleports: home teleports, TPA, admin `/tp`, `/tppos`, `/tphere` (saves the target's location), cross-server arrivals
- External teleports detected via `PlayerTeleportEvent` — covers other plugins and vanilla commands. Tracked causes:
  - `COMMAND` — vanilla `/tp`, other plugins' commands
  - `PLUGIN` — programmatic teleports by other plugins
  - `SPECTATE` — spectator mode teleport to an entity
  - `UNKNOWN` — catch-all for unclassified teleports

**How it avoids duplicates:**
- DogcraftHomes teleports save the location directly in `TeleportService` before executing
- The `PlayerTeleportEvent` listener runs at `MONITOR` priority and skips players that are in an active DogcraftHomes teleport sequence, so the same teleport isn't recorded twice
- Trivial teleports (less than 1 block distance, e.g. look-direction changes) are ignored

**Storage:**
- **In-memory:** `ConcurrentHashMap` for fast same-server lookups
- **Redis:** Stored as `dogcrafthomes:lastloc:{uuid}` with a 24-hour TTL for cross-server persistence
- On disconnect, the local cache entry is cleared but the Redis entry remains — so `/back` works after reconnecting or switching servers

### Cross-Server Teleporting

With `Bungee: true` and a Velocity proxy:

**Primary flow (Redis):**

1. Player runs `/home <name>` for a home on another server
2. Paper backend publishes a **transfer request** to Redis (`dogcrafthomes:transfer`)
3. Velocity proxy receives the request, finds the player, and transfers them to the target server
4. Velocity publishes an **arrival notification** to Redis (`dogcrafthomes:teleport`)
5. Target Paper server receives the arrival, looks up the home, and teleports the player on join

**Fallback flow (plugin messages):**

If Redis is unavailable, the same flow happens via Velocity plugin messages on the `dogcrafthome:channel` channel. This fallback requires at least one player connected to the target server to deliver the message.

**Important:** Each server's name must **exactly match** the server name in your Velocity `velocity.toml`. This is set via `ServerName` in `config.yml`, or automatically resolved from `server_id.conf` if `UseServerIdConf` is enabled (see [Server Identity](#server-identity-server_idconf)).

### Vanish Integration

DogcraftHomes integrates with vanish plugins that broadcast state on the `dogcraft:vanish` channel. When a player vanishes or unvanishes:

1. The vanish plugin sends a message to Velocity on `dogcraft:vanish`
2. Velocity receives it and relays the state to all Paper backends:
   - **Primary:** publishes to Redis channel `dogcrafthomes:vanish`
   - **Fallback:** sends via plugin message on `dogcrafthome:channel` (subchannel `vanish`)
3. Each Paper server updates its in-memory vanish state

**What vanish suppresses:**
- Portal frame and glass pane visuals (only the vanished player sees their own portal)
- Double helix spiral particles — sent only to the vanished player, not visible to others
- Departure and arrival sound effects — played only for the vanished player
- All teleport-related particle effects use `player.spawnParticle()` instead of `world.spawnParticle()` when vanished

---

## Home Sharing

`/homeshare <home> <player>` sends a **one-time teleport invite** to an online player.

**How it works:**
1. You run `/homeshare MyBase Steve`
2. Steve receives a chat message with clickable `[Accept]` and `[Decline]` buttons
3. If Steve clicks **Accept**, he is teleported to your home (one time only)
4. If Steve clicks **Decline** or the invite expires (5 minutes), nothing happens
5. You receive a notification of their response

Sharing is not persistent — each invite is a single-use teleport. There is no permanent shared homes list.

---

## Favorites & Default Home

### Favorites (★)

Mark any home as a favorite to make it easier to find:
- **Middle-click** in the homes GUI to toggle
- **Edit GUI** has a dedicated favorite toggle button (Nether Star)
- Favorites sort to the top when using "Favorites First" sort mode
- Favorites display with a ★ prefix in all GUIs and chat lists

### Default Home (⌂)

Set one home as your default — used when you run `/home` with no arguments:
- **Edit GUI** has a "Set as Default" button (Diamond)
- Only one home can be default at a time (setting a new one clears the previous)
- Default homes display with a ⌂ prefix
- `/home` priority: **default home** → **bed/respawn** (if `DefaultHome: true`) → usage message
- `/home bed` always goes to bed spawn regardless of default home setting

---

## Configuration

### config.yml

```yaml
## Database Settings ##
Database:
  Name: 'dogcraft'
  User: 'root'
  Password: 'password'
  Host: 'localhost:3306'
  PoolSize: 6              # HikariCP connection pool size

## Redis Settings (Optional) ##
Redis:
  Enabled: false
  Host: 'localhost'
  Port: 6379
  Password: ''
  Database: 0
  PoolSize: 4

## Proxy Settings ##
Bungee: false              # Enable Velocity/BungeeCord cross-server support
ServerName: 'server'       # Must match the name in velocity.toml (fallback if UseServerIdConf is enabled)
UseServerIdConf: false     # Use server_id.conf from NetworkSwitch for server name resolution

## General Settings ##
DefaultIcon: 'OAK_DOOR'    # Default Material for new home icons
SaveTime: 30               # Auto-save interval in seconds
UseEconomy: false           # Enable DogcraftEconomy integration
DefaultHome: true           # /home (no args) falls back to bed/respawn if no default set

## Pricing ##
PublicCost: 5000            # Base cost for public homes
PrivateCost: 100            # Base cost for private homes
EditCost: 100               # Flat cost to edit a home
IncrementalMultiplier: 1    # Price multiplier per home (1 = flat, 2 = doubles each)

## Refunds ##
RefundPercent: 0.0          # Refund on deletion (0.0 = none, 0.95 = 95%)

## Teleport Settings ##
Teleport:
  WarmupSeconds: 5          # Seconds before teleport (0 to disable)
  CooldownSeconds: 0        # Seconds between teleports (0 to disable)
  Portal:
    BuildPhysical: true      # Show visual portal frame around player (client-side only)
    FallbackParticles: true  # Show double helix particles if portal frame is disabled
    FrameMaterial: CRYING_OBSIDIAN
    # Fill uses randomly cycling blue/light blue/cyan glass panes
    ParticleColor: '0,150,255'
  TpaPortal:
    # TPA portal uses purple/magenta/pink glass panes
    ParticleColor: '180,100,255'
  Effects:
    DepartureSound: ENTITY_ENDERMAN_TELEPORT
    ArrivalSound: BLOCK_BEACON_ACTIVATE
    ParticleCount: 50

## Discount Tiers ##
# Permission format: dogcrafthomes.discount.<TierName>
Discounts:
  Tier1: 0.05               # 5%
  Tier2: 0.1                # 10%
  Tier3: 0.25               # 25%
  Tier4: 0.5                # 50%

## Debug ##
Debug: true                 # Enable debug logging
```

### MessageConfig.yml

All player-facing messages support `%HOME%` as a placeholder for the home name:

```yaml
HomeDeleted: '&2The home %HOME% was deleted!'
UnableToFindHome: '&4Unable to find the home %HOME%.'
Teleporting: '&eTeleporting to %HOME%.'
DuplicateHomeName: '&4You already have a home named %HOME%.'
EconomyError: '&4Something went wrong when trying to purchase this home.'
HomeSetSuccess: '&2Home %HOME% was set!'
CantSendPluginMessage: '&4Could not teleport! Please contact a staff member!'
HomeUnavailable: 'Cross server homes are disabled at the moment!'
PluginMessageError: 'Something went wrong, please try again. /home %HOME%'
```

### Config Auto-Update

On startup, DogcraftHomes checks `config.yml` and `MessageConfig.yml` for missing keys and adds them with their default values. This means upgrading the plugin version won't require manually adding new config entries — they appear automatically the next time the server starts. Added keys are logged to the console.

The Velocity proxy plugin uses Configurate (HOCON) and handles its own default population in the same way.

---

## Storage & Caching

### Database Schema

**Locations table** — stores all homes:

| Column | Type | Description |
|---|---|---|
| `id` | INT (PK, auto) | Unique home ID |
| `name` | VARCHAR(2000) | Home name |
| `world` | VARCHAR(2000) | World name |
| `x`, `y`, `z` | DOUBLE | Coordinates |
| `public` | BOOLEAN | Public visibility |
| `uuid` | VARCHAR(36) | Owner UUID |
| `servername` | VARCHAR(2000) | Server name |
| `icon` | VARCHAR(2000) | Material name for GUI icon |
| `created_at` | BIGINT | Creation timestamp |
| `favorite` | BOOLEAN | Favorite flag |
| `is_default` | BOOLEAN | Default home flag |

Schema migrations run automatically on startup — new columns are added if they don't exist.

### Caching Layers

1. **In-Memory** — `HomeManager` holds all online players' homes with O(1) name lookup. Public homes are preloaded on startup.
2. **Redis** (optional) — read-through cache with 10-minute TTL for player homes, 5-minute TTL for public homes. Cross-server invalidation via pub/sub.
3. **MySQL** — persistent storage, accessed asynchronously via `CompletableFuture`.

Player homes are loaded asynchronously during `AsyncPlayerPreLoginEvent` so they're ready before the player finishes joining.

### Redis Pub/Sub Channels

When Redis is enabled, the following channels are used for cross-server communication:

| Channel | Direction | Purpose |
|---|---|---|
| `dogcrafthomes:transfer` | Paper → Velocity | Player requests transfer to another server for a home teleport |
| `dogcrafthomes:teleport` | Velocity → Paper | Arrival notification — target server should teleport the player to a home |
| `dogcrafthomes:vanish` | Velocity → Paper | Vanish state broadcast — all servers update their vanish tracking |
| `dogcrafthomes:invalidate` | Paper ↔ Paper | Cache invalidation — a home was created, updated, or deleted |
| `dogcrafthomes:sync` | Paper ↔ Paper | Home data synchronization between servers |
| `dogcrafthomes:tpa` | Paper ↔ Paper | TPA request/response messages (request, accept, deny, admin tp/pull) |
| `dogcrafthomes:tpa-transfer` | Paper → Velocity | Player needs transfer to another server for a TPA teleport |
| `dogcrafthomes:tpa-arrive` | Velocity → Paper | TPA arrival — target server should teleport the player to another player |
| `dogcrafthomes:back-transfer` | Paper → Velocity | Player uses `/back` to a location on another server — transfer them |
| `dogcrafthomes:back-arrive` | Velocity → Paper | /back arrival — target server should teleport the player to saved coordinates |

Both the Velocity proxy plugin and each Paper backend maintain their own Redis connections. If Redis becomes unavailable at runtime, all messaging falls back to Velocity plugin messages automatically.

---

## Proxy Setup (Velocity)

1. Place `DogcraftHomes.jar` in both your Paper server `plugins/` folder **and** your Velocity proxy `plugins/` folder
2. Set `Bungee: true` in `config.yml` on each Paper server
3. Set `ServerName` on each server to **exactly match** the server name in your `velocity.toml`, or enable `UseServerIdConf` to resolve the name automatically from `server_id.conf`
4. Ensure all servers share the **same MySQL database**
5. **(Recommended)** Enable Redis on both Paper servers and the Velocity proxy
6. Start the Velocity proxy once to generate `plugins/dogcrafthomes/config.conf`
7. Configure the Velocity Redis settings (see below)

### Server Identity (`server_id.conf`)

If you use [NetworkSwitch](https://github.com/your-org/networkswitch) or a similar plugin that writes a shared `server_id.conf` file to the server root, DogcraftHomes can read it to automatically resolve the server name instead of requiring manual `ServerName` configuration.

To enable this, set `UseServerIdConf: true` in `config.yml`. When enabled:

1. On startup, DogcraftHomes reads `server_id.conf` from the server root directory
2. If the file has a `name` field, that name is used and takes priority over `ServerName` in config
3. If the file doesn't have a name yet (first-ever startup), `ServerName` is used temporarily
4. On first player join, the file is re-checked — NetworkSwitch writes the name after Velocity confirms it
5. If the resolved name differs from the old `ServerName`, all homes in the database are automatically migrated to the new name

When `UseServerIdConf: false` (the default), `ServerName` from config.yml is always used.

### Velocity Config (`config.conf`)

The Velocity proxy plugin uses a HOCON config file at `plugins/dogcrafthomes/config.conf` (powered by Configurate):

```hocon
# Redis pub/sub settings for cross-server messaging
redis {
    enabled = true
    host = "localhost"
    port = 6379
    password = ""
    database = 0
}
```

> **Migration:** If upgrading from a version that used `config.properties`, the old file is automatically migrated to `config.conf` and renamed to `config.properties.old`.

When Redis is enabled on Velocity, it becomes the **primary transport** for all cross-server messaging:
- **Home transfer requests** from Paper backends (player wants to teleport to a home on another server)
- **TPA transfer requests** from Paper backends (player needs to move to another server for a TPA)
- **/back transfer requests** from Paper backends (player uses `/back` to a location on another server)
- **Arrival notifications** to Paper backends (player has arrived, teleport them to home/player/coordinates)
- **Vanish state relay** from vanish plugins to all backends

Missing keys are added automatically with defaults on startup, same as the Paper-side config updater.

If Redis is disabled or unavailable, the proxy falls back to Velocity plugin messages on `dogcrafthome:channel`. This fallback works but requires at least one player on the target server to deliver messages.

### Paper Redis Config

Each Paper server's `config.yml` has its own Redis section for caching and pub/sub:

```yaml
Redis:
  Enabled: true
  Host: 'localhost'
  Port: 6379
  Password: ''
  Database: 0
  PoolSize: 4
```

Both the Velocity proxy and all Paper servers should point to the **same Redis instance**.
