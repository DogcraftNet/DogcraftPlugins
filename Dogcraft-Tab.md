# Dogcraft-Tab

A network-wide tab list plugin for Minecraft server networks running **Velocity** + **Paper**. Synchronizes player information across all backend servers using Redis, so every player sees a unified tab list with custom formatting, player heads, LuckPerms ranks, and server names.

## Features

- **Cross-server tab list** — players on any backend server appear in everyone's tab list with correct skins
- **LuckPerms integration** — displays prefix, suffix, and sorts by group weight; updates live on rank changes
- **Configurable formatting** — MiniMessage-based tab name format, header, and footer with placeholders
- **Composable sorting** — define sort order as a comma-separated list (e.g. `server,rank,alphabetical`)
- **Vanish support** — toggle player visibility via plugin channel; staff with permission see vanished players tagged `[V]`
- **Hot-reloadable config** — `/dogcrafttab reload` pushes config changes to all servers instantly
- **Multi-proxy support** — multiple Velocity proxies can share the same Redis; stale entries expire automatically
- **Redis-backed state** — TTL-based expiry with heartbeat ensures consistency even after crashes

## Architecture

```
┌──────────┐     Redis      ┌──────────┐
│ Velocity │◄──────────────►│ Velocity │  (optional multi-proxy)
│  Proxy   │   pub/sub +    │  Proxy   │
└────┬─────┘   hash state   └────┬─────┘
     │                            │
     ▼                            ▼
┌──────────┐              ┌──────────┐
│  Paper   │              │  Paper   │
│ Server 1 │              │ Server 2 │
└──────────┘              └──────────┘
```

**Velocity** captures player joins, quits, server switches, and skin textures. It writes player state to Redis and publishes events.

**Paper** subscribes to events, maintains a local cache, and builds the tab list using NMS packet injection for remote players. Local players use Paper's native API.

### Redis Data Model

| Key | Type | TTL | Purpose |
|-----|------|-----|---------|
| `network:online` | SET | none | UUID index of all online players |
| `network:player:{uuid}` | HASH | 90s | Player state (name, server, prefix, suffix, textures, weight, vanished) |
| `network:config` | HASH | none | Tab format, header, footer, sort order |
| `network:player_events` | PUB/SUB | — | JOIN, QUIT, SERVER_SWITCH, PREFIX_UPDATE, VANISH_TOGGLE, CONFIG_RELOAD |

## Requirements

- Java 21+
- Velocity 3.5.0+
- Paper 1.21.4+
- Redis server
- LuckPerms (optional, for prefix/suffix/rank sorting)

## Building

```bash
mvn clean package
```

Produces two shaded JARs:
- `velocity/target/dogcraft-tab-velocity-1.0-SNAPSHOT.jar`
- `paper/target/dogcraft-tab-paper-1.0-SNAPSHOT.jar`

## Installation

1. Place the Velocity JAR in your proxy's `plugins/` folder
2. Place the Paper JAR in each backend server's `plugins/` folder
3. Start the servers once to generate config files
4. Configure Redis connection on both sides (see below)
5. Restart

## Configuration

### Velocity — `plugins/dogcraft-tab/config.properties`

```properties
# Redis connection
redis.host=localhost
redis.port=6379
redis.password=

# Set to false on secondary proxies in a multi-proxy setup.
# Only the managing proxy writes tab config to Redis.
manage-config=true

# Tab list name format (MiniMessage). Placeholders: {name}, {prefix}, {suffix}, {server}, {online}
tab.format=<gray>[{server}]</gray> {prefix} {name} {suffix}

# Tab list header (MiniMessage). Placeholders: {online}
tab.header=<gold><bold>Dogcraft Network</bold></gold>\n<gray>Players Online: {online}</gray>

# Tab list footer (MiniMessage). Placeholders: {online}
tab.footer=<gray>Play at dogcraft.net</gray>

# Tab sort order — comma-separated keys, applied in order.
# Keys: rank (high first), rank_asc (low first), server, server_desc,
#        alphabetical, alphabetical_desc
tab.sort=server,rank,alphabetical
```

### Paper — `plugins/Dogcraft-Tab/config.yml`

```yaml
redis:
  host: localhost
  port: 6379
  password: ""
```

## Placeholders

| Placeholder | Available in | Description |
|-------------|-------------|-------------|
| `{name}` | format | Player name |
| `{prefix}` | format | LuckPerms prefix (MiniMessage) |
| `{suffix}` | format | LuckPerms suffix (MiniMessage) |
| `{server}` | format | Backend server name |
| `{online}` | format, header, footer | Total online player count |

## Sort Keys

Sort order is configured as a comma-separated list. Each key can be used once. The list is evaluated left-to-right as primary, secondary, tertiary sort, etc.

| Key | Order |
|-----|-------|
| `rank` | Highest LuckPerms group weight first |
| `rank_asc` | Lowest weight first |
| `server` | Server name A-Z |
| `server_desc` | Server name Z-A |
| `alphabetical` | Player name A-Z |
| `alphabetical_desc` | Player name Z-A |

**Examples:**
- `rank,alphabetical` — admins at top, alphabetical within same rank
- `server,rank,alphabetical` — grouped by server, then by rank, then A-Z
- `alphabetical` — simple A-Z list

## Vanish

Vanish is toggled via the `bungeecord:network-vanish` plugin channel. Send a message containing a byte (action) followed by a UTF string (player UUID) to toggle vanish state.

- Players without `dogcrafttab.vanish.see` permission will not see vanished players in tab
- Players with the permission will see vanished players with a `[V]` tag appended

## Commands

| Command | Permission | Description |
|---------|-----------|-------------|
| `/dogcrafttab reload` | `dogcrafttab.reload` | Reload config from disk, push to Redis, notify all servers |

## Permissions

| Permission | Description |
|-----------|-------------|
| `dogcrafttab.reload` | Use the reload command (Velocity) |
| `dogcrafttab.vanish.see` | See vanished players in tab list (Paper) |

## Project Structure

```
Dogcraft-Tab/
├── pom.xml                          # Parent POM
├── shared/                          # Shared library (Redis, models, events)
│   └── src/main/java/.../shared/
│       ├── RedisKeys.java           # Redis key constants & TTL config
│       ├── RedisManager.java        # JedisPool wrapper
│       ├── NetworkPlayer.java       # Player data model
│       └── PlayerEvent.java         # Pub/sub event record
├── velocity/                        # Velocity proxy plugin
│   └── src/main/java/.../velocity/
│       └── DogcraftTabVelocity.java # Player lifecycle, config management
└── paper/                           # Paper server plugin
    └── src/main/java/.../paper/
        ├── DogcraftTab.java         # Main plugin, tab list building
        ├── TabEntryManager.java     # NMS packet injection for remote players
        └── NetworkEventListener.java # Redis pub/sub event handler
```
