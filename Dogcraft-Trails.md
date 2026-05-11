# Dogcraft-Trails

Particle trails and non-obstructive auras for the Dogcraft network. Players unlock trails by purchase (DogcraftEconomy) or temporarily via monthly Patreon rotations, equip one at a time through a chat-based UI, and trail selection follows them across servers through Redis pub/sub.

- Paper **1.21.9+** (required — preview system uses the `Mannequin` entity)
- Java **21**
- MySQL + Redis (Redis is optional but recommended for multi-server networks)

---

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Commands](#commands)
4. [Permissions](#permissions)
5. [Configuration](#configuration)
   - [config.yml](#configyml)
   - [trails.yml — the catalog](#trailsyml--the-catalog)
   - [Default trail catalog](#default-trail-catalog)
6. [Trail Gates](#trail-gates)
7. [Patreon Monthly Rotation](#patreon-monthly-rotation)
8. [Cross-Server Selection Sync](#cross-server-selection-sync)
9. [Renderers](#renderers)
10. [Preview System](#preview-system)
11. [Database Schema](#database-schema)
12. [Auto-Updating Configs](#auto-updating-configs)
13. [Building from source](#building-from-source)
14. [Troubleshooting](#troubleshooting)

---

## Features

- 50 trails across 10 themed categories (simple → complex within each category)
- One-slot active selection per player; choose between behind-trail particles and non-obstructive auras (e.g. butterfly wings)
- Adventure chat UI with paginated browsing, click-to-equip, click-to-buy, hover tooltips
- Mannequin-based previews for aura trails (Paper 1.21.9+); 10-second drifting previews for behind-trails
- Permission-gated trails (staff-only, Patreon-exclusive, event-only)
- Monthly Patreon rotations with random allocation and automatic re-roll away from already-owned trails
- Cross-server selection sync over Redis pub/sub
- Hot-reload via `/traila reload`
- Self-updating configs: missing keys are added with defaults; deprecated keys are flagged with a comment but never deleted

---

## Installation

1. Drop the shaded jar (`Dogcraft-Trails-1.0-SNAPSHOT.jar`) into each server's `plugins/` directory.
2. Start once. The plugin creates `plugins/Dogcraft-Trails/config.yml` and `trails.yml` from bundled defaults, then disables itself with a clear error if it can't reach the database.
3. Edit `config.yml` — set your MySQL and Redis hosts, pick a unique `network.server.Name` per server.
4. Start again. The MySQL schema is created automatically. Console reports `Loaded 10 categories and 50 trails.`
5. Optionally install [DogcraftEconomy](https://repo.dogcraft.net) if you want purchase support. The plugin works without it (purchase commands will just say economy is unavailable).

There is **no LuckPerms dependency**. The plugin uses standard Bukkit `player.hasPermission(...)`, so any permission provider works.

---

## Commands

### Player commands — `/trail` (alias `/trails`)

| Command | Description |
|---|---|
| `/trail` | Opens the main chat menu — your current selection, an owned-count, and a list of categories. |
| `/trail browse <category> [page]` | Paginated view of one category. Most click-events in the menu route through this. |
| `/trail mine [page]` | Paginated view of trails you currently own (purchased + active Patreon grants). |
| `/trail select <id>` | Equip a trail you own. Equivalent to clicking `[Equip]` in chat. |
| `/trail off` | Stop rendering your trail without losing the selection. |
| `/trail on` | Resume rendering. |
| `/trail preview <id>` | Spawn a 10-second preview. Aura trails render on a Mannequin clone of you; behind-trails drift away from your position. |
| `/trail buy <id>` | Show a confirmation prompt with `[Confirm]` and `[Cancel]` clickables. |
| `/trail buy <id> confirm` | Internal — only invoked by the confirm click; this is the path that actually charges the player. |
| `/trail patreon` | List your active Patreon monthly grants and how many days each has left. |
| `/trail help` | Short text help for the subcommands. |

### Admin commands — `/traila`

Require `dogcrafttrails.admin` (defaults to OP).

| Command | Description |
|---|---|
| `/traila reload` | Reload configs (`config.yml` + `trails.yml`), re-register tier/gate permissions, restart tasks. Online players stay loaded. |
| `/traila grant <player> <trail-id>` | Permanently grants ownership. Bypasses gates and economy. Source recorded as `admin` in the DB. |
| `/traila revoke <player> <trail-id>` | Removes a permanent ownership row. Does not touch Patreon grants. |
| `/traila rotate <player>` | Forces a Patreon rotation evaluation for an online player. Useful right after assigning a tier permission. |

---

## Permissions

| Node | Default | Purpose |
|---|---|---|
| `dogcrafttrails.use` | `true` | Base — required to interact with the trail system at all. |
| `dogcrafttrails.buy` | `true` | Required to purchase trails through `/trail buy`. |
| `dogcrafttrails.admin` | `op` | Required for `/traila` admin commands. |
| `dogcrafttrails.bypass` | `false` | Overrides gates and ownership — staff/preview perm. Selects-without-owning. |

### Programmatically registered

Three groups of permissions are registered at runtime with `default: false`. This is so OPs do not auto-inherit them (mirrors the MobHeads pattern):

1. **Patreon tier nodes** — every key in `PatreonMonthlyTrailGrants` (default: `dogcrafttrails.tier1` … `tier4`).
2. **Gate nodes** — every key in `TrailGates` (you define these).

A reload re-scans both blocks and re-registers any new nodes. Removing a key from the config and reloading unregisters that permission cleanly.

---

## Configuration

Two files are auto-created on first start. Both are auto-updated on every start: missing keys are appended (with the default value and a `# Added in vX.Y` comment), and any keys present in your file that the plugin no longer recognises get a `# DEPRECATED in vX.Y — no longer used, safe to remove` comment prepended (the data is **not** deleted — your call).

### `config.yml`

```yaml
general:
  Debug: false

# Used in cross-server Redis payloads so a server can ignore its own
# broadcasts. Must be unique per server in your network.
network:
  server:
    Name: 'lobby'

database:
  Host: 'localhost:3306'
  Database: 'trails'
  Username: 'user'
  Password: 'password'
  pool:
    maxSize: 5
    minIdle: 2
    connectionTimeout: 5000

# Optional. Without Redis, single-server still works; selection won't propagate.
redis:
  Host: 'localhost:6379'
  Expiry_seconds: 7200

ui:
  page-size: 5                     # trails per page in /trail browse
  show-locked-as-mystery: false    # true = render gated trails as `🔒 ???`; false = hide
  colors:
    owned:   '#7CFC00'
    locked:  '#888888'
    patreon: '#FFB347'
    button:  '#5DADE2'
    border:  '#444444'

render:
  interval-ticks: 2                # 2 = ~10 Hz. Lower = smoother, more CPU.
  hide-while-sneaking: true
  hide-while-vanished: true
  hide-while-spectator: true

preview:
  duration-seconds: 10
  cooldown-seconds: 15
  distance-blocks: 4               # mannequin spawn distance in front of the player
  allow-in-combat: false
  fallback-when-cramped: 'offset'  # offset | cancel

PatreonMonthlyTrailGrants:
  dogcrafttrails.tier1: 1
  dogcrafttrails.tier2: 2
  dogcrafttrails.tier3: 3
  dogcrafttrails.tier4: 5

PatreonRotation:
  grant-window-days: 31
  reroll-attempts: 50
  catch-up-on-join: true

TrailGates: {}                     # see Trail Gates section below
```

### `trails.yml` — the catalog

Two top-level sections: `categories` and `trails`.

**Categories** are simple metadata blocks:

```yaml
categories:
  wings:
    display: 'Wings'
    description: 'Wing-shaped auras that don''t obscure your view.'
```

**Trails** are keyed by id. Trail ids contain a dot (e.g. `wings.butterfly`) — the first segment is conventionally the category, but the only hard requirement is that the trail's `category` field references a defined category id.

```yaml
trails:
  wings.butterfly:
    category: wings
    display: 'Butterfly Wings'
    lore: 'Flutter behind you in pastel blues.'
    renderer: wings
    price: 11000
    params:
      particle: DUST
      colorRgb: '#A8D8FF'
      flapHz: 2.0
      span: 0.6
      density: 14
```

Available fields:

| Field | Type | Notes |
|---|---|---|
| `category` | string | Must match a key under `categories`. |
| `display` | string | Shown in the chat UI. |
| `lore` | string | One-line description shown under the trail name. Optional. |
| `renderer` | string | One of `behind_foot`, `helix`, `circle_aura`, `column`, `wings`, `dust_cloud`. |
| `price` | number | Cost in DogcraftEconomy units. `0` is allowed (free purchase). |
| `params` | section | Renderer-specific knobs. See [Renderers](#renderers). |

> **About dotted ids:** Bukkit's YAML loader splits keys on `.`, so `wings.butterfly` becomes nested sections `wings → butterfly` internally. The catalog walker uses `getKeys(true)` and treats any section with a `category` field as a trail definition. You can therefore use dotted ids freely — the path is the trail id everywhere else in the system (DB, commands, gates).

### Default trail catalog

50 trails across 10 categories, ordered simple → complex within each category. Prices in DogcraftEconomy units.

#### Footsteps — particles on each step
| Id | Display | Renderer | Price |
|---|---|---|---|
| `footstep.dust` | Dust Steps | `behind_foot` | 500 |
| `footstep.heart` | Heart Steps | `behind_foot` | 1,500 |
| `footstep.note` | Note Steps | `behind_foot` | 2,000 |
| `footstep.star` | Star Steps | `behind_foot` | 3,500 |
| `footstep.crystal` | Crystal Trail | `helix` | 7,500 |

#### Sparkles — subtle shimmer trailing your path
| Id | Display | Renderer | Price |
|---|---|---|---|
| `sparkle.silver` | Silver Sparkles | `behind_foot` | 1,000 |
| `sparkle.gold` | Gold Sparkles | `behind_foot` | 2,000 |
| `sparkle.rainbow` | Rainbow Sparkles | `behind_foot` | 4,000 |
| `sparkle.glow` | Glow Sparkles | `behind_foot` | 5,500 |
| `sparkle.starlight` | Starlight Helix | `helix` | 8,500 |

#### Flame — fire and embers
| Id | Display | Renderer | Price |
|---|---|---|---|
| `flame.ember` | Embers | `behind_foot` | 1,200 |
| `flame.fire` | Fire | `behind_foot` | 2,500 |
| `flame.soul` | Soul Fire | `behind_foot` | 4,500 |
| `flame.lava` | Lava Drops | `behind_foot` | 6,000 |
| `flame.phoenix` | Phoenix | `wings` | 12,000 |

#### Frost — snow and ice
| Id | Display | Renderer | Price |
|---|---|---|---|
| `frost.snow` | Snowflakes | `behind_foot` | 1,000 |
| `frost.ice` | Ice Shards | `behind_foot` | 2,500 |
| `frost.blizzard` | Blizzard | `dust_cloud` | 4,500 |
| `frost.crystal` | Crystal Shimmer | `helix` | 7,000 |
| `frost.aurora` | Aurora | `wings` | 13,000 |

#### Magic — arcane sparks and runes
| Id | Display | Renderer | Price |
|---|---|---|---|
| `magic.spark` | Arcane Sparks | `behind_foot` | 1,000 |
| `magic.rune` | Glyphs | `behind_foot` | 2,500 |
| `magic.witch` | Witchcraft | `behind_foot` | 3,500 |
| `magic.spell` | Spell | `behind_foot` | 5,500 |
| `magic.arcane` | Arcane Circle | `circle_aura` | 11,000 |

#### Nature — leaves, petals, growth
| Id | Display | Renderer | Price |
|---|---|---|---|
| `nature.leaf` | Falling Leaves | `behind_foot` | 1,200 |
| `nature.petal` | Cherry Petals | `behind_foot` | 2,400 |
| `nature.fern` | Fern Spores | `behind_foot` | 3,000 |
| `nature.bloom` | Blooming Path | `behind_foot` | 5,000 |
| `nature.forest` | Forest Spirit | `circle_aura` | 11,500 |

#### Smoke — wisps and mist
| Id | Display | Renderer | Price |
|---|---|---|---|
| `smoke.wisp` | Wisps | `behind_foot` | 800 |
| `smoke.mist` | Mist | `behind_foot` | 2,000 |
| `smoke.shadow` | Shadow | `behind_foot` | 3,500 |
| `smoke.cloud` | Cloud | `behind_foot` | 5,000 |
| `smoke.specter` | Specter | `column` | 10,000 |

#### Galaxy — stars and cosmic dust
| Id | Display | Renderer | Price |
|---|---|---|---|
| `galaxy.star` | Stars | `behind_foot` | 1,500 |
| `galaxy.nebula` | Nebula | `behind_foot` | 3,000 |
| `galaxy.comet` | Comet | `helix` | 6,500 |
| `galaxy.cosmos` | Cosmos | `dust_cloud` | 9,000 |
| `galaxy.universe` | Universe | `circle_aura` | 14,000 |

#### Wings — non-obstructive auras anchored behind the shoulders
| Id | Display | Renderer | Price |
|---|---|---|---|
| `wings.angel` | Angel Wings | `wings` | 6,500 |
| `wings.demon` | Demon Wings | `wings` | 8,000 |
| `wings.fairy` | Fairy Wings | `wings` | 9,500 |
| `wings.butterfly` | Butterfly Wings | `wings` | 11,000 |
| `wings.dragon` | Dragon Wings | `wings` | 18,000 |

#### Runes — orbiting rune circles
| Id | Display | Renderer | Price |
|---|---|---|---|
| `rune.basic` | Rune Circle | `circle_aura` | 4,500 |
| `rune.binary` | Binary Runes | `circle_aura` | 7,000 |
| `rune.summon` | Summon Runes | `circle_aura` | 9,000 |
| `rune.banish` | Banishment Runes | `circle_aura` | 11,000 |
| `rune.ascend` | Ascension Pillar | `column` | 16,000 |

Prices, displays, and params can all be tuned in `plugins/Dogcraft-Trails/trails.yml`. Add your own trails by appending entries that reference a defined category and renderer.

---

## Trail Gates

Use gates to restrict trails to specific groups: Patreon-exclusives, staff-only trails, event trails. Gates control **acquisition and visibility**, not ongoing use — once a player owns a gated trail (admin grant or purchase while gate-eligible), they keep it even if their permission is removed later.

### Config

```yaml
TrailGates:
  dogcrafttrails.exclusive.patreon3:
    - wings.aurora
    - aura.galaxy
  dogcrafttrails.exclusive.staff:
    - aura.crown
    - sparkle.holographic
  dogcrafttrails.event.halloween2026: nature.pumpkin   # single value also accepted
```

Same shape as `PatreonMonthlyTrailGrants`: `permission node -> trail id` (single) or list of trail ids. A trail can be gated by multiple permissions; matching **any one** unlocks the gate (OR semantics).

### What gates affect

| Action | Behaviour |
|---|---|
| `/trail browse` rendering | Gated trails the player can't pass are hidden (or shown as `🔒 ???` if `ui.show-locked-as-mystery` is `true`). |
| `/trail select <id>` | Allowed if **(player has gate perm) OR (already owned in DB)**. |
| `/trail buy <id>` | Requires gate perm. Without it: "This trail isn't available to you." |
| `/trail preview <id>` | Requires gate perm — gates also hide previews so staff trails can't be datamined by curious players. |
| Patreon rotation pool | Filters by gate perms. A Tier 1 supporter can never roll a `staff-exclusive` trail. |
| `/traila grant` | **Ignores gates.** Admin intent overrides. |
| `dogcrafttrails.bypass` | Overrides every gate. |

---

## Patreon Monthly Rotation

Supporters at any configured tier get a random selection of free trails each month. Grants expire after 31 days (configurable) and are replaced with a fresh roll. The system never grants something the player already owns permanently, never grants a gated trail the player can't pass, and never re-rolls the same trail twice in the same month.

### How a player gets a tier

`PatreonMonthlyTrailGrants` maps **permission nodes** to **how many trails that tier earns per month**:

```yaml
PatreonMonthlyTrailGrants:
  dogcrafttrails.tier1: 1
  dogcrafttrails.tier2: 2
  dogcrafttrails.tier3: 3
  dogcrafttrails.tier4: 5
```

Grant the appropriate node to a Patreon via your permission manager (LuckPerms, GroupManager, anything). If a player has multiple tier nodes, the **highest count wins** — no priority ordering needed, the highest *value* always wins (same pattern MobHeads uses).

The keys can be any permission strings you like; the names above are conventional, not required. You can add `dogcrafttrails.tier5: 10` and remove `tier1` if that suits your tier structure better.

### When the rotation runs

Two triggers:

1. **Hourly async task** — runs 5 minutes after server start, then every 60 minutes, iterating online players.
2. **On player join** — if `PatreonRotation.catch-up-on-join: true` (the default), a player who was offline at the rollover gets caught up the next time they log in.

Both call the same idempotent `ensureCurrentGrants(uuid)` method. Calling it repeatedly within a month does nothing extra after the first successful run.

You can also force a rotation evaluation manually:

```
/traila rotate <player>
```

(Requires the player to be online — we need their permissions to compute their tier.)

### What `ensureCurrentGrants` does

For one player:

1. Compute tier count via the "highest matching permission" rule. If 0, return — they aren't a Patreon.
2. Delete all expired grants from the DB (`expires_at <= now`). This sweeps up last month's data.
3. Look up the player's existing grants for the current month (`grant_period = "YYYY-MM"`).
4. If they already have `tierCount` rows, return.
5. Otherwise, build the candidate pool:
   - Every trail in the catalog
   - **minus** trails the player permanently owns (no point granting what they bought)
   - **minus** trails already granted this month
   - **minus** trails the player fails the gate check for
6. Shuffle and pick `tierCount - existingCount` trails. Insert each into `trails_patreon_grants` with `grant_period` set to the current month and `expires_at = now + grant-window-days`.
7. Update the in-memory ownership cache so the render task sees the new trails immediately.
8. Chat the player a list of their new trails.

### Edge cases

- **Tier upgrade mid-month**: existing rows stay; the next run tops up to the new tier's count (same `grant_period`, same `expires_at` window).
- **Tier downgrade mid-month**: existing rows stay until they expire. Next rollover, the pool size shrinks.
- **Tier removed entirely**: existing rows finish their 31 days; no new rolls happen.
- **Player buys a trail they had as a Patreon grant**: both rows coexist; once the grant expires, they keep the trail (purchased ownership row is the source of truth).
- **Catalog shrinks (a trail is removed from `trails.yml`)**: a granted-but-now-missing trail is silently inert in render. The DB row is harmless until it expires.
- **Pool too small** (e.g. Tier 4 player with 49 of 50 trails already owned): the service logs a warning and grants whatever it can. They'll keep getting the same remaining trail each month until their permanent ownership shrinks.

---

## Cross-Server Selection Sync

When a player selects, enables, or clears their trail on server A:

1. The change is persisted to MySQL (`trails_selection`).
2. The local in-memory cache is updated.
3. The new state is set in Redis at `dogcraft:trails:selection:<uuid>` (with the expiry from `redis.Expiry_seconds`).
4. A pub/sub message is published on `dogcraft:trails:selection_update` with payload `{uuid, trailId, enabled, server}`.

Every other server is subscribed to that channel. They:

1. Ignore messages where `server` matches their own `network.server.Name` (own echo).
2. Update their local cache for that UUID — but only if the player is currently online on that server. Otherwise the message is a no-op; the player will get the fresh state from Redis (or DB if Redis is down) when they next log in.

If Redis is unavailable, selections still persist to MySQL — the plugin just becomes effectively single-server until Redis comes back. The pattern mirrors DogcraftEconomy's `RedisManager`.

---

## Renderers

Trails reuse a small set of parametric renderers. The `renderer:` key in each trail definition picks one; `params:` configures it.

| Renderer | Preview category | Description | Key params |
|---|---|---|---|
| `behind_foot` | BEHIND_TRAIL | Particles emitted at the player's feet on every tick. | `particle`, `count`, `offsetXZ`, `offsetY`, `speed`, `colorRgb`, `fromRgb`/`toRgb` for transitions |
| `helix` | BEHIND_TRAIL | Double-helix wrapping around the player's path. | `particle`, `radius`, `pitch`, `density`, `colorRgb` |
| `wings` | AURA | Two arrays of particles forming flapping wings behind the shoulders. Anchored to not obscure view. | `particle`, `colorRgb`, `flapHz`, `span`, `density` |
| `circle_aura` | AURA | Rotating ring of particles around the player. | `particle`, `radius`, `yOffset`, `density`, `rpm`, `colorRgb` |
| `column` | AURA | Vertical stack of rotating rings — pillar-like. | `particle`, `radius`, `height`, `density`, `rpm`, `colorRgb` |
| `dust_cloud` | AURA | Diffuse particle cloud surrounding the player. | `particle`, `count`, `offsetXZ`, `offsetY`, `speed`, `colorRgb` |

Common conventions:

- `particle` is any Bukkit `Particle` enum name (`DUST`, `END_ROD`, `FLAME`, `CHERRY_LEAVES`, `SNOWFLAKE`, …).
- `colorRgb` is a CSS-style hex string like `'#A8D8FF'`. Only meaningful when the particle is `DUST`.
- `fromRgb` / `toRgb` apply to `DUST_COLOR_TRANSITION`.
- Renderers that report `AURA` get the mannequin preview strategy; `BEHIND_TRAIL` renderers get the drifting-emitter strategy.

---

## Preview System

Click `[Preview]` on any trail (or run `/trail preview <id>`) to see it for 10 seconds (configurable). Free, gated only by the same permission rules as buying/selecting.

| Renderer category | Preview strategy |
|---|---|
| `BEHIND_TRAIL` | A "ghost emitter" anchored to your current position walks 6 blocks in the direction you're facing over the preview window, emitting the trail's particles as it goes. You see your trail leave you and drift away. |
| `AURA` | A Mannequin entity spawns 4 blocks in front of you (configurable), facing you. The trail renders on the mannequin for 10 seconds. |

Lifecycle:

- One active preview per player. A new preview cancels the previous one.
- Cooldown enforced (default 15 s).
- Cleaned up on player quit, world change, plugin disable, and preview timeout.
- Mannequins spawn with `setPersistent(false)` so they don't survive chunk-unload or crashes.
- If there's no clear space in front (cramped corridor), the fallback behaviour depends on `preview.fallback-when-cramped`: `offset` squeezes the mannequin in next to you; `cancel` aborts with a message.

> **Note on the current Mannequin skin:** the mannequin spawns with the default skin in this version. Paper 1.21.9's `setProfile` takes a `ResolvableProfile` and the conversion from `PlayerProfile` is still TBD here. Functionally everything else works; the wing colours and particle shapes are visible just fine.

---

## Database Schema

Three tables, auto-created on first start:

```sql
CREATE TABLE IF NOT EXISTS trails_ownership (
  uuid CHAR(36) NOT NULL,
  trail_id VARCHAR(64) NOT NULL,
  granted_at BIGINT NOT NULL,
  source VARCHAR(16) NOT NULL,           -- 'purchase' | 'admin'
  price_paid DOUBLE NULL,
  PRIMARY KEY (uuid, trail_id)
);

CREATE TABLE IF NOT EXISTS trails_selection (
  uuid CHAR(36) PRIMARY KEY,
  trail_id VARCHAR(64) NULL,             -- null = nothing selected
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS trails_patreon_grants (
  uuid CHAR(36) NOT NULL,
  trail_id VARCHAR(64) NOT NULL,
  tier_node VARCHAR(64) NOT NULL,
  grant_period CHAR(7) NOT NULL,         -- 'YYYY-MM'
  granted_at BIGINT NOT NULL,
  expires_at BIGINT NOT NULL,
  PRIMARY KEY (uuid, trail_id, grant_period),
  INDEX idx_expires (expires_at)
);
```

- **`trails_ownership`** — permanent ownership. One row per (player, trail). `source` is `purchase` or `admin`. Set by `/trail buy` and `/traila grant`.
- **`trails_selection`** — exactly one row per player. `trail_id` may be null when they have nothing selected.
- **`trails_patreon_grants`** — one row per (player, trail, month). Expired rows are deleted on the next rotation pass.

A trail is "owned" for render/select purposes if there's a permanent row **OR** an unexpired Patreon row. The render task reads this from an in-memory cache that's loaded on player join and updated on grant/revoke.

---

## Auto-Updating Configs

Both YAML files self-heal on every plugin start. The reconciler:

1. **Adds missing keys** present in the bundled defaults. Each added key is annotated with `# Added in vX.Y.Z`.
2. **Flags removed keys** present in the user file but not in defaults. A `# DEPRECATED in vX.Y.Z — no longer used, safe to remove` comment is prepended. The data is **never deleted** — admins decide when to remove it.

Two sections are excluded from the deprecated-flagging pass because they're admin-defined free maps:

- `PatreonMonthlyTrailGrants` — add/remove tier nodes freely.
- `TrailGates` — add/remove gate nodes freely.

Children of these blocks are never flagged as deprecated.

Implementation uses Bukkit's built-in `YamlConfiguration` (1.18.1+ comments API). No external config library is shaded.

---

## Building from source

```
mvn clean package
```

Produces `target/Dogcraft-Trails-1.0-SNAPSHOT.jar` (~11 MB shaded — HikariCP, MySQL connector, Lettuce, Netty, Reactor are all relocated under `net.dogcraft.dogcraftTrails.libraries.*` to avoid clashes with sibling plugins that ship the same libs).

Required dependencies:

- Paper 1.21.9 API (`io.papermc.paper:paper-api:1.21.9-R0.1-SNAPSHOT`, `provided`)
- DogcraftEconomy (`net.dogcraft:DogcraftEconomy`, `provided`) — from `https://repo.dogcraft.net/releases`
- Lombok 1.18.36 (`provided`)
- HikariCP 5.1.0, mysql-connector-j 8.2.0, lettuce-core 6.3.1.RELEASE (all shaded)

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Database connection failed; disabling plugin.` | Wrong host, db, user, password in `database` block, or MySQL not reachable. | Verify `mysql -h <host> -u <user> -p<password> <db>` from the server box. |
| `Loaded 10 categories and 0 trails.` | Old jar — pre-fix catalog walker. | Update the jar. The walker now uses `getKeys(true)` and handles dotted trail ids. |
| Trail purchased but `/trail select` says "you don't own it" | Ownership cache wasn't refreshed. | Should never happen after `/trail buy` — please report. Workaround: rejoin. |
| Cross-server selection not propagating | Redis unreachable, or two servers share the same `network.server.Name`. | Check Redis logs. Set a unique `network.server.Name` per server. |
| `Mannequin` preview fails / falls back to ghost emitter | Server running Paper < 1.21.9. | Upgrade Paper. The fallback is intentional so old servers still get a preview. |
| Patreon player got no monthly trails | They don't have any node from `PatreonMonthlyTrailGrants`, or they were offline and `catch-up-on-join` is false. | Verify their permissions; run `/traila rotate <player>` once they're online. |
| Permissions tier node "doesn't work" | OPs auto-inheriting an undeclared node. | Tier nodes are registered with `default: false` automatically — make sure no other plugin redeclares them with a different default. |
| Config has keys with `# DEPRECATED` comments after an update | Keys removed from the schema upstream. | Read the comment, delete the keys when you're ready. The plugin won't touch them. |

---

## Credits

- Tier permission pattern mirrored from Dogcraft-MobHeads.
- Redis + Hikari layout mirrored from DogcraftEconomy.
- Built by ironboundred for the Dogcraft network.
