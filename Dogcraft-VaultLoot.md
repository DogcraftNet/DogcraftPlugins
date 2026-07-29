# Dogcraft-VaultLoot

Playtime-gated re-looting of trial chamber vaults.

Paper 26.2+ · Java 25 · single-server (Survival)

Vanilla rewards each player from a given vault exactly once, permanently. This plugin
makes a vault lootable again by the same player once they have accumulated a
configurable amount of **active playtime** since they last looted *that specific vault*.

---

## Contents

- [How it works](#how-it-works)
- [What this defends against](#what-this-defends-against)
- [Commands](#commands)
- [Permissions](#permissions)
- [Configuration](#configuration)
- [Integrations](#integrations)
- [Before you enable this on a live world](#before-you-enable-this-on-a-live-world)
- [Data](#data)
- [Operational notes](#operational-notes)
- [Building](#building)
- [Testing](#testing)
- [Project layout](#project-layout)
- [Requirements](#requirements)

---

## How it works

### The rule

```
eligible(player, vault) := (currentPlaytime - playtimeWhenLastLooted) >= threshold
```

Playtime comes from `Statistic.PLAY_ONE_MINUTE`, which is measured in **ticks**, not
minutes (4 hours = 288,000). Dogcraft-AFK freezes that statistic while a player is
AFK, so the value is *active* playtime — idling next to a vault does not bring a reset
closer.

The snapshot is taken when the vault **dispenses loot**, not when it unlocks. A player
who is unlocked by the plugin but walks away without spending a key has consumed
nothing and keeps their progress.

### The plugin is the source of truth

A vault block entity stores only the most recent **128** player UUIDs. On a busy vault
older UUIDs are silently evicted, and vanilla then hands those players a free re-loot —
which is exactly the failure this plugin exists to prevent. Consequently:

1. The block's rewarded list is **never** read to decide eligibility. The database is.
2. Enforcement is **two-directional**: every pass writes the answer back to the block.
   Eligible → removed from the list. Ineligible → added back.
3. Because eviction can happen at any time, this is re-asserted continuously rather
   than cached per session.

### What runs when

| Trigger | What happens |
|---|---|
| `ChunkLoadEvent` | Chunk is scanned for vaults and added to an in-memory spatial index |
| Every `sync-interval-ticks` | For each non-AFK player, vaults within `sync-radius` are forced to agree with the database; the nearest locked one drives the action bar |
| `BlockDispenseLootEvent` | The playtime snapshot is recorded (cache write-through, then persisted) |
| `PlayerInteractEvent` on a vault | Enforcement is re-run *before* vanilla reads the list, and a "still recharging" notice is sent |
| `PlayerJoinEvent` / `PlayerQuitEvent` | The player's rows are loaded into / evicted from the cache |
| Shutdown | Optional fail-closed flush (see [`fail-closed-on-disable`](#configuration)) |

The block is only written when the desired state actually differs, so a vault that is
already correct costs one read and no write.

**Timing.** A vault re-evaluates its own state at most once per second, so an
eligibility change can take up to ~1s to become visible. Key insertion is checked
live, so the *gate* itself is immediate — the delay is only in the vault's
lit/unlit appearance.

---

## What this defends against

✅ **In scope:** one player sitting at a single vault and looting it repeatedly over a
short period.

❌ **Out of scope:** a player looting many different vaults or chambers in one session.
Breadth costs travel and exploration, which is self-limiting. There are no throughput
caps, reset budgets, or token economies.

**Not changed:** loot tables (vaults dispense their normal loot every time), key
acquisition, and trial spawner behaviour.

---

## Commands

Root command: `/vaultreset`, alias `/vr`.

| Command | Permission | Description |
|---|---|---|
| `/vaultreset status` | `dogcraft.vaultreset.use` | How many of your vaults are recharging and when the next one opens |
| `/vaultreset info` | `dogcraft.vaultreset.use` | Details for the vault you are looking at |
| `/vaultreset buy` | `dogcraft.vaultreset.buy` | Show the purchase confirmation (price, balance, vaults affected) |
| `/vaultreset buy confirm` | `dogcraft.vaultreset.buy` | Execute the purchase |
| `/vaultreset reset <player>` | `dogcraft.vaultreset.admin` | Staff: clear **all** rows for a player |
| `/vaultreset reset here <player>` | `dogcraft.vaultreset.admin` | Staff: clear the vault you are looking at, for a player |
| `/vaultreset debug` | `dogcraft.vaultreset.admin` | Dump index / database / block state for the targeted vault |

`<player>` accepts offline players — the usual case for a support ticket.

`/vaultreset debug` is the first thing to reach for when something looks wrong. It
shows the index entry, the database row, the computed eligibility, and the block's own
rewarded list side by side, which is enough to tell index drift from a missing row from
a 128-entry eviction.

---

## Permissions

| Permission | Default | Grants |
|---|---|---|
| `dogcraft.vaultreset.use` | everyone | `status`, `info` |
| `dogcraft.vaultreset.buy` | everyone | `buy` |
| `dogcraft.vaultreset.admin` | op | `reset`, `debug` |

---

## Configuration

```yaml
vault-reset:
  # Active playtime a player must accrue after looting a vault before that same
  # vault becomes lootable again. Measured in PLAY_ONE_MINUTE ticks internally.
  reset-playtime-hours: 4
  ominous-reset-playtime-hours: 4   # at parity by decision; separate knob for future tuning

  sync-interval-ticks: 20           # see the warning below before changing
  sync-radius: 6                    # must exceed the vault activation range (4)

  actionbar:
    enabled: true
    message: "<gray>Vault recharging — <yellow>{remaining}</yellow> of playtime left"

  locked-message: "<gray>This vault is still recharging — <yellow>{remaining}</yellow> of playtime left."
  locked-message-cooldown-seconds: 10

  purchase:
    enabled: true
    price: 250000.0
    cooldown-minutes: 60            # wall clock; the anti-camp rail on the bypass
    confirm-required: true
    transaction-message: "Vault reset"

  database:
    file: "vaults.db"

  worlds:                           # empty list = every world
    - world

  require-afk-hook: true
  fail-closed-on-disable: true
  debug: false
```

Messages use [MiniMessage](https://docs.advntr.dev/minimessage/format.html). They are
validated once at startup, and a malformed template is reported with its key rather
than throwing on every send.

### Keys that deserve a second look

**`worlds`** — this is the easiest way to make the plugin appear broken. A name that
matches no loaded world means every chunk is skipped and nothing happens anywhere. The
plugin logs a warning per unmatched name at startup, and a louder one if *nothing*
matches, but check this first if vaults are not being tracked. Note this is the world
name (`level-name`), not the folder you expect.

**`sync-radius`** — must exceed the vault's own activation range (4 by default) so the
block is already correct before it would light up. Raising it multiplies the per-pass
cost by the number of vaults now in range.

**`sync-interval-ticks`** — 20 (one second) matches the rate at which a vault
re-evaluates itself, so syncing faster buys nothing and costs proportionally more.

**`require-afk-hook`** — leave this `true`. See [Integrations](#integrations).

**`{remaining}`** — is **playtime** remaining, not a wall-clock countdown. If you
reword these messages, keep that distinction; players who read it as a timer will log
off expecting progress they do not get.

### Keys from the design that are deliberately absent

- **`actionbar.suppress-while-afk`** — could only ever be `true`. AFK players are
  skipped entirely, because Dogcraft-AFK writes its own action bar during the AFK phase
  (two writers flicker) and because reading the frozen statistic mid-AFK biases toward
  unlocking.
- **`purchase.scope`** — `all` is the only implemented behaviour, so the key would read
  like a choice that does not exist.

Both are noted in the shipped `config.yml`. Reinstate them if the underlying behaviour
is ever added.

---

## Integrations

### Dogcraft-AFK — required in practice

`Dogcraft-AFK` is a soft dependency, but it **carries correctness**, and it fails open.
Without it, `isAfk` returns false for everyone *and* `PLAY_ONE_MINUTE` is never frozen,
so AFK time silently counts toward resets with no error anywhere. That is why
`require-afk-hook` defaults to `true` and the plugin refuses to enable rather than run
degraded.

Two consequences worth knowing:

- Dogcraft-AFK currently fails to enable without **LuckPerms** installed. A
  failed-to-enable AFK plugin is indistinguishable from an absent one, so an unrelated
  LuckPerms problem will keep this plugin down too.
- If `freeze-stats` is ever flipped to `false` in Dogcraft-AFK's config, thresholds
  silently start measuring idle time. A built-in drift detector watches for exactly
  that and logs a `SEVERE` line once per server start if it sees playtime accruing
  while a player is flagged AFK.

### DogcraftEconomy — optional

Required only for `/vaultreset buy`. If it is absent the purchase command refuses
cleanly and everything else keeps working; the plugin still enables.

Money is moved with `api.withdraw` and nothing else. It is atomic and auto-logs a
`withdraw` ledger entry, whereas `setBalance` and `atomicTransfer` do not log and would
surface as a DISCREPANCY in DogcraftEconomy's periodic `audit`. Funds are destroyed
rather than transferred, so a purchase is a true sink.

> **Naming hazard for contributors.** Three unrelated `Vault` types are in play:
> `org.bukkit.block.Vault` (the tile state), `org.bukkit.block.data.type.Vault` (the
> block data, which carries the ominous flag), and Vault the economy bridge. The first
> two appear in the same methods and are always fully qualified in this codebase.
> Go through `DogcraftEconomyApi` directly, never the Vault bridge.

---

## Before you enable this on a live world

> **Enabling this on a world where players have already looted vaults will hand every
> one of them a free re-loot of every vault they ever opened.**

This is the mechanic working as designed, and that is the problem. On first run the
database is empty, so every `(player, vault)` pair evaluates as "never looted" →
eligible → the sync pass *removes* them from the vault's rewarded list. A whole
season's worth of vanilla locks is erased the moment a player walks near a vault.

Pick one before going live:

1. **A one-shot admin migration** *(recommended, not yet implemented)* — walk loaded
   chambers once before enabling and write a row for every UUID currently in each
   vault's rewarded list. Explicit, auditable, and cannot fight a purchased reset.
2. **Adoption gated on a persisted per-player flag**, cleared by a purchase. Automatic,
   but more state to get wrong — and note that adopting naively *will* eat a purchased
   reset, because a buyer's rows are deleted while they remain listed on every vault
   outside sync radius.
3. **Accept the payout** as a launch event and announce it.

Whichever you choose, the 128-entry cap means adoption can only ever recover the most
recent 128 looters per vault. It is a mitigation, not a guarantee.

**Also do one manual purchase on staging** before enabling `purchase`. That is the one
code path that could not be exercised in automated testing (it needs MySQL, Redis and
the Vault plugin). Confirm exactly one `withdraw` row in the ledger and a matching
`rows_cleared` in `reset_purchase`.

---

## Data

SQLite in `plugins/Dogcraft-VaultLoot/vaults.db`, WAL mode. All access is off the main
thread on a single connection and a single-threaded executor, which also guarantees
write ordering. An in-memory per-player cache backs the proximity loop so it never
touches disk.

```sql
CREATE TABLE vault_access (
    player_uuid   TEXT    NOT NULL,
    world_uid     TEXT    NOT NULL,
    x             INTEGER NOT NULL,
    y             INTEGER NOT NULL,
    z             INTEGER NOT NULL,
    last_playtime INTEGER NOT NULL,   -- PLAY_ONE_MINUTE ticks at the moment of loot
    looted_at     INTEGER NOT NULL,   -- epoch millis; diagnostics and support only
    PRIMARY KEY (player_uuid, world_uid, x, y, z)
);

CREATE TABLE reset_purchase (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    player_uuid   TEXT    NOT NULL,
    price         REAL    NOT NULL,
    purchased_at  INTEGER NOT NULL,   -- epoch millis, for the purchase cooldown
    rows_cleared  INTEGER NOT NULL
);
```

Rows are keyed by **position**, not by block identity. A vault moved by WorldEdit or a
chunk restore orphans its rows harmlessly; they simply never match again.

The database is per-server. Playtime statistics and vault positions are local, so there
is no cross-server state.

`sqlite-jdbc` is not on Paper's classpath and is **not** shaded into the jar — it is
resolved at load time by the plugin loader. The plugin therefore needs network access
on first start, or a warm Maven cache.

---

## Operational notes

**A purchase moves money before it clears rows.** The reverse would give the reset away
free if payment declined. That leaves a narrow window where a crash means the player
paid and got nothing; it is logged at `SEVERE` naming the player and price so you can
refund from the auto-logged ledger entry. A `reset_purchase` row existing means the
reset really happened.

**Fail-closed shutdown** re-locks ineligible online players on vaults they have looted
that are still loaded, so *removing* the plugin does not hand out free loots. It cannot
cover offline players or unloaded chunks. In the ordinary case it writes nothing,
because the running plugin already keeps nearby vaults correct — it earns its place on
vaults a player is far from, where a 128-entry eviction would otherwise go unrepaired.

**Two players at one vault with different eligibility is safe.** The rewarded list is
per-UUID, so unlocking for one does not unlock for the other.

**`/setblock` and WorldEdit do not fire block events**, so vaults placed that way are
not indexed until their chunk reloads (or until the vault is looted, which self-heals
the index). An unindexed vault gets no enforcement.

**Index drift self-corrects.** If the world disagrees with the index — the block is no
longer a vault — the stale entry is dropped on the next pass.

---

## Building

Requires JDK 25. The Gradle toolchain will provision one if none is detected.

```bash
./gradlew build
```

The jar lands in `build/libs/`.

A test build targeting 26.1.2 (same source, different `api-version` and paper-api
dependency) is available because the mineflayer bot used for in-world testing cannot
join a 26.2 server:

```bash
./gradlew build -PmcTarget=26.1.2
```

This is sound because `org.bukkit.block.Vault` and `BlockDispenseLootEvent` are
byte-identical between the two versions. **Do not deploy a 26.1.2 build to a 26.2
server** — use the default target for production.

To run a scratch server with the plugin installed:

```bash
./gradlew runServer
```

---

## Testing

Every stage was verified in-world against the harness at `T:\Projects\dcl-test`
(see its `TESTING.md`). Four repro drivers live in that harness's `bot/` directory:

| Script | Covers |
|---|---|
| `repro-vaultloot-e2e.js` | The core cycle: loot → lock → wait out the threshold → unlock → loot again |
| `repro-vaultloot-stage4.js` | Action bar, `status`, `info`, the locked notice and its rate limit |
| `repro-vaultloot-stage5.js` | `buy` degradation without an economy, and both admin reset commands |
| `repro-vaultloot-stage6.js` | The fail-closed shutdown flush |

Two traps worth knowing if you extend them:

- `/data get block <pos>` **truncates** long NBT and will silently hide
  `rewarded_players`. Query the targeted path `server_data.rewarded_players` instead.
- mineflayer does not emit its `actionBar` event on this protocol; hook the raw
  `action_bar` packet via `bot._client.on(...)`.

Give each run **fresh coordinates** and a wiped `vaults.db` — rows and rewarded lists
accumulate across runs and will otherwise contaminate assertions.

---

## Project layout

```
src/main/java/net/dogcraft/dogcraftVaultLoot/
├── DogcraftVaultLoot.java          main plugin; wiring and the enable gate
├── DogcraftVaultLootLoader.java    resolves sqlite-jdbc at load time
├── command/VaultResetCommand.java  the whole /vaultreset tree (Brigadier)
├── config/PluginConfig.java        typed snapshot of config.yml
├── hook/
│   ├── DogcraftAfkHook.java        reflection hook; no compile-time dependency
│   └── EconomyHook.java            isolation boundary for the optional economy dep
├── index/
│   ├── IndexedVault.java           position + the cached ominous flag
│   └── VaultIndex.java             chunk-bucketed spatial index
├── listener/
│   ├── PlayerSessionListener.java  join → load rows, quit → evict
│   ├── VaultIndexListener.java     chunk/world load and unload, block place and break
│   ├── VaultInteractListener.java  just-in-time enforcement + the locked notice
│   └── VaultLootListener.java      records the playtime snapshot
├── message/Messages.java           MiniMessage rendering and startup validation
├── service/
│   ├── EligibilityService.java     the reset rule, and nothing else
│   └── PurchaseService.java        cooldown → withdraw → clear → resync
├── storage/
│   ├── PlayerVaultCache.java       per-player row cache with a load-window buffer
│   ├── VaultAccessStore.java       SQLite access, serialised on one thread
│   └── VaultKey.java               (world, x, y, z)
├── task/VaultSyncTask.java         the enforcement pass and the drift detector
└── util/TimeFormat.java            tick durations for players
```

`DESIGN.md` is the original design document. `IMPLEMENTATION_PLAN.md` records the build
order, everything that changed during implementation and why, and the open decisions —
read §7 before changing enforcement or money code, and §7b before deploying.

---

## Requirements

- Paper **26.2+**
- Java **25+**
- **Dogcraft-AFK** — soft dependency, but required in practice (see
  [Integrations](#integrations)); itself needs LuckPerms to enable
- **DogcraftEconomy** — optional, only for `/vaultreset buy`
- Network access on first start, or a warm Maven cache, to fetch `sqlite-jdbc`
