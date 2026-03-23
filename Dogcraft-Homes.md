# DogcraftHomes

A feature-rich home management plugin for Paper (1.21.1–1.21.4) with Velocity proxy support, economy integration, and inventory GUIs.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Commands](#commands)
  - [Player Commands](#player-commands)
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
  - [Cross-Server Teleporting](#cross-server-teleporting)
- [Home Sharing](#home-sharing)
- [Favorites & Default Home](#favorites--default-home)
- [Configuration](#configuration)
  - [config.yml](#configyml)
  - [GUIConfig.yml](#guiconfigyml)
  - [MessageConfig.yml](#messageconfigyml)
- [Storage & Caching](#storage--caching)
- [Proxy Setup (Velocity)](#proxy-setup-velocity)

---

## Features

- **Unlimited homes** with dynamic pricing — no hard limits, price scales per home
- **Public & private homes** — share locations with the server or keep them personal
- **Inventory GUIs** — clean chest-based interfaces for managing homes
- **Full chat interface** — every action can be done via clickable chat messages
- **Cross-server teleporting** — teleport to homes on other servers via Velocity proxy
- **Teleport warmup** with portal animation, movement cancellation, and bypass permission
- **Economy integration** — configurable pricing with exponential scaling and discount tiers
- **Deletion refunds** — configurable percentage refund when deleting homes
- **Favorites & default home** — mark homes as favorites, set a default for `/home`
- **One-time home sharing** — send clickable teleport invites to other players
- **Redis caching** — optional Redis layer for multi-server performance
- **Admin tools** — view, search, teleport to, and delete any player's homes

---

## Requirements

| Dependency | Required | Notes |
|---|---|---|
| **Paper** 1.21.1–1.21.4 | Yes | Not compatible with Spigot — uses Paper API |
| **MySQL/MariaDB** | Yes | For home storage |
| **Velocity** | Optional | For cross-server home teleporting |
| **DogcraftEconomy** | Optional | For home pricing, discounts, and refunds |
| **Redis** | Optional | For cross-server cache sync and pub/sub |

---

## Installation

1. Place `DogcraftHomes.jar` in your Paper server's `plugins/` folder
2. Start the server to generate config files
3. Edit `plugins/DogcraftHomes/config.yml` with your database credentials
4. (Optional) Install DogcraftEconomy and set `UseEconomy: true`
5. (Optional) Configure Redis for multi-server caching
6. Restart the server

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

All admin commands have tab completion for subcommands and online player names.

---

## Permissions

### Player Permissions

| Permission | Description | Default |
|---|---|---|
| `dogcrafthome.teleport.bypass` | Skip teleport warmup cooldown | op |
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
| `dogcrafthomes.admin.tp` | Teleport to any home (skips warmup and cost) | op |

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
   - Interior: Randomly cycling blue, light blue, and cyan stained glass panes that shimmer and change color
   - Double helix spiral particles spin around the player
   - If portal visual is disabled: particle-only fallback with colored dust
   - Only the teleporting player can see the portal — other players are unaffected
3. **Movement check** — moving more than 0.5 blocks during warmup cancels the teleport
4. **Teleport** — fade-out screen effect, teleport, fade-in with arrival sound and particles
5. **Portal cleanup** — the fake blocks are removed from the player's view after teleport

**Bypass:** Players with `dogcrafthome.teleport.bypass` skip the warmup entirely.

### Cross-Server Teleporting

With `Bungee: true` and a Velocity proxy:

1. Player runs `/home <name>` for a home on another server
2. Plugin sends a plugin message to the proxy with the home ID
3. Proxy transfers the player to the target server
4. Target server receives the arrival notification
5. Player is teleported to the home coordinates on join

The `ServerName` in config must match the server name in your Velocity `velocity.toml`.

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
ServerName: 'server'       # Must match the name in velocity.toml

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
  Portal:
    BuildPhysical: true      # Show visual portal frame around player (client-side only)
    FallbackParticles: true  # Show double helix particles if portal frame is disabled
    FrameMaterial: CRYING_OBSIDIAN
    # Fill uses randomly cycling blue/light blue/cyan glass panes
    ParticleColor: '0,150,255'
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

### GUIConfig.yml

Controls the appearance of inventory GUIs — border materials, button materials, and inventory slot layouts. Generated automatically on first run.

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

---

## Proxy Setup (Velocity)

1. Place `DogcraftHomes.jar` in both your Paper server `plugins/` folder **and** your Velocity proxy `plugins/` folder
2. Set `Bungee: true` in `config.yml` on each Paper server
3. Set `ServerName` on each server to match the server name in your `velocity.toml`
4. Ensure all servers share the **same MySQL database**
5. (Recommended) Enable Redis for cache synchronization across servers

The plugin registers on the `dogcrafthome:channel` plugin message channel. When a player teleports to a home on another server, the proxy routes them automatically.
