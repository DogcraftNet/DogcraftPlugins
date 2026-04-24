# DogcraftClaims

A cross-server land claiming and block protection plugin for Paper/Purpur servers. Built for multi-server networks where players share a single identity, claim block balance, and trust list across all connected servers.

Inspired by GriefPrevention, DogcraftClaims adds cross-server sync via Redis, a built-in block lock system with group management, tiered staff ignore modes, and native DogcraftEconomy integration.

## Features

- **Cross-server claims** — Claims, balances, and trust lists sync in real time across all servers via MySQL + Redis Pub/Sub.
- **Self-service protection** — Players create and manage their own claims with a golden shovel, just like GriefPrevention.
- **Trust system** — Four trust tiers (Access, Container, Build, Manage) with public trust support.
- **Block locks** — Lock individual chests, doors, and other blocks independently of claims. Supports named player groups for shared access.
- **Admin claims** — Server-owned claims with no block cost, separate from player claims.
- **Subdivisions** — Split a claim into sub-claims with different trust settings per section.
- **Claim rentals** — List subclaims for rent; renters get full owner-level access until the rental expires. Auto-renewal, 30-day unlist grace period, and prorated refunds.
- **Claim flags** — Per-claim toggles for PvP, mob spawning, fire spread, explosions, and lock restriction.
- **Claim block economy** — Players earn blocks over time, purchase them with currency, or receive admin grants.
- **Proximity warnings** — Alerts players and staff when a new claim is created too close to an existing one.
- **Tiered staff bypass** — Container tier for inspecting grief reports, Owner tier for full access. Resets on login.
- **Claim visualization** — Gold block corners and glowstone edges shown via block packets when holding the inspection or claim tool.
- **Auto-updating configs** — New config options and messages are merged into your on-disk files on startup; obsolete keys are flagged but preserved.

## Requirements

- **Paper or Purpur** 1.21+
- **Java 21+**
- **MySQL or MariaDB** — Shared database for all servers
- **Redis** — Optional but recommended for real-time cross-server sync
- **DogcraftEconomy** — Optional, for `/buyclaimblocks` and claim rentals

---

## Getting Started

1. Place the plugin JAR in your server's `plugins/` folder.
2. Start the server once to generate the default `config.yml`.
3. Edit `plugins/DogcraftClaims/config.yml` with your database and Redis credentials.
4. Set a unique `server-name` for each server in your network.
5. Restart the server. The plugin will create all database tables automatically.

### Minimal config.yml

```yaml
database:
  host: "localhost"
  port: 3306
  name: "dogcraftclaims"
  user: "dogcraftclaims"
  password: "your-password-here"

redis:
  enabled: true
  host: "localhost"
  port: 6379

server-name: "survival"    # Must be unique per server
```

---

## How to Claim Land

### Creating a Claim

**Method 1 — Golden Shovel (two-click)**
1. Hold a **golden shovel**.
2. Right-click a block to set the first corner.
3. Right-click a second block to set the opposite corner.
4. The claim is created between those two corners, from bedrock to sky.

**Method 2 — Radius command**
```
/claim 15
```
Creates a 31x31 square claim centered on where you're standing (15 blocks in each direction).

### Inspecting Claims

Hold a **stick** and right-click a block to see who owns the claim, its area, trust list, and other details. You can also use `/claiminfo` while standing in a claim.

Staff with `dogcraftclaims.admin.lastseen` will additionally see the owner's last play time and which server they were last on — useful for identifying inactive claims.

### Resizing a Claim

Use the golden shovel on one of the existing corners of your claim, then click a new position to move that corner.

### Naming a Claim

```
/claimname My Base
```

### Abandoning Claims

```
/abandonclaim              — Abandon the claim you're standing in
/abandonallclaims confirm  — Abandon ALL your claims (irreversible)
```

When you abandon a claim, the claim blocks are returned to your balance (no currency refund).

### Listing Your Claims

```
/claimlist
```

Shows all your claims across every server and world, with name, location, and area.

### Transferring a Claim

```
/transferclaim <player>
```

Stand inside a claim you own and run the command with a target player's name. The plugin shows a confirmation prompt with a clickable **[Click to confirm transfer]** button. The target must have enough claim blocks to cover the claim's area.

Transfers are **not** allowed on admin claims or subdivisions (subdivisions move with their parent). Once confirmed, ownership is permanently transferred — there's no undo. Pending transfers expire after 30 seconds.

---

## Trust System

Trust controls who can do what inside your claim. There are four levels, each including all permissions of the levels below it:

