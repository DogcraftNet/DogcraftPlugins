# DogcraftClaims

A cross-server land claiming and block protection plugin for Paper/Purpur servers. Built for multi-server networks where players share a single identity, claim block balance, and trust list across all connected servers.

Inspired by GriefPrevention, DogcraftClaims adds cross-server sync via Redis, a built-in block lock system with group management, tiered staff ignore modes, and native DogcraftEconomy integration.

## Features

- **Cross-server claims** — Claims, balances, and trust lists sync in real time across all servers via MySQL + Redis Pub/Sub.
- **Self-service protection** — Players create and manage their own claims with a stick — sneak modifies, plain right-click inspects.
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
- **Per-player preferences** — `/claimprefs` chat menu lets each player set tri-state defaults for claim flags (PvP off by default, fire-spread off by default, etc.) and an auto-lock toggle that locks every lockable block they place. Preferences are network-wide.
- **Auto-updating configs** — New config options and messages are merged into your on-disk files on startup; obsolete keys are flagged but preserved.
- **Plugin API** — Other plugins can query claim state, trust, and flags via a reflection-friendly API. No hard dependency required.
- **Tamed mob protection** — Tamed pets and mounts (horses, wolves, cats, etc.) are protected from damage and interaction by anyone except the tamer; tamers can interact with their own pets in any claim; ownership can be transferred via `/transferpet`.

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

### The Stick — one tool, three gestures

DogcraftClaims uses a **stick** as its single tool. The gesture you use determines what happens:

| Gesture (with stick in main hand) | Effect |
|---|---|
| Right-click a block | Inspect the claim at that block (owner, area, trust, location) |
| Sneak (no click) | Show the gold-corner / glowstone-edge markers for nearby claims |
| Sneak + right-click a block | Start a create / resize gesture |
| Right-click after a sneak-click (sneak optional) | Complete the in-progress gesture |

The shovel is no longer involved in claim management — it's a vanilla shovel again, free for digging paths and dirt.

#### Sneak is for *starting*; the second click is "free"

Once a sneak-click has stored the first corner of a new claim or grabbed the corner of an existing claim, the **next right-click with the stick completes the gesture regardless of sneak**. Walk to the second corner without holding shift the whole way.

In-progress gestures cancel automatically when:
- You make the second click (the gesture completes).
- The stick leaves your main hand (hotbar swap, off-hand swap, or drop). An action-bar message confirms.
- `claims.resize-timeout-seconds` (default `30`) elapses without a follow-up click.
- You log out.

Movement and toggling sneak do **not** cancel — only the four conditions above.

### Creating a Claim

**Method 1 — Stick (sneak-then-click)**
1. Hold a **stick** and start sneaking. The borders of nearby claims appear.
2. Sneak + right-click a block to set the first corner.
3. Right-click a second block (sneak optional) to set the opposite corner.
4. The claim is created between those two corners, from bedrock to sky.

**Method 2 — Radius command**
```
/claim 15
```
Creates a 31×31 square claim centered on where you're standing (15 blocks in each direction).

If you're already standing in **your own** top-level claim, `/claim N` *expands* that claim instead of creating a new one — the new bounds are the union of the existing claim and the requested radius around you, so a smaller `N` will never shrink the claim. Subdivisions and admin claims aren't expanded this way; resize them with the stick.

**`-extend` modifier — push only one wall outward**
```
/claim 10 -extend
```
While standing in your own top-level claim, this pushes **only the wall in the direction you're facing** outward by `N` blocks — north / south / east / west, depending on your look direction. The other three boundaries don't move.

So if your claim is from `(0, 0)` to `(50, 50)` and you're facing north when you run `/claim 10 -extend`, the new bounds are `(0, -10)` to `(50, 50)` — only the northern edge moved. Useful when you want to grow a claim toward a specific feature without paying claim blocks for symmetric expansion in all four directions. Aliases: `-extend`, `--extend`, `-e`, `extend`.

### Inspecting Claims

Hold a **stick** and right-click a block (without sneaking) to see who owns the claim, its area, trust list, and other details. You can also use `/claiminfo` while standing in a claim.

Staff with `dogcraftclaims.admin.lastseen` will additionally see the owner's last play time and which server they were last on — useful for identifying inactive claims.

### Resizing a Claim

Sneak + right-click on the **edge** of a claim with the stick — the corner closest to your click is grabbed and the opposite corner becomes the anchor. Right-click a new position (sneak optional) to move that grabbed corner there.

The edge gate covers any side or corner of the claim. The "edge of a claim" means a block on the perimeter — `x == x1`, `x == x2`, `z == z1`, or `z == z2`. Inside-claim clicks no longer trigger resize, so you can walk through your own claim with the stick out without accidentally entering resize mode.

