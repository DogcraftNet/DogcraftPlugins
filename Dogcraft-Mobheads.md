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

When a mob dies, the plugin inspects its properties to determine the exact variant key. Examples:

- A **black sheep** resolves to `SHEEP.BLACK`
- A **powered creeper** resolves to `CREEPER.POWERED`
- A **pollinated angry bee** resolves to `BEE.POLLINATED_ANGER`
- A **villager with armorer profession** resolves to `VILLAGER.ARMORER`
- A sheep named **jeb_** resolves to `SHEEP.JEB`

If no variant-specific head is found, the plugin falls back to the base entity key (e.g. `SHEEP`).

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

1. **Player skin heads** (`uuid=true`) always rebuild from Mojang to pick up skin changes
2. Check **Redis cache** first (fastest) - if valid and not stale, use it
3. Check **DB items table** - if valid and not stale, deserialize and use it
4. **Cache miss** - build the skull from config, serialize it, store in DB + Redis
5. Publish update on Redis channel so other servers can pick up the new item

Items are serialized as byte-identical data, so heads from different servers will stack in player inventories. The `updated_at` timestamps ensure stale caches are automatically rebuilt when configuration changes.

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

## Supported Entities with Variants

The following entities have variant- or state-specific heads. If a variant key is not found in `Heads.yml`, the plugin falls back to the base entity key.

### Biome / Registry Variants

| Entity | Keys | Detection |
|--------|------|-----------|
| Axolotl | `.BLUE` `.CYAN` `.GOLD` `.LUCY` `.WILD` | `getVariant()` |
| Cat | `.TABBY` `.BLACK` `.ALL_BLACK` `.BRITISH_SHORTHAIR` `.CALICO` `.JELLIE` `.PERSIAN` `.RAGDOLL` `.RED` `.SIAMESE` `.WHITE` | `getCatType()` |
| Chicken | `.TEMPERATE` `.COLD` `.WARM` | `getVariant()` |
| Cow | `.TEMPERATE` `.COLD` `.WARM` | `getVariant()` |
| Fox | `.RED` `.SNOW` | `getFoxType()` |
| Frog | `.COLD` `.TEMPERATE` `.WARM` | `getVariant()` |
| Horse | `.BLACK` `.BROWN` `.CHESTNUT` `.CREAMY` `.DARK_BROWN` `.GRAY` `.WHITE` | `getColor()` |
| Llama | `.BROWN` `.CREAMY` `.GRAY` `.WHITE` | `getColor()` |
| Mooshroom | `.RED` `.BROWN` | `getVariant()` |
| Parrot | `.BLUE` `.CYAN` `.GRAY` `.GREEN` `.RED` | `getVariant()` |
| Pig | `.TEMPERATE` `.COLD` `.WARM` | `getVariant()` |
| Rabbit | `.BLACK` `.BLACK_AND_WHITE` `.BROWN` `.GOLD` `.SALT_AND_PEPPER` `.THE_KILLER_BUNNY` `.WHITE` | `getRabbitType()` |
| Salmon | `.SMALL` `.MEDIUM` `.LARGE` | `getVariant()` |
| Trader Llama | `.BROWN` `.CREAMY` `.GRAY` `.WHITE` | `getColor()` |
| Wolf | `.PALE` `.ASHEN` `.BLACK` `.CHESTNUT` `.RUSTY` `.SNOWY` `.SPOTTED` `.STRIPED` `.WOODS` | `getVariant()` (biome spawn type) |
| Zombie Nautilus | `.TEMPERATE` `.WARM` | `getVariant()` |

### Colour Variants

| Entity | Keys | Detection |
|--------|------|-----------|
| Sheep | `.WHITE` `.ORANGE` `.MAGENTA` `.LIGHT_BLUE` `.YELLOW` `.LIME` `.PINK` `.GRAY` `.LIGHT_GRAY` `.CYAN` `.PURPLE` `.BLUE` `.BROWN` `.GREEN` `.RED` `.BLACK` `.JEB` | `getColor()` + name check |
| Shulker | All 16 dye colours + base | `getColor()` |
| Tropical Fish | By body colour (15 colours) | `getBodyColor()` |

### Behaviour / State Variants

| Entity | Keys | Condition |
|--------|------|-----------|
| Armadillo | `.SCARED` | `getState()` is ROLLING, SCARED, or UNROLLING |
| Bee | `.PASSIVE` `.ANGER` `.POLLINATED` `.POLLINATED_ANGER` `.STUNG` | `getAnger()` + `hasNectar()` + `hasStung()` |
| Camel | `.DASHING` | `isDashing()` |
| Copper Golem | `.UNAFFECTED` `.EXPOSED` `.WEATHERED` `.OXIDIZED` | `getWeatheringState()` |
| Creaking | `.ACTIVE` | `isActive()` — glowing eyes vs dormant |
| Creeper | `.POWERED` | `isPowered()` |
| Enderman | `.SCREAMING` | `isScreaming()` |
| Goat | `.SCREAMING` `.HORNLESS` | `isScreaming()` / `!hasLeftHorn() && !hasRightHorn()` |
| Iron Golem | `.CRACKED` `.VERY_CRACKED` | health `< 50%` / `< 25%` of max |
| Magma Cube | `.TINY` `.SMALL` `.LARGE` | `getSize()` ≤1 / ≤2 / >2 |
| Panda | `.AGGRESSIVE` `.BROWN` `.LAZY` `.NORMAL` `.PLAYFUL` `.WEAK` `.WORRIED` | `getMainGene()` |
| Pufferfish | `.FLAT` `.SEMI` `.PUFFED` | `getPuffState()` 0 / 1 / 2 |
| Slime | `.TINY` `.SMALL` `.LARGE` | `getSize()` ≤1 / ≤2 / >2 |
| Sniffer | `.SNIFFING` `.DIGGING` | `getState()` SNIFFING/SCENTING or DIGGING/SEARCHING |
| Snow Golem | `.DERP` | `isDerp()` — pumpkin removed |
| Strider | `.WARM` `.COLD` | `isShivering()` — cold when off lava |
| Vex | `.CHARGING` | `isCharging()` — glowing red texture |
| Warden | `.CALM` `.AGITATED` `.ANGRY` | `getAngerLevel()` 0–39 / 40–79 / 80+ |

### Profession Variants

| Entity | Keys |
|--------|------|
| Villager | `.ARMORER` `.BUTCHER` `.CARTOGRAPHER` `.CLERIC` `.FARMER` `.FISHERMAN` `.FLETCHER` `.LEATHERWORKER` `.LIBRARIAN` `.MASON` `.NITWIT` `.NONE` `.SHEPHERD` `.TOOLSMITH` `.WEAPONSMITH` |
| Zombie Villager | Same professions as Villager |

### New Entities (1.21.11)

| Entity | Notes |
|--------|-------|
| Camel Husk | Undead camel from desert ambush |
| Happy Ghast | Friendly rideable ghast — breedable |
| Nautilus | Tameable rideable combat mob |
| Parched Skeleton | Parched skeleton riding undead camel |
| Zombie Nautilus | `.TEMPERATE` `.WARM` |

## Authors

- Ironboundred
