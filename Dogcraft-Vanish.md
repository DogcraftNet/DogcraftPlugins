# Dogcraft Vanish

A standalone vanish plugin for Paper 1.21+ servers. No external plugin dependencies required.

Vanished players are completely hidden from non-staff players — no visual presence, no sounds, no mob interactions, no environmental tells. Vanish state persists across server switches and relogs via Redis.

---

## Features

- Full player hiding using Paper's native `hidePlayer` API
- Vanish state persistence across server restarts and proxy switches via Redis
- Collision and name tag suppression via scoreboard teams
- Detection suppression: mobs, item pickups, damage, pressure plates, tripwires, sculk sensors, projectiles, raids
- Chat rerouting to staff-only channel while vanished
- Fake join/quit messages (configurable)
- Action bar reminder shown to vanished players
- Staff glow effect visible only to players who can see the vanished player
- Plugin message broadcast on `dogcraft:vanish` channel for tab list and HUD integrations
- Daily rotating audit log with configurable retention
- Block interaction prevention (configurable)
- Permission check on join — strips vanish if permission was revoked while offline

---

## Requirements

- Paper 1.21 or later
- Java 21
- Redis server

---

## Installation

1. Build the plugin with `mvn clean package`
2. Place the resulting jar from `target/` into your server's `plugins/` directory
3. Start the server to generate the default `config.yml`
4. Edit `plugins/Dogcraft-Vanish/config.yml` with your Redis connection details
5. Restart the server or reload the plugin

---

## Commands

| Command | Description | Permission |
|---------|-------------|------------|
| `/vanish` | Toggle vanish on yourself | `dogcraft.vanish` |
| `/vanish <player>` | Toggle vanish on another player | `dogcraft.vanish.others` |
| `/vanishlist` | List all currently vanished players network-wide | `dogcraft.vanish.see` |

### `/vanish`

When used without arguments, toggles your own vanish state. When used with a player name, toggles vanish for that player (requires `dogcraft.vanish.others`). Can also be run from console with a player argument.

### `/vanishlist`

Queries Redis for all vanished players across the network. Players on the current server are marked with a green `*` indicator. Each entry shows the player name and the server they vanished on.

---

## Permissions

| Permission | Description | Default |
|------------|-------------|---------|
| `dogcraft.vanish` | Can vanish and unvanish self | op |
| `dogcraft.vanish.others` | Can vanish and unvanish other players | op |
| `dogcraft.vanish.see` | Can see vanished players in-world. Receives all staff alerts and notifications | op |

### How permissions interact

- A player with only `dogcraft.vanish` can toggle their own vanish state but cannot see other vanished players or receive staff notifications.
- A player with `dogcraft.vanish.see` sees vanished players in-world with a glow effect, receives join/quit/toggle notifications in chat, and sees rerouted chat from vanished players.
- A player with `dogcraft.vanish.others` can toggle vanish for any online player. Staff are notified when this happens including who triggered it.

---

## Configuration

The default `config.yml` is generated on first startup:

```yaml
redis:
  host: "localhost"
  port: 6379
  password: ""
  timeout-ms: 2000

vanish:
  unvanish-on-disconnect: false
  permission-check-on-join: true
  allow-block-interact: false
  staff-chat-while-vanished: true
  action-bar-interval: 40
  fake-quit-message: ""
  fake-join-message: ""
  notify-prefix: "§8[§7Vanish§8] "
  log:
    retention-days: 30
```

### Redis

| Key | Description |
|-----|-------------|
| `host` | Redis server hostname |
| `port` | Redis server port |
| `password` | Redis password. Leave empty for no authentication |
| `timeout-ms` | Connection timeout in milliseconds |

### Vanish behavior

| Key | Description |
|-----|-------------|
| `unvanish-on-disconnect` | When `true`, players are fully unvanished when they disconnect. When `false`, vanish state is kept in Redis and restored on rejoin |
| `permission-check-on-join` | When `true`, checks if a previously vanished player still has the `dogcraft.vanish` permission on join. If they lost it while offline, they are silently unvanished |
| `allow-block-interact` | When `true`, vanished players can break and place blocks. When `false`, block interactions are cancelled |
| `staff-chat-while-vanished` | When `true`, public chat from vanished players is cancelled and rerouted to players with `dogcraft.vanish.see` |
| `action-bar-interval` | Ticks between action bar refreshes. The action bar fades after ~3 seconds, so this must be below 60. Default 40 (2 seconds) |
| `fake-quit-message` | Broadcast to all players when a vanished player disconnects. `{player}` is replaced with the player name. Leave empty to show nothing |
| `fake-join-message` | Broadcast to all players when a vanished player joins. `{player}` is replaced with the player name. Leave empty to show nothing |
| `notify-prefix` | Prefix prepended to all staff alert messages |