Permissions:
- **Player claims**: only the owner can resize (it costs them claim blocks).
- **Subdivisions**: subclaim owner OR anyone with Manage trust on the subclaim.
- **Admin claims**: requires `dogcraftclaims.admin.claim`.

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

## Tamed Mobs

Any tamed mob you own is automatically protected, **anywhere on the server**. Other players cannot:

- Damage your tamed mob (melee or projectile)
- Right-click to mount, leash, breed, dye, name-tag, sheer, or open its inventory

This applies to every Bukkit `Tameable` species — horses, donkeys, mules, llamas, trader llamas, camels, wolves, cats, parrots, foxes, and axolotls — regardless of whether they're inside a claim. Untamed mobs and Steerable-only mounts (pigs, striders) are not covered since they have no concept of an owner.

**Happy ghasts** are *not* Tameable in the Paper API — Mojang classified them as a vehicle/animal hybrid with no owner UUID. They only get the standard claim protection: inside a claim, untrusted players can't mount or damage them (ACCESS trust to ride, BUILD trust to damage). Outside any claim they're vanilla — anyone can ride or hit them. If you want anywhere-protection for a happy ghast, park it inside one of your claims.

### Owners bypass claim trust on their own pets

If your wolf wanders into someone else's claim, you can still walk in, interact with it (open inventory, leash it, feed it, breed it, etc.), and damage it — even if you have no trust in that claim. Pet ownership trumps claim trust for the pet itself; everything else in the claim is still protected as normal.

### Staff override

Pet protection is global — claim trust doesn't unlock it, and there's no permanent permission to bypass it. Staff who genuinely need to interact with or damage another player's pet (a stuck horse blocking a doorway, an abandoned wolf, transferring ownership manually) run `/ignoreclaims owner` first. The OWNER tier overrides pet protection for the session, resets on login, and shows an action-bar reminder so it's hard to forget you're in bypass mode.

### Transferring a tamed mob

```
/transferpet <player>
```

**Look at** the tamed mob you want to transfer (within 6 blocks), then run the command with the recipient's name. The plugin shows a confirmation prompt with a clickable **[Click to confirm transfer]** button. Pending transfers expire after 30 seconds.

The recipient does **not** have to be online — offline players are looked up by their UUID and ownership is set on the entity directly. Once confirmed, ownership transfers permanently.

Players with `dogcraftclaims.admin` can transfer any tamed mob, even one they don't own — useful for resolving disputes when an owner has left the server.

---

## Block Locks

Locks protect individual blocks — chests, doors, furnaces, etc. — even inside shared claims where everyone has Container trust. Locks are independent of claims and work on unclaimed land too.

Locked containers are also protected from automated extraction by hoppers, droppers, dispensers, hopper minecarts, and copper golems — they can't pull items out unless the destination is another locked container with the same owner. Pushes *into* a locked container are still allowed (so a sorter feeding your locked storage works fine).

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
/lockgroup teammates merge friends    — Fold "teammates" into "friends" (members and lock access combined; "teammates" deleted)
```

### Lockable Blocks

Configured in `config.yml`. Each lockable block is listed under either `access` or `container`. The category does double duty:

1. **Lockability** — anything in either list can have a lock attached with the feather tool.
2. **Right-click trust level** — `access` entries require ACCESS trust to right-click in someone else's claim; `container` entries require CONTAINER trust. Anything not listed needs BUILD trust and is not lockable.

```yaml
locks:
  tool: FEATHER
  lockable-blocks:
    access:
      - "*_DOOR"
      - "*_TRAPDOOR"
      - "*_FENCE_GATE"
      - "*_BUTTON"
      - "*_PRESSURE_PLATE"
      - "*_BED"
      - LEVER
      - REPEATER
      - COMPARATOR
    container:
      - CHEST
      - TRAPPED_CHEST
      - BARREL
      - SHULKER_BOX
      - ENDER_CHEST
      - "*SHELF"          # CHISELED_BOOKSHELF + BOOKSHELF + wood-variant shelves
      - FURNACE
      - BLAST_FURNACE
      - SMOKER
      - HOPPER
      - DROPPER
      - DISPENSER
      - BREWING_STAND
