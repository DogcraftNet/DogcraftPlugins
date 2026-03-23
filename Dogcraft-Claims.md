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
- **Claim flags** — Per-claim toggles for PvP, mob spawning, fire spread, explosions, and lock restriction.
- **Claim block economy** — Players earn blocks over time, purchase them with currency, or receive admin grants.
- **Proximity warnings** — Alerts players and staff when a new claim is created too close to an existing one.
- **Tiered staff bypass** — Container tier for inspecting grief reports, Owner tier for full access. Resets on login.
- **Claim visualization** — Gold block corners and glowstone edges shown via block packets when holding the inspection or claim tool.

## Requirements

- **Paper or Purpur** 1.21+
- **Java 21+**
- **MySQL or MariaDB** — Shared database for all servers
- **Redis** — Optional but recommended for real-time cross-server sync
- **DogcraftEconomy** — Optional, for `/buyclaimblocks`

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

Hold a **stick** and right-click a block to see who owns the claim, its area, trust list, and other details.

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

## Claim Flags

Flags toggle specific behaviors inside a claim.

```
/claimflag <flag> <true|false>
```

| Flag | Default | Effect when `true` |
|------|---------|-------------------|
| `PVP` | false | Players can damage each other inside the claim |
| `MOB_SPAWNING` | false | Natural and spawner mob spawns are allowed |
| `FIRE_SPREAD` | false | Fire can spread inside the claim |
| `EXPLOSIONS` | false | Explosions can damage blocks inside the claim |
| `LOCK_RESTRICTED` | false | Only the claim owner (or admins for admin claims) can place new locks |

You must own the claim or have Manage trust to change flags.

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

The first command shows the cost. The second confirms the purchase. Bulk discounts may apply depending on server configuration.

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

### Suggested Role Assignments

| Role | Permissions |
|------|------------|
| Player | Default permissions only |
| Mod | `dogcraftclaims.admin.ignoreclaims.container`, `dogcraftclaims.admin.delete`, `dogcraftclaims.lock.locksmith`, `dogcraftclaims.notify.proximity` |
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

### If Redis is unavailable

The plugin continues to work using the database directly. Changes made on other servers will be visible after a configurable polling interval (default: 60 seconds) or on player login.

---

## Configuration Reference

See the generated `config.yml` for all options. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `server-name` | `survival` | Unique identifier for this server |
| `claims.min-size` | `100` | Minimum claim area in blocks |
| `claims.initial-blocks` | `500` | Starting claim blocks for new players |
| `claims.blocks-per-hour` | `100` | Blocks earned per hour online |
| `claims.max-earned-blocks` | `50000` | Cap on earned blocks (0 = unlimited) |
| `claims.proximity-warning.distance` | `100` | Warning distance between claims |
| `claims.investigation-tool` | `STICK` | Item for inspecting claims |
| `claims.modification-tool` | `GOLDEN_SHOVEL` | Item for creating/resizing claims |
| `locks.tool` | `FEATHER` | Item for managing block locks |
| `economy.enabled` | `true` | Enable `/buyclaimblocks` |

---

## Building from Source

Requires Java 21+ and Maven.

```bash
mvn clean package
```

The shaded JAR will be in `target/Dogcraft-Claims-1.0-SNAPSHOT.jar`.