| Level | What it allows |
|-------|---------------|
| **Access** | Enter the claim, use buttons, levers, doors, ride vehicles |
| **Container** | Open chests, furnaces, hoppers, barrels, brewing stands |
| **Build** | Place and break blocks, use all items |
| **Manage** | Add and remove trust for other players (up to Build level) |

### Granting Trust

```
/accesstrust PlayerName       — Grant Access trust
/containertrust PlayerName    — Grant Container trust
/trust PlayerName             — Grant Build trust
/managetrust PlayerName       — Grant Manage trust
```

To trust **all players** (public access), use `public` as the player name:
```
/containertrust public
```

### Removing Trust

```
/untrust PlayerName
```

### Viewing Trust

```
/trustlist
```

You must be standing inside your claim (or a claim where you have Manage trust) to use trust commands.

---

## Block Locks

Locks protect individual blocks — chests, doors, furnaces, etc. — even inside shared claims where everyone has Container trust. Locks are independent of claims and work on unclaimed land too.

### Locking a Block

1. Hold a **feather** (the lock tool).
2. **Right-click** a lockable block to select it. You'll see its current lock status.
3. **Left-click** the selected block to toggle the lock on or off.

### Managing Lock Access

```
/lock                        — Show info about the selected lock
/lock add PlayerName         — Allow a player to use this locked block
/lock remove PlayerName      — Revoke access
/lock transfer PlayerName    — Transfer lock ownership
/lock delete                 — Remove the lock entirely
```

### Lock Groups

Groups let you manage access across many locks at once. Add someone to a group and they instantly gain access to every lock that references it.

```
/lockgroup teammates add Alice Bob    — Create/update "teammates" group
/lock add teammates                   — Grant the group access to a lock
/lockgroup teammates remove Bob       — Remove Bob from the group
/lockgroup list                       — List all your groups
/lockgroup teammates                  — Show members of a group
/lockgroup teammates rename friends   — Rename a group
```

### Lockable Blocks

Configured in `config.yml`. Supports wildcard patterns:

```yaml
locks:
  tool: FEATHER
  lockable-blocks:
    - CHEST
    - TRAPPED_CHEST
    - BARREL
    - FURNACE
    - "*_DOOR"           # All door types (oak, iron, birch, etc.)
    - "*_TRAPDOOR"
    - "*_FENCE_GATE"
    - "*_BUTTON"
```

---

## Subdivisions

Subdivisions let you split a claim into sections with different trust settings. Useful for shared bases where you want a communal area and private rooms.

```
/subdivideclaims
```

Toggles subdivision mode. While active, the golden shovel creates sub-claims inside your existing claim instead of new top-level claims. Run the command again to switch back to normal mode.

Sub-claims inherit their parent's flags unless overridden.

---

## Claim Rentals

Owners can list subdivisions for rent. Renters pay the price (via DogcraftEconomy) and receive full owner-level access inside the subclaim until the rental expires. This works for both admin and player claims — a great fit for shops, apartments, or plot rentals on creative worlds.

### Listing a subclaim for rent

Stand inside a subdivision you own (or have Manage trust on) and run:

```
/claimrent list <price> [hours]
```

- `price` — rental cost in your server's currency
- `hours` — rental duration (default `168` = 7 days, use `0` for indefinite)

Only subdivisions can be listed. To unlist:

```
/claimrent unlist
```

### Renting a claim

Stand inside a listed claim and run `/claimrent rent`. The price is withdrawn from your balance and paid to the claim owner (admin claims withdraw the rent but no one receives it).

While rented, you have full owner-level access inside that subclaim — build, break, containers, lock placement — as if you owned it. Trust entries still apply.

**The original owner is locked out** while someone is renting (except staff with `/ignoreclaims owner`). This prevents owners from tampering with rented property.

### Renting management

```
/claimrent info              — see rental details for the claim you're in
/claimrent mine              — list all claims you're currently renting
/claimrent                   — browse all available rentals
/claimrent renew             — extend your rental by another period
/claimrent autorenew <on|off> — toggle auto-renewal at expiry
/claimrent cancel            — end your rental early (no refund)
```

### Auto-renewal

When `autorenew on` is set and your rental expires, the plugin attempts to charge you for another period automatically. If you can't afford it, the rental vacates normally.

Auto-renew is **automatically disabled** when the owner starts an unlist notice (see below), so you don't keep paying for a rental that's already ending.

### Owner unlist protection (30-day grace)

If the owner unlists the claim while you're actively renting, you **keep access for 30 more days**. At the end of the grace period:
- The rental ends
- You receive a **prorated refund** for the unused portion of your original rental
- Auto-renew stays off (cannot be re-enabled during a grace period)