```

Wildcard patterns:

- `*_DOOR` matches OAK_DOOR, IRON_DOOR, BIRCH_DOOR, etc.
- `SHULKER_*` matches every shulker box color.
- `*SHELF` matches anything ending in SHELF — picks up new shelf variants automatically as Paper exposes them.

#### Auto-upgrade

If your `config.yml` still has the legacy flat `lockable-blocks: [list]` format from an older version, the plugin will rewrite it into the new `access` / `container` shape on the next startup. Each entry is categorized using the historical substring rules (CHEST/BARREL/FURNACE/HOPPER/DROPPER/DISPENSER/BREWING/SHULKER/SHELF → container; everything else → access) and the file is saved before `ConfigUpdater` runs. A log line `Auto-upgraded locks.lockable-blocks from flat list to access/container format` confirms the migration.

---

## Subdivisions

Subdivisions let you split a claim into sections with different trust settings. Useful for shared bases where you want a communal area and private rooms.

```
/subdivideclaims
```

Toggles subdivision mode. While active, the stick (sneak + right-click) creates sub-claims inside your existing claim instead of new top-level claims. Run the command again to switch back to normal mode.

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
| `COPPER_GOLEM` | true | Copper golems can pick up items off the ground and move items in/out of containers inside the claim |
| `CREEPER_GRIEFING` | false | Creepers can damage blocks inside the claim. (Hard yes/no in claims — the Y-cutoff rule applies only to unclaimed land.) |
| `ENDERMAN_GRIEFING` | false | Endermen can pick up blocks inside the claim |

### Admin Flags

These require `dogcraftclaims.admin`:

| Flag | Default | Effect when `true` |
|------|---------|-------------------|
| `MOB_SPAWNING` | true | All natural/spawner mob spawns allowed |
| `HOSTILE_SPAWNING` | true | Hostile mob spawns allowed (checked after MOB_SPAWNING) |
| `KEEP_INVENTORY` | false | Players keep inventory and XP on death |
| `NO_ENTRY` | false | Non-trusted players cannot enter (blocks movement, teleportation, and **all vehicle/mount entry** including unsaddled horses being passively carried) |
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
  copper-golem: true
  creeper-griefing: false
  enderman-griefing: false

protection:
  # In unclaimed land, when creeper-griefing is false, creepers can still damage
  # blocks at or below this Y. Above it, creeper damage is always blocked.
  # Inside claims the per-claim flag is a hard yes/no — this Y rule does not apply.
  creeper-griefing-max-y: 62
```

**Creeper Y-cutoff explained.** With the default config (`creeper-griefing: false`, `creeper-griefing-max-y: 62`):

- Outside any claim, above Y 62: creeper damage is blocked. Surface builds in unclaimed wilderness are protected.
- Outside any claim, at or below Y 62: creeper damage works as vanilla. Caves, mining tunnels, ravines stay dangerous.
- Inside a claim: the per-claim `CREEPER_GRIEFING` flag is checked as a hard yes/no — `false` blocks everywhere in the claim regardless of Y level, `true` allows everywhere in the claim.

This solves the common issue of unclaimed surface bases getting blown up while preserving the cave-mining experience. The cutoff is configurable per server.

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

## Claim Preferences

Each player can set personal defaults that apply to every claim they create on every server in the network.

```
/claimprefs
```

Opens a clickable chat menu. Each row has `[default]` `[on]` `[off]` buttons; the active one is highlighted, the other two are clickable to switch. Changes take effect immediately and are written to the database synchronously.

### Default flags for new claims

For each player flag, you can pin it on, pin it off, or fall back to the server's global default:

- `[default]` — the claim uses the server-wide default (or, for a subdivision, the parent claim's value).
- `[on]` — the flag is forced on for every new claim you create.
- `[off]` — the flag is forced off for every new claim you create.

Player flags (PvP, fire spread, explosions, lock-restricted, leaf decay, crop trample) are always shown. Admin flags appear in the menu only for players with `dogcraftclaims.admin`. Subdivisions are not affected — they continue to inherit from their parent claim.

### Auto-lock placed blocks

```
/claimprefs auto_lock on
```

When on, every lockable block you place is automatically locked to you. Forming a double chest is handled correctly:

- Adjacent to your own locked chest → the new half is locked and the partner's access list is mirrored onto it.
- Adjacent to your own unlocked chest → both halves are locked.
- Adjacent to another player's locked chest → auto-lock is skipped (you'd lose access to the chest otherwise).
- Inside a `LOCK_RESTRICTED` claim where you aren't the owner → auto-lock is skipped.

A short action-bar message confirms each lock or explains why it was skipped.

### Lock-deny notifications

```
/claimprefs lock_notify chat       (default)
/claimprefs lock_notify actionbar
```

Controls whether "this block is locked" failure messages appear in chat or on the action bar.

### Direct command syntax

You can also set preferences without opening the menu:

```
/claimprefs PVP on
/claimprefs FIRE_SPREAD default
/claimprefs auto_lock on
/claimprefs lock_notify actionbar
```

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

Toggles admin claim mode. While active, the stick (sneak + right-click) creates admin claims (no owner, no block cost). Run again to switch back.

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

### Plugin Admin (`/dogcraftclaims`)

`/dogcraftclaims` has **no command-level permission**. Each subcommand has its own perm, so mods can be granted exactly the tools they need without inheriting unrelated power:

