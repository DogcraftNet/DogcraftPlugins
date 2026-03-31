# Mob Heads

A Paper plugin that allows mobs to drop custom heads when killed by players. Highly customizable - configure which mobs drop heads, drop rates, textures, display names, and variant-specific heads (e.g. different colored sheep, cat breeds, villager professions).

Supports optional MySQL database storage and Redis caching for multi-server networks where you want identical, stackable head items across all servers.

## Features

- Custom skull textures for 80+ entity types and variants
- Configurable drop rates per entity with Looting enchantment bonus
- Player head drops on PvP kills (optional)
- Variant-specific heads (colored wolves, cat breeds, villager professions, etc.)
- MySQL database backend (optional) with HikariCP connection pooling
- Redis cache (optional) for cross-server item synchronization
- NBT item serialization for byte-identical items across servers (stackable)
- Automatic Mojang API texture resolution for UUID-based player skin heads
- Folia compatible

## Requirements

- Paper 1.21.4+ (or compatible fork)
- Java 21+
- MySQL (optional, for database mode)
- Redis (optional, for cross-server caching)

## Building

```bash
git clone <repo-url>
cd Dogcraft-MobHeads
mvn clean package
```

The shaded jar will be in `target/MobHeads-3.0.0-SNAPSHOT.jar`. Dependencies (HikariCP, Jedis) are relocated and bundled in the jar.

## Installation

Drop the jar into your server's `plugins/` directory and restart. On first run, the plugin creates:

- `plugins/MobHeads/config.yml` - Main configuration
- `plugins/MobHeads/Heads.yml` - Head texture definitions
- `plugins/MobHeads/Entitys.yml` - Entity-to-variant mappings

## Configuration

### config.yml

| Key | Default | Description |
|-----|---------|-------------|
| `AlwaysDropOP` | `false` | If true, players with `MobHead.AlwaysDrop` permission always receive a head drop |
| `IDPrefix` | *(base64 prefix)* | Base64 prefix for Minecraft texture URLs. Do not change unless you know what you're doing |
| `PlayersDropTheirHeads` | `false` | Enable player head drops on PvP kills |
| `HeadOnSuicide` | `false` | Allow head drops when a player kills themselves |
| `DebugInfo` | `false` | Enable verbose logging for troubleshooting |
| `PlayerHeadRate` | `100` | Drop chance percentage (0-100) for player heads |
| `LootingBonus` | `3` | Additional drop chance percentage per Looting level |

### Database Settings

| Key | Default | Description |
|-----|---------|-------------|
| `UseSQLConfiguration` | `false` | Enable MySQL database backend |
| `PopulateDatabase` | `true` | Sync Heads.yml to database on startup. Set to true when initializing or updating the database |
| `Db_Name` | `database` | MySQL database name |
| `DB_User` | `root` | MySQL username |
| `DB_Password` | `password` | MySQL password |
| `DB_IP` | `LOCALHOST:3306` | MySQL host and port |
| `DB_TablePrefix` | `mobheads` | Table name prefix. Creates `{prefix}_config` and `{prefix}_items` tables |

### Redis Settings

| Key | Default | Description |
|-----|---------|-------------|
| `UseRedis` | `false` | Enable Redis caching for cross-server sync |
| `Redis_Host` | `localhost` | Redis server hostname |
| `Redis_Port` | `6379` | Redis server port |
| `Redis_Password` | *(empty)* | Redis password (leave empty for no auth) |
| `Redis_Channel` | `mobheads` | Pub/sub channel name for cache invalidation |

## How It Works

### Drop Flow

When a mob is killed by a player:

1. The plugin checks if the entity type has a configured head in `Heads.yml`
2. If the entity has variants (e.g. a black sheep, a powered creeper), the specific variant key is resolved from the mob's properties
3. A pre-built skull ItemStack is looked up from the in-memory cache using that key
4. If multiple textures are configured for that entity, one is chosen at random
5. The drop chance is rolled based on the configured `Drop` percentage and the killer's Looting enchantment level
6. If the roll succeeds (or the player has `MobHead.AlwaysDrop` permission with `AlwaysDropOP` enabled), the head is dropped at the mob's death location

For player heads (when `PlayersDropTheirHeads` is enabled), the killed player's own skin is used as the skull texture with the `PlayerHeadRate` percentage.