This prevents owners from using `/claimrent unlist` to boot renters mid-rental and steal items. The owner can cancel the unlist notice via `/claimrent cancel-unlist` if they change their mind — auto-renew can be turned back on once the notice is cleared.

### Admin-only: auto-reset

```
/claimrent autoreset <on|off>
```

Requires `dogcraftclaims.admin.rental`. When enabled:

1. A **block snapshot** of the claim is captured the moment you flip `autoreset on` — every block inside the claim bounds (from world min to world max Y) is recorded.
2. When the rental **vacates** (renter cancels, rental expires without auto-renewal, or the 30-day grace period ends after an owner unlists), all blocks inside the claim are reset to the snapshot.
3. Non-player entities inside the claim (item frames, armor stands, dropped items) are removed before the restore.
4. The snapshot file persists for reuse — a plot gets reset to the same baseline each time it vacates. Turning `autoreset off` deletes the snapshot.

The restore runs in the background at a configurable rate (`rental.reset-blocks-per-tick` in `config.yml`, default 5000 blocks/tick). A 50×50 plot typically restores in 2–5 seconds; huge plots take longer but don't freeze the server.

Snapshots are stored in `plugins/DogcraftClaims/<snapshot-dir>/<claim-id>.snap` as GZIP-compressed block palette data.

**Caution:**
- Chests and containers inside the claim are overwritten during restore — any items stored in them when the renter vacates are lost. Tell renters to remove their belongings before their rental ends.
- Players standing inside the claim during a restore are not auto-teleported; make sure renters have left before triggering manually.

### Cross-server rentals

All rental state is stored in MySQL and synced via Redis. You can rent a plot on `creative-1` while standing on `survival`, though the rental commands must be used while physically standing in the claim.

---

## Claim Flags

Flags toggle specific behaviors. They can be set per-claim with `/claimflag` and also configured as server-wide global defaults in `config.yml`.

```
/claimflag <flag> <true|false>
```

### Player Flags

These can be set by the claim owner or anyone with Manage trust:

| Flag | Default | Effect when `true` |
|------|---------|-------------------|
| `PVP` | false | Players can damage each other |
| `FIRE_SPREAD` | true | Fire can spread |
| `EXPLOSIONS` | true | Explosions can damage blocks |
| `LOCK_RESTRICTED` | false | Only the claim owner can place new locks |
| `LEAF_DECAY` | true | Leaves decay naturally |
| `CROP_TRAMPLE` | false | Farmland can be trampled |

### Admin Flags

These require `dogcraftclaims.admin`:

| Flag | Default | Effect when `true` |
|------|---------|-------------------|
| `MOB_SPAWNING` | true | All natural/spawner mob spawns allowed |
| `HOSTILE_SPAWNING` | true | Hostile mob spawns allowed (checked after MOB_SPAWNING) |
| `KEEP_INVENTORY` | false | Players keep inventory and XP on death |
| `NO_ENTRY` | false | Non-trusted players cannot enter (blocks movement and teleportation) |
| `DENY_FLIGHT` | false | Flying is disabled inside the claim |
| `ENDERPEARL` | false | Non-trusted players can enderpearl into the claim |
| `VINE_GROWTH` | true | Vines, moss, sculk, kelp can spread |
| `SNOW_FORM` | true | Snow layers and ice can form |
| `EXCLUDE_LOGGING` | false | Suppress Dogcraft Logging in this claim |

### Global Flag Defaults

Global flags apply server-wide — both inside and outside of claims. Per-claim flags override the global default. Configure them in `config.yml`:

```yaml
global-flags:
  fire-spread: true       # true = vanilla behavior, false = blocked everywhere
  explosions: true
  pvp: true
  mob-spawning: true
  leaf-decay: true
  crop-trample: false
  keep-inventory: false
  no-entry: false
  deny-flight: false
  hostile-spawning: true
  enderpearl: false
  vine-growth: true
  snow-form: true
```

**Example:** Setting `fire-spread: false` globally blocks fire spread everywhere on the server. A claim can then set `/claimflag FIRE_SPREAD true` to re-enable it within that claim only. This effectively replaces the `doFireTick` gamerule with per-claim granularity.

### Require Claim Mode

For creative worlds or heavily managed servers, you can block all player actions (build, break, interact) outside of claims entirely:

```yaml
protection:
  require-claim: true
```

When enabled, players can only modify the world inside claims where they have the appropriate trust level. Unclaimed land is fully protected. Players with `dogcraftclaims.bypass.build` skip this restriction.