- `dogcraftclaims.admin.reload` (default op) — `reload`, `globalflag`, `globalset`, `lockable`. Anything that mutates config or running state.
- `dogcraftclaims.admin.entities` (default op) — `entities`. Read-only entity overview, intended for moderators triaging lag reports.

Tab completion respects these — a player with only `dogcraftclaims.admin.entities` only sees `entities` in `/dcc <tab>`. They can't even auto-complete the config-edit subcommands, much less run them. Notably, `dogcraftclaims.admin.entities` is **independent of** `dogcraftclaims.admin` — granting just the entities perm doesn't bring along trust-override, admin-claim creation, admin-flag visibility, or any of the other broad admin powers.

```
/dogcraftclaims reload [aspect]                                (aliases: /dgclaims, /dcc)
/dogcraftclaims globalflag <flag-name> <true|false>
/dogcraftclaims globalflag list
/dogcraftclaims globalset <config-path> <value>
/dogcraftclaims lockable add <access|container> <material>
/dogcraftclaims lockable remove <access|container> <material>
/dogcraftclaims lockable list
/dogcraftclaims lockable resolve
/dogcraftclaims entities [buffer-chunks]
```

#### `reload [aspect]`

| Aspect | Effect |
|--------|--------|
| `config` | Re-reads `config.yml` and `messages_en.yml` from disk into the live `MainConfig` and `MessageConfig`. Preserves the runtime-resolved server name. **Broadcasts a `CONFIG_RELOAD` Redis event** so peer servers reload their own config from disk too. |
| `claims` | Clears the local claim cache and reloads all claims for this server from MySQL. |
| `locks` | Clears the local lock cache and reloads all locks for this server from MySQL. |
| `profiles` | Refreshes the cached profile of every online player from MySQL. |
| `prefs` | Refreshes the cached preferences of every online player from MySQL. |
| `db` | Runs a `SELECT 1` against the database and reports OK or the error. Does **not** restart the connection pool. |
| `all` | Runs every aspect above in sequence. **Default if you omit the argument.** |

#### `globalflag <flag-name> <true|false>`

Toggle one of the entries under `global-flags:` (PvP, fire-spread, mob-spawning, copper-golem, creeper-griefing, enderman-griefing, etc.). The change:

1. Persists to `config.yml` on this server.
2. Reloads the live `MainConfig`.
3. Broadcasts a `CONFIG_KEY_CHANGED` Redis event so peer servers apply the same change locally and persist it to *their* `config.yml`.

Run `/dogcraftclaims globalflag` with no arguments (or `globalflag list`) to open a clickable chat menu — every boolean flag is shown as a row with `[on]` / `[off]` buttons, the active one highlighted. Clicking a button runs the same `globalflag <name> <value>` command and re-renders the menu so you can toggle several in a row.

#### `globalset <config-path> <value>`

Same mechanism but for any config key (numbers, strings, etc.) — for example `/dcc globalset protection.creeper-griefing-max-y 80` or `/dcc globalset claims.min-size 200`. The value is parsed against the existing key's type (boolean / int / long / double / string).

A small set of paths is **rejected** at runtime because they're captured at startup and changing them live would corrupt running state. `globalset` reports them with `requires a plugin restart`:

- `database.*`, `redis.*` (connection pools)
- `server-name`, `use-server-id-conf` (server identity, baked into cache keys)
- `claims.blocks-per-hour` (scheduler interval baked at startup)

For those, edit `config.yml` directly and restart.

#### `lockable add|remove <access|container> <material>` / `lockable list`

Live editor for the `locks.lockable-blocks.access` and `locks.lockable-blocks.container` lists. `globalset` can't touch list values, so this subcommand is the one to use when you need a new block type lockable network-wide.

```
/dcc lockable add container OAK_SHELF
/dcc lockable add access "*_PRESSURE_PLATE"
/dcc lockable remove container BARREL
/dcc lockable list
```

Each `add`/`remove` mutates the list locally, saves `config.yml`, reloads in-memory state, and broadcasts a `LOCKABLE_LIST_CHANGED` Redis event so peer servers do the same. Tab completion on `add` suggests every block-type Material name; `remove` suggests the current entries in the chosen category.

`list` prints both sub-lists with their current entries — useful to eyeball the full picture without opening `config.yml`.

`resolve` is the diagnostic command. Look at a block (within 8 blocks) and run `/dcc lockable resolve`. The command reports:

- The block's Bukkit `Material` name (what you'd add to `lockable-blocks`).
- The block's registry id (`minecraft:foo`) — flagged separately if it differs from the Material name (catches snapshot blocks where the two don't line up, like the unified `minecraft:shelf` vs the per-wood `OAK_SHELF`/`SPRUCE_SHELF` Materials).
- Suggested wildcard patterns derived from underscore-split parts (`*_LASTPART`, `*LASTPART`, `HEAD_*`), each with a count of how many existing block Materials it would match — so you can see scope before committing.