### Log

| Key | Description |
|-----|-------------|
| `retention-days` | Number of days to keep log files. Files older than this are deleted on startup. Set to `0` to keep logs forever |

---

## What is suppressed

When a player is vanished, the following is blocked or hidden from non-staff players:

| Category | Detail |
|----------|--------|
| **Visibility** | Player is hidden via `hidePlayer` API. Invisible to non-staff in-world, tab list, and player indicators |
| **Collision** | Disabled via scoreboard team. Vanished players cannot push or be pushed by others |
| **Name tags** | Hidden via scoreboard team `NAME_TAG_VISIBILITY: NEVER` |
| **Mob targeting** | Mobs will not target or aggro on vanished players |
| **Item pickup** | Vanished players cannot pick up items |
| **Damage** | Vanished players cannot deal or receive entity damage |
| **Block interaction** | Block breaking and placing cancelled (configurable via `allow-block-interact`) |
| **Pressure plates & tripwires** | All pressure plate types and tripwire hooks will not activate |
| **Sculk sensors** | Vibrations from vanished players are cancelled |
| **Projectiles** | Arrow, snowball, and all projectile launches are cancelled |
| **Raids** | Bad Omen will not trigger a raid while vanished |
| **Chat** | Public chat is rerouted to staff-only (configurable via `staff-chat-while-vanished`) |
| **Join/quit messages** | Suppressed entirely. Optional fake messages can be configured |

### Staff visibility

Players with `dogcraft.vanish.see` will:

- See vanished players in-world with a glow effect
- Receive notifications when players vanish, unvanish, join silently, or leave while vanished
- See rerouted chat from vanished players
- See vanished players in `/vanishlist` with server information

---

## Logging

All vanish events are written to daily rotating log files in `plugins/Dogcraft-Vanish/logs/`.

**File format:** `vanish-YYYY-MM-DD.log`

**Log entry format:**
```
[2025-03-22 09:15:02] VANISH        Notch            (uuid) by Notch on survival-overworld
[2025-03-22 09:47:33] LEFT_VANISHED Notch            (uuid) left server while vanished — state retained in Redis
[2025-03-22 11:02:08] RESTORE       Notch            (uuid) on survival-nether
[2025-03-22 11:45:19] UNVANISH      Notch            (uuid) by Notch on survival-nether
```

### Event types

| Type | When logged |
|------|-------------|
| `VANISH` | Player vanished via `/vanish` command |
| `UNVANISH` | Player unvanished via command, disconnect (if `unvanish-on-disconnect: true`), or permission lost on join |
| `LEFT_VANISHED` | Player disconnected while vanished with `unvanish-on-disconnect: false` |
| `RESTORE` | Vanish state restored from Redis on server join |
| `STARTUP` | Vanished player entry found in Redis when the plugin starts |

---

## Redis Keys

The plugin uses two Redis key patterns. No TTL is set on either — vanish state is intentional and persistent.

| Key | Type | Description |
|-----|------|-------------|
| `vanish:active` | SET | UUIDs of all currently vanished players |
| `vanish:player:{uuid}` | HASH | Metadata for each vanished player |

**Hash fields in `vanish:player:{uuid}`:**

| Field | Description |
|-------|-------------|
| `name` | Display name at time of vanish |
| `vanished_at` | Epoch milliseconds |
| `vanished_by` | UUID of the player who initiated the vanish, or `CONSOLE` |
| `server` | Server name at time of vanish |

---

## Plugin Messaging

On every vanish state change, a message is sent on the `dogcraft:vanish` channel. Any plugin or system that needs to react — tab lists, scoreboards, custom HUDs — can subscribe to this channel.

**Message format:**

| Byte(s) | Content |
|---------|---------|
| `[0]` | `0x01` = vanished, `0x00` = unvanished |
| `[1+]` | Player UUID as UTF string |

---

## Multi-server setup

Vanish state is stored in Redis, making it work across a proxy network:

1. Point all servers to the same Redis instance in `config.yml`
2. When a player vanishes on one server and switches to another, the new server reads their state from Redis on join and silently restores vanish
3. `/vanishlist` queries Redis directly, showing vanished players across all servers with their current server name
4. The plugin message channel can be used by proxy plugins to sync tab list state

---

## Building

```
mvn clean package
```

The shaded jar will be in `target/`.