### Drop Chance Calculation

The base drop chance is the `Drop` value from the head's config (0-100%). A `Drop: 5` means a 5% base chance.

**Without Looting:**
A random value between 0 and 101 is generated. If it falls below the configured `Drop` percentage, the head drops.

**With Looting:**
The Looting enchantment provides two separate chances to drop:

1. **Primary roll**: The effective drop rate is increased by the Looting level. For example, with `Drop: 5` and Looting III, the primary chance becomes `5 + 3 = 8%`
2. **Second chance roll**: If the primary roll fails, a secondary roll is made with a probability of `level / (level + 1)`. For Looting III this is `3/4 = 75%`

This means Looting significantly improves drop rates, especially at higher levels:

| Looting Level | Base 5% Effective Chance |
|---------------|------------------------|
| None | ~5% |
| I | ~8% primary, then 50% second chance |
| II | ~9% primary, then 67% second chance |
| III | ~10% primary, then 75% second chance |

### Skull Creation

Heads are created using one of two methods depending on the `PlayerSkin` setting:

- **Custom textures** (`PlayerSkin: false`): The `ID` field is a base64-encoded texture string. Combined with the `IDPrefix` from config, this forms a full Minecraft skin texture URL that is applied to a player head item via a custom `PlayerProfile`.

- **Player UUIDs** (`PlayerSkin: true`): The `ID` field is a player UUID. If the player has joined the server, their cached profile is used. If not, the plugin fetches their skin texture directly from the Mojang session API (rate-limited to 1 request/second to avoid 429 errors). Once fetched, the texture is cached in the database so subsequent startups don't need to hit the API again.

### Variant Resolution

When an entity dies the plugin calls `getSkullKey()` to resolve the exact config key. The result is looked up in the in-memory map; if no match is found it falls back to the base entity type name (e.g. `SHEEP`).

#### Biome / registry variants — `Variant.key().value().toUpperCase()`

| Entity | Method | Example keys |
|--------|--------|-------------|
| `COW` | `getVariant()` | `COW.COLD` `COW.TEMPERATE` `COW.WARM` |
| `PIG` | `getVariant()` | `PIG.COLD` `PIG.TEMPERATE` `PIG.WARM` |
| `CHICKEN` | `getVariant()` | `CHICKEN.COLD` `CHICKEN.TEMPERATE` `CHICKEN.WARM` |
| `SALMON` | `getVariant()` | `SALMON.SMALL` `SALMON.MEDIUM` `SALMON.LARGE` |
| `WOLF` | `getVariant()` | `WOLF.PALE` `WOLF.ASHEN` `WOLF.BLACK` `WOLF.CHESTNUT` `WOLF.RUSTY` `WOLF.SNOWY` `WOLF.SPOTTED` `WOLF.STRIPED` `WOLF.WOODS` |
| `ZOMBIE_NAUTILUS` | `getVariant()` | `ZOMBIE_NAUTILUS.TEMPERATE` `ZOMBIE_NAUTILUS.WARM` |
| `FROG` | `getVariant()` | `FROG.COLD` `FROG.TEMPERATE` `FROG.WARM` |
| `AXOLOTL` | `getVariant()` | `AXOLOTL.BLUE` `AXOLOTL.CYAN` `AXOLOTL.GOLD` `AXOLOTL.LUCY` `AXOLOTL.WILD` |
| `CAT` | `getCatType().getKey()` | `CAT.TABBY` `CAT.BLACK` `CAT.JELLIE` … (11 types) |
| `FOX` | `getFoxType()` | `FOX.RED` `FOX.SNOW` |
| `HORSE` | `getColor()` | `HORSE.BLACK` `HORSE.BROWN` `HORSE.CHESTNUT` `HORSE.CREAMY` `HORSE.DARK_BROWN` `HORSE.GRAY` `HORSE.WHITE` |
| `LLAMA` | `getColor()` | `LLAMA.BROWN` `LLAMA.CREAMY` `LLAMA.GRAY` `LLAMA.WHITE` |
| `TRADER_LLAMA` | `getColor()` | `TRADER_LLAMA.BROWN` `TRADER_LLAMA.CREAMY` `TRADER_LLAMA.GRAY` `TRADER_LLAMA.WHITE` |
| `MOOSHROOM` | `getVariant()` | `MUSHROOM_COW.BROWN` `MUSHROOM_COW.RED` |
| `PARROT` | `getVariant()` | `PARROT.BLUE` `PARROT.CYAN` `PARROT.GRAY` `PARROT.GREEN` `PARROT.RED` |
| `RABBIT` | `getRabbitType()` | `RABBIT.BLACK` `RABBIT.WHITE` `RABBIT.THE_KILLER_BUNNY` … (7 types) |
| `PANDA` | `getMainGene()` | `PANDA.AGGRESSIVE` `PANDA.BROWN` `PANDA.LAZY` `PANDA.NORMAL` `PANDA.PLAYFUL` `PANDA.WEAK` `PANDA.WORRIED` |
| `TROPICAL_FISH` | `getBodyColor()` | `TROPICAL_FISH.BLACK` `TROPICAL_FISH.BLUE` … (15 colours) |
| `VILLAGER` | `getProfession().getKey()` | `VILLAGER.FARMER` `VILLAGER.LIBRARIAN` … (14 professions) |
| `ZOMBIE_VILLAGER` | `getVillagerProfession().getKey()` | `ZOMBIE_VILLAGER.FARMER` … (14 professions) |

