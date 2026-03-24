# NetworkSwitch

A Velocity + Paper plugin for managing server switching across a Minecraft network. Velocity is the brain — it owns all configuration, enforces server capacity, tracks backend health, and handles player transfers. Paper backends are thin clients that register commands/GUI and relay transfer requests.

## Requirements

- **Java 21+**
- **Velocity 3.4.0+**
- **Paper 1.21.4+**
- **Redis** server accessible by both Velocity and all Paper backends

## Architecture

```
  Velocity (source of truth)
    ├── Owns all config (messages, GUI, capacity)
    ├── Publishes config + server list to Redis
    ├── Handles all player transfers
    ├── Enforces server capacity limits
    ├── Monitors backend heartbeats
    └── Provides admin commands (/ns, /nslimit)

  Redis (shared state)
    ├── Config + server list
    ├── Transfer requests (pub/sub)
    ├── Server identity mappings (UUID → name)
    ├── Backend heartbeats (key with TTL)
    └── Live server stats (player counts, online status)

  Paper Backends (thin clients)
    ├── Read config from Redis
    ├── Register per-server commands + GUI
    ├── Publish transfer requests to Redis
    ├── Heartbeat to Redis every 30s
    └── Auto-discover server name via Velocity
```

## Setup

### 1. Velocity

Drop the jar into your Velocity `plugins/` folder. On first start it creates `plugins/networkswitch/config.yml` — configure your Redis connection there. Everything else is managed through that config.

### 2. Paper Backends

Drop the same jar into each Paper server's `plugins/` folder. On first start it creates `plugins/NetworkSwitch/config.yml` with just the Redis connection settings:

```yaml
Redis:
  Host: "localhost"
  Port: 6379
  Password: ""
```

The backend reads all other settings (server list, messages, GUI layout) from Redis automatically.

### 3. Redis

Ensure Redis is running and accessible from both Velocity and all Paper backends. No special Redis configuration is needed.

## Features

### Server Switching

Players can switch servers via:
- **Per-server commands** (e.g., `/lobby`, `/survival`) — auto-registered on Paper from the Velocity server list
- **Server selector GUI** — `/servers` opens a configurable chest GUI
- **Admin command** — `/ns <player> <server>` from Velocity console or with permission

All transfer requests flow through Velocity which validates the target, checks capacity, sends player messages, and performs the connection.

### Dynamic Server List

The server list is pulled directly from Velocity's registered servers — no static list in config. Updates happen automatically when:
- Velocity starts or reloads (`/velocity reload`)
- A server is registered or unregistered at runtime (`ServerRegisteredEvent` / `ServerUnregisteredEvent`)

Paper backends receive updates via Redis pub/sub and re-register commands/GUI on the fly.

### Server Capacity

Velocity enforces per-server player limits with a two-tier slot system:

| Slot Type | Who Can Use It | Config Key |
|---|---|---|
| **Regular** (`maxPlayers`) | All players | `ServerLimits.DefaultMaxPlayers` |
| **Staff** (`staffSlots`) | Players with `networkswitch.staff` | `ServerLimits.DefaultStaffSlots` |

Staff fill staff slots first. Only when staff slots are full do staff count against regular slots. Regular players can only use regular slots.

- Set either value to `-1` for unlimited (default)
- `networkswitch.bypass` permission skips all capacity checks
- Capacity is enforced via `ServerPreConnectEvent` so it applies to ALL transfers (not just NetworkSwitch)
- Per-server overrides via config or the `/nslimit` command

### Backend Heartbeat & Identity

Paper backends generate a persistent UUID on first startup and heartbeat to Redis every 30 seconds. Velocity uses these to track which servers are online.

**Identity discovery** (automatic, zero-config):
1. Paper generates a UUID, saves to `server_id.conf` in the server root
2. Paper heartbeats to Redis using the UUID
3. On first player join, Paper sends a plugin message with its UUID to Velocity
4. Velocity resolves the server name from the connection and maps UUID to name
5. Paper receives the mapping and saves the name to `server_id.conf`

If the server is renamed in `velocity.toml`, the next identity check detects the mismatch and pushes the updated name.

Transfers to offline servers are denied with a configurable message.

### Live Server Stats in Redis

Every registered server has a stats hash in Redis, updated in real time:

```
Key: networkswitch:servers:<name>

Fields:
  players    — total player count
  staff      — players with networkswitch.staff
  bypass     — players with networkswitch.bypass
  maxPlayers — configured limit (-1 = unlimited)
  staffSlots — configured staff slots (-1 = unlimited)
  online     — true/false
  heartbeat  — plugin (heartbeat active), ping (responded to ping), offline
  uuid       — backend UUID (if identity mapped)
```

The full server list is also available as a SET at `networkswitch:servers`.

## Commands

### Velocity

| Command | Permission | Description |
|---|---|---|
| `/ns <player> <server>` | `networkswitch.admin` | Send a player to a server |
| `/nslimit` | `networkswitch.admin` | List all capacity limits |
| `/nslimit <server>` | `networkswitch.admin` | Show limits for a server |
| `/nslimit <server> <max> <staff>` | `networkswitch.admin` | Set capacity override (persists to config) |