Each suggestion has clickable `[+access]` / `[+container]` buttons that run the existing `lockable add` command and broadcast it to the network. Lets you point at a new block and lock it down in two clicks.

#### `entities [buffer-chunks]`

Moderator overview of every entity inside the claim you're standing in. Useful for spotting lag-causing buildup — animal farms, dropped-item piles, villager breeders — without flying around looking for them.

```
/dcc entities       (claim only)
/dcc entities 1     (claim + 1-chunk buffer)
/dcc entities 3     (claim + 3-chunk buffer, max 8)
```

Output looks like:

```
═══ Entity Overview ═══ (claim + 1 chunk buffer)
Total: 137 (137 ticking)
  Cow: 100 (50 ticking)
  Sheep: 24 (24 ticking)
  Villager: 6 (6 ticking)
  Item Frame: 4 (0 ticking)
  Wandering Trader: 3 (3 ticking)
```

Each row shows the total of that entity type and how many of those are currently being **ticked** by the server (Paper's `Entity.isTicking()`). The gap between total and ticking is interesting: a high total with a low ticking count usually means the entities are in a no-tick view-distance zone, so they're alive but not contributing to TPS at the moment.

Iterates `world.getEntities()` once and filters by the claim bounding box plus the buffer. Skips entities in unloaded chunks (they can't be ticking anyway). The buffer is capped at 8 chunks to keep big-claim queries quick.

#### What reload still doesn't cover

`/dcc reload config` re-reads everything in `config.yml` *except* the restart-required paths above. Reloading won't migrate the connection pool or re-schedule the accrual task even if the value changed in the file. Restart the plugin to pick those up.

---

## Permissions

### Player Permissions (default: true)

| Permission | Description |
|-----------|-------------|
| `dogcraftclaims.claim` | Create and manage own claims |
| `dogcraftclaims.trust` | Use trust commands |
| `dogcraftclaims.lock` | Place and manage locks |
| `dogcraftclaims.claimblocks.buy` | Purchase claim blocks |
| `dogcraftclaims.tame` | Use `/transferpet` on tamed mobs you own |

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
| `dogcraftclaims.claim.fly` | Allowed to claim while flying |
| `dogcraftclaims.admin.lastseen` | See claim owner's last play time in `/claiminfo` |
| `dogcraftclaims.admin.rental` | Toggle rental auto-reset (admin-only rental feature) |
| `dogcraftclaims.admin.reload` | Run `/dogcraftclaims reload`, `globalflag`, `globalset`, `lockable` (config-edit power) |
| `dogcraftclaims.admin.entities` | Run `/dogcraftclaims entities` (read-only entity overview, mod tool) |

### Opt-in Permissions (default: false)

These cover the few protections that `/ignoreclaims` *cannot* override. Ops are expected to use `/ignoreclaims container`/`owner` for normal claim-trust bypass; these perms are reserved for dedicated tooling accounts (anti-grief sweeps, staff-only shop creators, etc.) that need the extras below.

`dogcraftclaims.bypass.build` covers exactly two cases:

1. **`require-claim` mode** — when `protection.require-claim: true` is set, holders can build/break/interact on unclaimed land that would otherwise be locked down. Useful for staff doing world setup outside player plots.
2. **`DENY_FLIGHT` claim flag** — flight stays enabled in claims that disable it on entry/teleport.

**Tamed-pet override is `/ignoreclaims owner` only**, not `bypass.build`. Staff who need to damage or interact with another player's pet (clean up a stuck horse, transfer ownership manually, etc.) toggle `/ignoreclaims owner` first — the override is session-scoped, resets on login, and shows an action-bar reminder so it's hard to forget you're in bypass mode. There's no permanent perm for pet override by design.

Inside-claim build/break/interact, `NO_ENTRY` movement and teleport, hanging breaks, vehicle destroy, and inventory-open are *not* covered by this perm — `/ignoreclaims owner` (or `container`, depending on the action) handles them through the normal trust check. Staff can't accidentally walk in and break things just because they have `bypass.build`; they have to actively toggle bypass mode.

`dogcraftclaims.bypass.pvp` is unchanged in scope — it lets the holder hit other players regardless of the `PVP` claim flag and any global PvP setting.

| Permission | Description |
|-----------|-------------|
| `dogcraftclaims.bypass.build` | Bypass `require-claim` mode and the `DENY_FLIGHT` claim flag |
| `dogcraftclaims.bypass.pvp` | Always bypass `PVP` claim flag — hit any player anywhere |

### Suggested Role Assignments

| Role | Permissions |
|------|------------|
| Player | Default permissions only |
| Mod | `dogcraftclaims.admin.ignoreclaims.container`, `dogcraftclaims.admin.delete`, `dogcraftclaims.lock.locksmith`, `dogcraftclaims.notify.proximity`, `dogcraftclaims.admin.lastseen`, `dogcraftclaims.admin.entities` |
| Senior Mod / Admin | All of the above + `dogcraftclaims.admin.ignoreclaims.owner`, `dogcraftclaims.admin.adjust`, `dogcraftclaims.admin`, `dogcraftclaims.admin.reload` |

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
| `claims.investigation-tool` | `STICK` | The single DogcraftClaims tool (right-click inspects, sneak shows borders, sneak + right-click creates/resizes) |
| `claims.resize-timeout-seconds` | `30` | How long an in-progress create or resize gesture stays active. After this many seconds without a follow-up click, the state is dropped. Set to `0` to disable. |
| `locks.tool` | `FEATHER` | Item for managing block locks |
| `economy.enabled` | `true` | Enable `/buyclaimblocks` |
| `protection.require-claim` | `false` | Block all player actions outside of claims (creative worlds) |
| `rental.snapshot-dir` | `snapshots` | Directory under the plugin folder for rental auto-reset snapshots |
| `rental.reset-blocks-per-tick` | `5000` | Max blocks restored per tick during an auto-reset |

---

## Plugin API

DogcraftClaims exposes a public API at `net.dogcraft.dogcraftClaims.api.DogcraftClaimsAPI` for other plugins to query claim state. The API is reflection-friendly — its methods only return JDK types (`UUID`, `String`, `boolean`, `int[]`) and Bukkit types (`Location`, `Player`) so callers don't need a compile-time dependency on this plugin.

### Reflection (recommended for soft-depend plugins)

Pure-reflection integration with no compile-time dependency on DogcraftClaims. Drop this class into your plugin and you're done — it gracefully degrades when DogcraftClaims isn't installed.

#### Step 1 — declare a soft-depend in your `plugin.yml`

```yaml
name: YourPlugin
main: com.example.yourplugin.YourPlugin
version: 1.0.0
api-version: '1.21'
softdepend: [DogcraftClaims]
```

`softdepend` (not `depend`) means your plugin loads even when DogcraftClaims is missing, and it loads *after* DogcraftClaims when present.

#### Step 2 — add a hook utility class

```java
package com.example.yourplugin.hooks;

import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.entity.Player;
import org.bukkit.plugin.java.JavaPlugin;

import java.lang.reflect.Method;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;

/**
 * Pure-reflection hook for DogcraftClaims. No compile-time dependency.
 * Methods return safe defaults when DogcraftClaims is missing or the API
 * isn't ready yet, so callers never need to null-check the hook itself.
 */
public class DogcraftClaimsHook {

    private final JavaPlugin plugin;
    private boolean available = false;
    private Object api;

    // Cached reflected methods
    private Method isClaimed;
    private Method getClaimOwner;
    private Method getClaimId;
    private Method getClaimName;
    private Method isAdminClaim;
    private Method isSubdivision;
    private Method getClaimBounds;
    private Method getClaimArea;
    private Method hasTrust;
    private Method hasTrustEntry;
    private Method getFlag;
    private Method getClaimIdsForOwner;

    public DogcraftClaimsHook(JavaPlugin plugin) {
        this.plugin = plugin;
    }

    /**
     * Attempt to hook into DogcraftClaims. Call from your onEnable() —
     * since softdepend guarantees DogcraftClaims has loaded first, the API
     * singleton is already initialized by the time we get here.
     *
     * @return true if successfully hooked
     */
    public boolean hook() {
        if (Bukkit.getPluginManager().getPlugin("DogcraftClaims") == null) {
            plugin.getLogger().info("DogcraftClaims not installed — claim features disabled.");
            return false;
        }
        try {
            Class<?> apiClass = Class.forName("net.dogcraft.dogcraftClaims.api.DogcraftClaimsAPI");
            api = apiClass.getMethod("getInstance").invoke(null);
            if (api == null) {
                plugin.getLogger().warning("DogcraftClaims is loaded but its API isn't initialized yet.");
                return false;
            }

            isClaimed           = apiClass.getMethod("isClaimed", Location.class);
            getClaimOwner       = apiClass.getMethod("getClaimOwner", Location.class);
            getClaimId          = apiClass.getMethod("getClaimId", Location.class);
            getClaimName        = apiClass.getMethod("getClaimName", Location.class);
            isAdminClaim        = apiClass.getMethod("isAdminClaim", Location.class);
            isSubdivision       = apiClass.getMethod("isSubdivision", Location.class);
            getClaimBounds      = apiClass.getMethod("getClaimBounds", Location.class);
            getClaimArea        = apiClass.getMethod("getClaimArea", Location.class);
            hasTrust            = apiClass.getMethod("hasTrust", Player.class, Location.class, String.class);
            hasTrustEntry       = apiClass.getMethod("hasTrustEntry", UUID.class, Location.class, String.class);
            getFlag             = apiClass.getMethod("getFlag", Location.class, String.class);
            getClaimIdsForOwner = apiClass.getMethod("getClaimIdsForOwner", UUID.class);

            available = true;
            plugin.getLogger().info("DogcraftClaims API hooked.");
            return true;
        } catch (ClassNotFoundException e) {
            plugin.getLogger().info("DogcraftClaims classes not found — claim features disabled.");
            return false;
        } catch (Exception e) {
            plugin.getLogger().log(Level.WARNING, "Failed to hook DogcraftClaims API", e);
            return false;
        }
    }

    public boolean isAvailable() {
        return available;
    }

    // ─── Read-only queries ────────────────────────────────────────────────

    /** True if the location is inside any claim. False if not, or if the hook isn't available. */
    public boolean isClaimed(Location loc) {
        if (!available) return false;
        try { return (boolean) isClaimed.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return false; }
    }

    /** Owner UUID, or null for unclaimed/admin claims, or null if hook unavailable. */
    public UUID getClaimOwner(Location loc) {
        if (!available) return null;
        try { return (UUID) getClaimOwner.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return null; }
    }

    /** Claim UUID, or null. */
    public UUID getClaimId(Location loc) {
        if (!available) return null;
        try { return (UUID) getClaimId.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return null; }
    }

    /** Friendly claim name, or null. */
    public String getClaimName(Location loc) {
        if (!available) return null;
        try { return (String) getClaimName.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return null; }
    }

    /** True if it's an admin claim. */
    public boolean isAdminClaim(Location loc) {
        if (!available) return false;
        try { return (boolean) isAdminClaim.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return false; }
    }

    /** True if it's a subdivision. */
    public boolean isSubdivision(Location loc) {
        if (!available) return false;
        try { return (boolean) isSubdivision.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return false; }
    }

    /** Returns {x1, z1, x2, z2} or null if no claim / hook unavailable. */
    public int[] getClaimBounds(Location loc) {
        if (!available) return null;
        try { return (int[]) getClaimBounds.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return null; }
    }

    /** Claim area in blocks, or 0. */
    public int getClaimArea(Location loc) {
        if (!available) return 0;
        try { return (int) getClaimArea.invoke(api, loc); }
        catch (Exception e) { logAndDisable(e); return 0; }
    }

    /**
     * Full trust check including ignore-tier bypass, rental status, owner identity,
     * and trust entries. Use this when you have an online Player.
     *
     * <p>Returns true when there is no claim at the location (no protection applies).
     *
     * @param level one of "ACCESS", "CONTAINER", "BUILD", "MANAGE" (case-insensitive)
     */
    public boolean hasTrust(Player player, Location loc, String level) {
        if (!available) return true; // fail-open: don't block actions when hook is missing
        try { return (boolean) hasTrust.invoke(api, player, loc, level); }
        catch (Exception e) { logAndDisable(e); return true; }
    }

    /**
     * Trust-entries-only check by UUID. Does NOT honor ignore tiers or rental
     * overrides; use {@link #hasTrust(Player, Location, String)} when possible.
     */
    public boolean hasTrustEntry(UUID playerUuid, Location loc, String level) {
        if (!available) return true;
        try { return (boolean) hasTrustEntry.invoke(api, playerUuid, loc, level); }
        catch (Exception e) { logAndDisable(e); return true; }
    }

    /**
     * Read a claim flag at this location. If no claim is present, returns the
     * configured global default. Returns false if the flag name is unknown
     * or the hook is unavailable.
     */
    public boolean getFlag(Location loc, String flagName) {
        if (!available) return false;
        try { return (boolean) getFlag.invoke(api, loc, flagName); }
        catch (Exception e) { logAndDisable(e); return false; }
    }

    /** All claim IDs owned by this player on the local server. */
    @SuppressWarnings("unchecked")
    public List<UUID> getClaimIdsForOwner(UUID ownerUuid) {
        if (!available) return Collections.emptyList();
        try { return (List<UUID>) getClaimIdsForOwner.invoke(api, ownerUuid); }
        catch (Exception e) { logAndDisable(e); return Collections.emptyList(); }
    }

    private void logAndDisable(Exception e) {
        plugin.getLogger().log(Level.WARNING,
                "DogcraftClaims API call failed; disabling integration", e);
        available = false;
    }
}
```

#### Step 3 — wire it up in your plugin's `onEnable`

```java
public class YourPlugin extends JavaPlugin {

    private DogcraftClaimsHook claims;

    @Override
    public void onEnable() {
        claims = new DogcraftClaimsHook(this);
        claims.hook(); // safe if DogcraftClaims is missing — just disables claim features
    }

    public DogcraftClaimsHook getClaims() {
        return claims;
    }
}
```

#### Step 4 — call it from anywhere in your plugin

```java
// In a listener, command, etc.
DogcraftClaimsHook claims = YourPlugin.getInstance().getClaims();

// Don't trample player builds
if (claims.isClaimed(targetLoc) && !claims.hasTrust(player, targetLoc, "BUILD")) {
    player.sendMessage("You can't do that here — this area is claimed.");
    return;
}

// Respect a per-claim PvP setting
if (!claims.getFlag(victim.getLocation(), "PVP")) {
    event.setCancelled(true);
    return;
}

// Skip an effect for admin claims
if (claims.isAdminClaim(loc)) return;

// Lookup owner for a UI
UUID owner = claims.getClaimOwner(loc);
String name = (owner != null) ? Bukkit.getOfflinePlayer(owner).getName() : "Server";
```

The hook returns sensible defaults (false / null / empty list / fail-open for trust) whenever DogcraftClaims isn't installed or the API call fails, so your plugin keeps working either way.

### Direct usage (if you `depend` on DogcraftClaims)

```java
import net.dogcraft.dogcraftClaims.api.DogcraftClaimsAPI;

DogcraftClaimsAPI api = DogcraftClaimsAPI.getInstance();
if (api == null) return; // plugin disabled

if (api.isClaimed(player.getLocation())) {
    UUID owner = api.getClaimOwner(player.getLocation());
    boolean canBuild = api.hasTrust(player, player.getLocation(), "BUILD");
    boolean pvpAllowed = api.getFlag(player.getLocation(), "PVP");
    int[] bounds = api.getClaimBounds(player.getLocation()); // {x1, z1, x2, z2}
}
```

### Available methods

| Method | Returns | Description |
|--------|---------|-------------|
| `isClaimed(Location)` | `boolean` | True if the location is inside any claim |
| `isClaimed(String world, int x, int z)` | `boolean` | Coordinate variant for the local server |
| `getClaimOwner(Location)` | `UUID` | Owner UUID, or `null` for unclaimed/admin claims |
| `getClaimId(Location)` | `UUID` | Claim's UUID, or `null` |
| `getClaimName(Location)` | `String` | Friendly name, or `null` |
| `isAdminClaim(Location)` | `boolean` | True if it's an admin claim |
| `isSubdivision(Location)` | `boolean` | True if it's a subdivision |
| `getParentClaimId(Location)` | `UUID` | Parent claim's UUID if subdivision, else `null` |
| `getClaimBounds(Location)` | `int[]` | `{x1, z1, x2, z2}` or `null` |
| `getClaimArea(Location)` | `int` | Block area, or 0 |
| `hasTrust(Player, Location, String level)` | `boolean` | Full trust check (honors ignore tiers, rentals, owner) |
| `hasTrustEntry(UUID, Location, String level)` | `boolean` | Trust-entries-only check (no online Player available) |
| `getFlag(Location, String flagName)` | `boolean` | Flag value at this location, with subdivision/global fallback |
| `getClaimIdsForOwner(UUID)` | `List<UUID>` | All claim IDs owned by a player on this server |

Trust levels (case-insensitive): `"ACCESS"`, `"CONTAINER"`, `"BUILD"`, `"MANAGE"`.
Flag names: `"PVP"`, `"MOB_SPAWNING"`, `"FIRE_SPREAD"`, `"EXPLOSIONS"`, `"LOCK_RESTRICTED"`, `"LEAF_DECAY"`, `"CROP_TRAMPLE"`, `"KEEP_INVENTORY"`, `"NO_ENTRY"`, `"DENY_FLIGHT"`, `"HOSTILE_SPAWNING"`, `"ENDERPEARL"`, `"VINE_GROWTH"`, `"SNOW_FORM"`, `"EXCLUDE_LOGGING"`, `"COPPER_GOLEM"`, `"CREEPER_GRIEFING"`, `"ENDERMAN_GRIEFING"`.

### Notes

- All queries reflect state on the **current server** only. For cross-server data, query MySQL directly (see the storage section).
- The API is read-only — there's no public way to create or modify claims through it.
- `getInstance()` may return `null` if called before our `onEnable` completes; handle that case.

---

## Building from Source

Requires Java 21+ and Maven.

```bash
mvn clean package
```

The shaded JAR will be in `target/Dogcraft-Claims-1.0-SNAPSHOT.jar`.