#### Colour variants

| Entity | Method | Keys |
|--------|--------|------|
| `SHEEP` | `getColor()` | All 16 dye colours + `SHEEP.JEB` (custom name `jeb_`) |
| `SHULKER` | `getColor()` | All 16 dye colours, falls back to `SHULKER` if null |

#### State-based variants

| Entity | Logic | Keys |
|--------|-------|------|
| `BEE` | `hasStung()` → `hasNectar()` + `getAnger()` | `BEE.STUNG` `BEE.POLLINATED_ANGER` `BEE.POLLINATED` `BEE.ANGER` `BEE.PASSIVE` |
| `CREEPER` | `isPowered()` | `CREEPER.POWERED` |
| `CAMEL` | `isDashing()` | `CAMEL.DASHING` |
| `SNOWMAN` | `isDerp()` | `SNOWMAN.DERP` |
| `STRIDER` | `isShivering()` (off lava = cold) | `STRIDER.COLD` `STRIDER.WARM` |
| `PUFFERFISH` | `getPuffState()` 0/1/2 | `PUFFERFISH.FLAT` `PUFFERFISH.SEMI` `PUFFERFISH.PUFFED` |
| `ENDERMAN` | `isScreaming()` | `ENDERMAN.SCREAMING` |
| `GOAT` | `isScreaming()` then `!hasLeftHorn() && !hasRightHorn()` | `GOAT.SCREAMING` `GOAT.HORNLESS` |
| `VEX` | `isCharging()` | `VEX.CHARGING` |
| `WARDEN` | `getAngerLevel()` | `WARDEN.CALM` `WARDEN.AGITATED` `WARDEN.ANGRY` |
| `CREAKING` | `isActive()` | `CREAKING.ACTIVE` |
| `ARMADILLO` | `getState()` — ROLLING / SCARED / UNROLLING → same key | `ARMADILLO.SCARED` |
| `SLIME` | `getSize()` ≤1 / ≤2 / >2 | `SLIME.TINY` `SLIME.SMALL` `SLIME.LARGE` |
| `MAGMA_CUBE` | `getSize()` ≤1 / ≤2 / >2 | `MAGMA_CUBE.TINY` `MAGMA_CUBE.SMALL` `MAGMA_CUBE.LARGE` |
| `IRON_GOLEM` | `isPlayerCreated()` | `IRON_GOLEM.PLAYER_CREATED` — built by a player with pumpkin + iron blocks. Falls back to `IRON_GOLEM` for naturally spawned village golems. |
| `SNIFFER` | `getState()` — DIGGING/SEARCHING → DIGGING, SNIFFING/SCENTING → SNIFFING | `SNIFFER.SNIFFING` `SNIFFER.DIGGING` |
| `COPPER_GOLEM` | `getWeatheringState()` | `COPPER_GOLEM.UNAFFECTED` `COPPER_GOLEM.EXPOSED` `COPPER_GOLEM.WEATHERED` `COPPER_GOLEM.OXIDIZED` |