Both commands have tab completion that filters as you type.

### Paper

| Command | Permission | Description |
|---|---|---|
| `/<servername>` | `networkswitch.server` | Switch to that server |
| `/servers` | `networkswitch.server` | Open server selector GUI |
| `/networkswitchreload` | `networkswitch.reload` | Refresh config from Redis |

Server commands are dynamically registered/unregistered based on the Velocity server list.

## Permissions

| Permission | Description |
|---|---|
| `networkswitch.server` | Use server switch commands and GUI |
| `networkswitch.reload` | Reload backend config from Redis |
| `networkswitch.admin` | Use `/ns` and `/nslimit` on Velocity |
| `networkswitch.staff` | Use reserved staff capacity slots |
| `networkswitch.bypass` | Bypass all server capacity limits |

## Configuration

### Velocity (`plugins/networkswitch/config.yml`)

All player-facing messages use [MiniMessage](https://docs.advntr.dev/minimessage/format.html) format with `%SERVER%` and `%PLAYER%` placeholders.

See `velocity-config.yml` in the jar for the full default config with comments.

### Paper (`plugins/NetworkSwitch/config.yml`)

Only the Redis connection. Everything else comes from Velocity via Redis.

## Redis Key Reference

| Key | Type | Description |
|---|---|---|
| `networkswitch:servers` | SET | Registered server names |
| `networkswitch:servers:<name>` | HASH | Live stats per server |
| `networkswitch:config` | HASH | Plugin config (messages, GUI, settings) |
| `networkswitch:heartbeat:<uuid>` | STRING | Backend heartbeat (TTL auto-expires) |
| `networkswitch:identity:<uuid>` | STRING | UUID to server name mapping |

### Pub/Sub Channels

| Channel | Message Format | Description |
|---|---|---|
| `networkswitch:servers:update` | `refresh` | Config changed, backends should re-read |
| `networkswitch:transfer` | `<server>:<playerUuid>` | Transfer request from Paper to Velocity |
| `networkswitch:identity` | `<uuid>:<serverName>` | Identity mapping from Velocity to Paper |

## server_id.conf

NetworkSwitch creates a `server_id.conf` file in the **server root directory** (next to `server.properties`). This is a shared convention — any plugin can read it to discover the server's identity without depending on NetworkSwitch.

### File Format

```properties
# Auto-generated server identity - do not edit
uuid=550e8400-e29b-41d4-a716-446655440000
name=lobby
```

- `uuid` — always present after first startup, persistent across restarts
- `name` — populated after Velocity maps the UUID to a server name (requires one player to connect)

### Reading From Other Plugins

```java
Path path = Bukkit.getServer().getWorldContainer().toPath().resolve("server_id.conf");

if (Files.exists(path)) {
    Properties props = new Properties();
    try (InputStream in = Files.newInputStream(path)) {
        props.load(in);
    }

    String uuid = props.getProperty("uuid");  // always present
    String name = props.getProperty("name");   // may be null on first-ever startup
}
```

### Important Notes

- The file lives in the server root, not inside any plugin folder
- `name` may be null/empty until the first player connects to trigger identity discovery
- For plugins that need the name immediately, fall back to a config value and re-check on `PlayerJoinEvent`
- The UUID is stable across restarts, plugin updates, and server renames — only regenerated if the file is deleted
- NetworkSwitch uses `load: STARTUP` in `plugin.yml` so it initializes before most plugins — but if your plugin also uses `STARTUP`, add `softdepend: [NetworkSwitch]` to guarantee load order

## Migrating Other Plugins to Use server_id.conf

A step-by-step guide for converting any Paper plugin from a hardcoded/config-based server name to the shared `server_id.conf` identity system.

### 1. Add a config toggle (opt-in)

Add a boolean config option so existing servers aren't affected. Default to `false`.

```yaml
# Use server_id.conf (from NetworkSwitch) to resolve the server name.
# When enabled, the shared identity file takes priority over ServerName.
# When disabled (default), ServerName is always used.
UseServerIdConf: false
```

Keep the existing `ServerName` config entry as the fallback.

### 2. Create a ServerIdentity utility class

The class needs to handle three scenarios:

| Scenario | Behaviour |
|---|---|
| `UseServerIdConf: false` | Always use config `ServerName`. Done. |
| `UseServerIdConf: true`, file has name | Use file name. Migrate DB if old name differs. |
| `UseServerIdConf: true`, file has no name yet | Use config `ServerName` temporarily. Re-check on first player join. |

**Core structure:**

```java
public class ServerIdentity {
    private String resolvedName;
    private boolean resolved; // true once we have the real name

    // Called in onEnable()
    public void initialize() {
        boolean useFile = plugin.getConfig().getBoolean("UseServerIdConf", false);
        String configName = plugin.getConfig().getString("ServerName", "server");

        if (!useFile) {
            resolvedName = configName;
            resolved = true;
            return;
        }

        String fileName = readNameFromFile();
        if (fileName != null && !fileName.isEmpty()) {
            resolvedName = fileName;
            resolved = true;
            // migrate if needed
        } else {
            resolvedName = configName; // temporary fallback
            resolved = false;
        }
    }

    // Called on first player join
    public void onFirstPlayerJoin() {
        if (resolved) return;
        String fileName = readNameFromFile();
        if (fileName != null && !fileName.isEmpty()) {
            String oldName = resolvedName;
            resolvedName = fileName;
            resolved = true;
            plugin.serverName = resolvedName; // update live reference
            // migrate if oldName differs
        }
    }
}
```

### 3. Read the file

The file location is always relative to the server root:

```java
Path path = Bukkit.getServer().getWorldContainer().toPath().resolve("server_id.conf");
```

Parse it with `java.util.Properties`:

```java
private String readNameFromFile() {
    Path path = Bukkit.getServer().getWorldContainer().toPath().resolve("server_id.conf");
    if (!Files.exists(path)) return null;

    Properties props = new Properties();
    try (InputStream in = Files.newInputStream(path)) {
        props.load(in);
    } catch (IOException e) {
        return null;
    }

    String name = props.getProperty("name");
    return (name != null && !name.trim().isEmpty()) ? name.trim() : null;
}
```

### 4. Wire into your plugin lifecycle

**onEnable:**
```java
serverIdentity = new ServerIdentity(this);
serverIdentity.initialize();
serverName = serverIdentity.getServerName();
```

**PlayerJoinEvent:**
```java
plugin.getServerIdentity().onFirstPlayerJoin();
```

This is safe to call on every join — the method returns immediately once resolved. Any event priority works since this is just a file read. Note that on the very first player join, the name won't be available yet — NetworkSwitch sends the identity request to Velocity over Redis and the response comes back async. The name will be resolved by the time the next player joins.

### 5. Handle the server name changing at runtime

If your plugin captures `serverName` in closures or final fields at startup, those won't update when the name resolves on first player join.

**Don't do this:**
```java
final String sName = serverName;
redisMessaging.subscribe(channel, message -> {
    if (!message.equals(sName)) return; // stale!
});
```

**Do this instead:**
```java
redisMessaging.subscribe(channel, message -> {
    if (!message.equals(serverName)) return; // reads current value
});
```

For classes that take `serverName` as a constructor parameter (like storage layers), you have two options:
- Pass the `ServerIdentity` object instead and call `getServerName()` when needed
- Accept that the constructor value may be stale and only matters for the initial load

### 6. One-time database migration

If your plugin stores server names in a database, add a migration method:

```java
// In your storage class
public int migrateServerName(String oldName, String newName) {
    try (Connection conn = dataSource.getConnection();
         PreparedStatement stmt = conn.prepareStatement(
             "UPDATE your_table SET server_name = ? WHERE server_name = ?")) {
        stmt.setString(1, newName);
        stmt.setString(2, oldName);
        return stmt.executeUpdate();
    } catch (SQLException e) {
        return 0;
    }
}
```

Call it from `ServerIdentity` when the resolved name differs from the config name:

```java
if (!resolvedName.equals(configName) && !configName.equals("server")) {
    // Run async — don't block the main thread
    Bukkit.getScheduler().runTaskAsynchronously(plugin, () -> {
        int updated = storage.migrateServerName(configName, resolvedName);
        logger.info("Migrated " + updated + " rows: '" + configName + "' -> '" + resolvedName + "'");
    });
}
```

**Important:** Only migrate when the old name isn't the placeholder default (e.g. `"server"`). You don't want to rename rows that were never real.

### 7. Add to your config updater (if you have one)

Make sure the new key gets added to existing configs automatically:

```java
CONFIG_DEFAULTS.put("UseServerIdConf", false);
```

### 8. Update your Redis key filtering

If your plugin uses the server name in Redis keys or pub/sub message filtering, make sure those references read the live `serverName` field rather than a cached copy. This is the most common source of bugs after migration.

### Migration Checklist

- [ ] Add `UseServerIdConf: false` to config with comments
- [ ] Add `UseServerIdConf` to config updater defaults
- [ ] Create `ServerIdentity` class
- [ ] Initialize in `onEnable()` before any code that uses the server name
- [ ] Call `onFirstPlayerJoin()` in your `PlayerJoinEvent` handler
- [ ] Update any captured/final `serverName` references to read the field directly
- [ ] Add `migrateServerName()` to your storage layer (if you store server names in DB)
- [ ] Test with `UseServerIdConf: false` — existing behaviour unchanged
- [ ] Test with `UseServerIdConf: true` and `server_id.conf` present — uses file name
- [ ] Test with `UseServerIdConf: true` and `server_id.conf` missing name — falls back, resolves on first join
- [ ] Test migration — set a different `ServerName` in config, enable the toggle, verify DB rows update

## Building

```
mvn clean package
```

The shaded jar at `target/NetworkSwitch-<version>.jar` works for both Velocity and Paper — drop the same jar on both sides.