This is ideal for creative servers where every player gets a claim to build in and shouldn't be able to modify the rest of the world.

---

## Claim Blocks

Claim blocks are your budget for claiming land. Every block of area (length x width) costs one claim block.

### Checking Your Balance

```
/claimblocks
```

Shows earned blocks, bonus blocks, used blocks, and available blocks.

### Earning Blocks

Blocks accrue automatically while you're online. The rate is configured per server (default: 100 blocks/hour). Since the balance is global, it doesn't matter which server you're on.

### Buying Blocks

If DogcraftEconomy is installed:

```
/buyclaimblocks 500
/buyclaimblocks 500 confirm
```

The first command shows the cost and a clickable **[Click to confirm]** button — you can either click or re-type the command with `confirm` to charge your balance. Pending purchases expire after 30 seconds. Bulk discounts may apply depending on server configuration.

Claim blocks are **one-way** — they cannot be sold back for currency.

---

## Proximity Warnings

When you create a claim within a configurable distance (default: 100 blocks) of another player's claim, you'll receive a warning listing all nearby claims and their distances. Staff with the `dogcraftclaims.notify.proximity` permission are also notified across all servers.

```
/checkproximity              — Check the claim you're standing in
/checkproximity PlayerName   — Check all of a player's claims (staff only)
```

Proximity warnings are advisory only — the claim is still created.

---

## Staff Commands

### Ignore Claims

Staff can temporarily bypass claim protection for investigating grief reports or performing maintenance.

```
/ignoreclaims container    — Bypass Access + Container checks (open any chest)
/ignoreclaims owner        — Bypass ALL protection (full owner access everywhere)
```

Run the same command again to toggle it off. **Resets automatically on login.** An action bar reminder is shown while active.

| Tier | Permission | Can do |
|------|-----------|--------|
| Container | `dogcraftclaims.admin.ignoreclaims.container` | Open containers, use doors, interact with entities |
| Owner | `dogcraftclaims.admin.ignoreclaims.owner` | Everything the claim owner can do |

### Admin Claims

```
/adminclaim
```

Toggles admin claim mode. While active, the golden shovel creates admin claims (no owner, no block cost). Run again to switch back.

### Deleting Claims

```
/deleteclaim                   — Delete the claim you're standing in
/deleteallclaims PlayerName    — Delete all of a player's claims
```

### Managing Player Blocks

```
/adjustclaimblocks PlayerName 500     — Add 500 bonus blocks
/adjustclaimblocks PlayerName -200    — Remove 200 bonus blocks
/setclaimblocks PlayerName 1000       — Set earned blocks to 1000
/checkclaimblocks PlayerName          — View full balance breakdown
```

### Lock Administration

Players with `dogcraftclaims.lock.locksmith` can:
- `/lock delete` on any lock
- `/lock info` to see full details of any lock

---

## Permissions

### Player Permissions (default: true)

| Permission | Description |
|-----------|-------------|
| `dogcraftclaims.claim` | Create and manage own claims |
| `dogcraftclaims.trust` | Use trust commands |
| `dogcraftclaims.lock` | Place and manage locks |
| `dogcraftclaims.claimblocks.buy` | Purchase claim blocks |

### Staff Permissions (default: op)

| Permission | Description |
|-----------|-------------|
| `dogcraftclaims.admin` | Access all admin commands |
| `dogcraftclaims.admin.claim` | Create admin claims |
| `dogcraftclaims.admin.delete` | Delete any player's claims |
| `dogcraftclaims.admin.adjust` | Adjust any player's claim blocks |
| `dogcraftclaims.admin.ignoreclaims.container` | Enter Container ignore tier |
| `dogcraftclaims.admin.ignoreclaims.owner` | Enter Owner ignore tier |
| `dogcraftclaims.notify.proximity` | Receive proximity alerts |
| `dogcraftclaims.lock.locksmith` | Manage any player's locks |
| `dogcraftclaims.lock.ghost` | Bypass all locks |
| `dogcraftclaims.bypass.pvp` | Ignore PvP claim flags |
| `dogcraftclaims.bypass.build` | Bypass build protection |
| `dogcraftclaims.claim.fly` | Allowed to claim while flying |
| `dogcraftclaims.admin.lastseen` | See claim owner's last play time in `/claiminfo` |
| `dogcraftclaims.admin.rental` | Toggle rental auto-reset (admin-only rental feature) |

### Suggested Role Assignments