## Database Schema

When database mode is enabled, two tables are created:

**`{prefix}_config`** - Stores head configuration (textures, drop rates, names)

| Column | Type | Description |
|--------|------|-------------|
| `entity` | VARCHAR(64) PK | Entity key (e.g. `CREEPER`, `SHEEP.BLACK`) |
| `settings` | VARCHAR(5000) | Comma-separated texture IDs or player UUIDs |
| `droprate` | INT | Drop percentage (0-100) |
| `name` | VARCHAR(64) | Display name |
| `uuid` | BOOLEAN | If true, settings are player UUIDs |
| `updated_at` | BIGINT | Timestamp of last update (ms since epoch) |

**`{prefix}_items`** - Stores serialized ItemStacks for cross-server consistency

| Column | Type | Description |
|--------|------|-------------|
| `entity` | VARCHAR(64) | Entity key |
| `variant_idx` | INT | Variant index (composite PK with entity) |
| `nbt_data` | MEDIUMTEXT | Base64-encoded serialized ItemStack |
| `updated_at` | BIGINT | Timestamp of when this item was built |

## How Caching Works

On startup, for each entity head:

1. Check **Redis cache** first (fastest) — if the cached item is newer than the config's `updated_at`, use it immediately
2. Check **DB items table** — same staleness check; if valid, deserialize and warm Redis so other servers don't need a DB round-trip
3. **Cache miss** — build the skull from config, serialize it, store in DB + Redis

For **player UUID heads** (e.g. Camel, staff heads): the raw Mojang texture string is looked up in `{prefix}_skin_cache` first. If it has never been fetched it calls the Mojang session API once and stores the result permanently — no TTL. Staff members update their head by joining any server (which uses the local `hasPlayedBefore()` profile path instead) and running `/mhreload`.

Items are serialized as byte-identical NBT data, so heads built on different servers will stack in player inventories. The `updated_at` timestamp on each config row is what servers compare against — bump it (or run `/mhreload`) to force a rebuild.

## Multi-Server Setup

1. Enable `UseSQLConfiguration` and point all servers to the same MySQL database
2. Enable `UseRedis` and point all servers to the same Redis instance
3. Set `PopulateDatabase: true` on one server to initialize the database from Heads.yml
4. Set `PopulateDatabase: false` on other servers so they read from the database

When you update head configuration (via Heads.yml or directly in the database):
- Run `/mhreload` on any server
- That server rebuilds its items and publishes a Redis invalidation
- Other servers automatically pick up the changes

## Head Configuration

### Heads.yml

Defines textures and drop rates for each entity/variant:

```yaml
CREEPER:
  ID: 'f4254838-GfaJ-...'   # Base64 texture string
  Drop: 5                     # 5% drop chance
  DisplayName: Creeper
  PlayerSkin: false

CREEPER.POWERED:
  ID: 'a4321abc-...'
  Drop: 10
  DisplayName: Charged Creeper
  PlayerSkin: false
```

For player UUID-based skins:

```yaml
CAMEL:
  ID:
    - 963a748f-fd36-49bb-af49-7d6cf7b48f24
    - 341f3317-2435-4670-8eca-bf65f77c5561
  Drop: 5
  DisplayName: Camel
  PlayerSkin: true
```

Multiple IDs means a random texture is chosen each drop.

### Entitys.yml

Maps entity types to their variant keys:

```yaml
CREEPER:
  - CREEPER
  - POWERED

SHEEP:
  - SHEEP
  - WHITE
  - ORANGE
  - BLACK
  # ... all colors

ALLAY: ALLAY    # Simple entity with no variants
```

## Commands

| Command | Permission | Description |
|---------|-----------|-------------|
| `/mhreload` | `MobHead.reload` | Reload all configuration files and rebuild head cache |
| `/mhspawn [entity]` | `MobHead.spawn` | Spawn all heads (or heads for a specific entity) at your location |

## Permissions

| Permission | Default | Description |
|-----------|---------|-------------|
| `MobHead.AlwaysDrop` | op | Heads always drop for this player (when `AlwaysDropOP` is enabled) |
| `MobHead.spawn` | op | Access to `/mhspawn` command |
| `MobHead.reload` | op | Access to `/mhreload` command |

## Authors

- Ironboundred