| Role | Permissions |
|------|------------|
| Player | Default permissions only |
| Mod | `dogcraftclaims.admin.ignoreclaims.container`, `dogcraftclaims.admin.delete`, `dogcraftclaims.lock.locksmith`, `dogcraftclaims.notify.proximity`, `dogcraftclaims.admin.lastseen` |
| Senior Mod / Admin | All of the above + `dogcraftclaims.admin.ignoreclaims.owner`, `dogcraftclaims.admin.adjust`, `dogcraftclaims.admin` |

---

## Cross-Server Sync

All servers in the network connect to the same MySQL database. Redis Pub/Sub broadcasts changes in real time so caches stay in sync without polling.

### What syncs instantly via Redis

- Claim creation, deletion, and resizing
- Trust changes
- Claim block balance updates
- Lock placement and removal
- Lock access and group membership changes
- Player messages (proximity alerts to staff on other servers)

### Redis as a Data Cache

In addition to Pub/Sub, Redis stores full claim data in hashes and owner-claim mappings in sets. This means cross-server lookups like `/claimlist` and `/claimblocks` read from Redis instantly without hitting the database. At startup, all local claims are bulk-loaded into Redis via pipeline.

### If Redis is unavailable

The plugin continues to work using the database directly. Changes made on other servers will be visible after a configurable polling interval (default: 60 seconds) or on player login.

---

## Server Identity (server_id.conf)

DogcraftClaims supports the shared `server_id.conf` identity file written by NetworkSwitch. This allows the plugin to automatically discover its Velocity-registered server name instead of relying on a hardcoded config value.

### How it works

1. At startup, if `use-server-id-conf` is `true`, the plugin reads `server_id.conf` from the server root directory.
2. If the file contains a `name` value, that becomes the server name.
3. If the file exists but the name is empty (Velocity hasn't responded yet), the plugin falls back to `server-name` from config and re-checks on the first player join.
4. When the name resolves and differs from the config fallback, the plugin automatically migrates all database rows (`claims`, `locks`, `player_profiles`) from the old name to the new one.

### Enabling it

```yaml
# config.yml
server-name: "survival"          # Fallback name used until server_id.conf is available
use-server-id-conf: true         # Enable reading from server_id.conf
```

### What gets updated at runtime

When the identity resolves on first player join:
- `MainConfig.getServerName()` returns the new name
- Redis Pub/Sub message filtering uses the new name
- All database rows with the old server name are migrated asynchronously

### Without NetworkSwitch

If you don't use NetworkSwitch, leave `use-server-id-conf: false` (the default). The plugin will use `server-name` from config as it always has.

---

## Configuration Reference

### Auto-updating config files

Both `config.yml` and `messages_en.yml` are auto-updated on every server startup:

- **New options** added in plugin upgrades are automatically merged into your on-disk file, with their default values and documentation comments from the JAR template. Your customized values are preserved — only missing keys are added.
- **Unknown options** (leftover keys from an older plugin version) get a `# UNKNOWN OPTION — this is not used by DogcraftClaims and can be safely removed.` comment prepended above them, so you can clean them up at your convenience.

The log shows every change at startup, e.g.:
```
[DogcraftClaims] [config.yml] Added missing option: rental.snapshot-dir
[DogcraftClaims] [config.yml] Marked unknown option: legacy-section.deprecated-key
[DogcraftClaims] [config.yml] Configuration file updated.
```

### Key settings

See the generated `config.yml` for all options. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `server-name` | `survival` | Unique identifier for this server |
| `use-server-id-conf` | `false` | Use server_id.conf from NetworkSwitch for the server name |
| `claims.min-size` | `100` | Minimum claim area in blocks |
| `claims.initial-blocks` | `500` | Starting claim blocks for new players |
| `claims.blocks-per-hour` | `100` | Blocks earned per hour online |
| `claims.max-earned-blocks` | `50000` | Cap on earned blocks (0 = unlimited) |
| `claims.proximity-warning.distance` | `100` | Warning distance between claims |
| `claims.investigation-tool` | `STICK` | Item for inspecting claims |
| `claims.modification-tool` | `GOLDEN_SHOVEL` | Item for creating/resizing claims |
| `locks.tool` | `FEATHER` | Item for managing block locks |
| `economy.enabled` | `true` | Enable `/buyclaimblocks` |
| `protection.require-claim` | `false` | Block all player actions outside of claims (creative worlds) |
| `rental.snapshot-dir` | `snapshots` | Directory under the plugin folder for rental auto-reset snapshots |
| `rental.reset-blocks-per-tick` | `5000` | Max blocks restored per tick during an auto-reset |

---

## Building from Source

Requires Java 21+ and Maven.

```bash
mvn clean package
```

The shaded JAR will be in `target/Dogcraft-Claims-1.0-SNAPSHOT.jar`.
