# DCLink2

A [Velocity](https://velocitypowered.com/) proxy plugin that handles account linking, whitelisting, permission management, and verification for Minecraft servers. Players must link their Minecraft account through a website, verify their email, and optionally pass age verification (GamerSafer) or Patreon pledge requirements before they can play.

**Authors:** Ironboundred, William278

---

## Features

- **Account Linking** — Players are kicked with a unique link code on first join. They register on your website using that code to link their Minecraft account.
- **Email Verification** — Linked players must verify their email address before joining backend servers.
- **Age Verification (GamerSafer)** — Optional integration with GamerSafer to verify player ages. Configurable allowed age groups.
- **Patreon Integration** — Optional Patreon pledge requirements with tiered LuckPerms group assignment.
- **LuckPerms Integration** — Automatically manages permission groups based on linked status, Patreon tier, and other criteria.
- **Bypass List** — Exempt specific UUIDs from all verification requirements.
- **Player Activity Tracking (ProxyData)** — Monitors online status, server, client brand, IP, ping, view distance, and LuckPerms roles in real time.
- **Client Type Announcements** — Announces player client types to staff and warns non-vanilla players about mods policy.
- **Resource Pack Enforcement** — Sends and enforces a server resource pack on connect with configurable kick-on-decline.
- **Cookie Caching** — Caches linking profiles in memory and Velocity cookies to eliminate database queries on server switches.
- **Configurable Messages** — All player-facing messages are customizable with [MineDown](https://github.com/Phoenix616/MineDown) formatting.
- **Hot Reload** — Configuration can be reloaded via the Velocity proxy reload command without restarting.

---

## Requirements

- **Java 21** or higher
- **Velocity 3.4.0+** proxy server
- **LuckPerms** plugin installed on Velocity
- **MySQL** database
- A website that handles account registration/linking (consuming link codes from the database), email verification, Patreon linking, and GamerSafer age verification

---

## Installation

1. Download the latest `DCLink2-x.x.x.jar` from releases (or build from source).
2. Place the JAR in your Velocity proxy's `plugins/` directory.
3. Start (or restart) the Velocity proxy. A default `config.yml` will be generated in `plugins/dclink2/`.
4. Stop the proxy and edit `plugins/dclink2/config.yml` with your database credentials and settings.
5. Create the required LuckPerms groups (see [LuckPerms Setup](#luckperms-setup)).
6. Start the proxy.

---

## Building from Source

```bash
git clone https://github.com/your-org/DCLink2.git
cd DCLink2
./gradlew build
```

The output JAR will be in `target/DCLink2-x.x.x.jar`.

---

## Configuration

The configuration file is generated at `plugins/dclink2/config.yml` on first run. Below is a breakdown of each section.

### General

```yaml
general:
  # UUIDs that bypass all linking/verification requirements
  bypass_list:
    - "2dd0cc3b-0825-4c3e-bd99-3bf07ef27447"
  link_code:
    # Length of generated link codes
    length: 6
    # Characters used to generate link codes
    character_set: "0123456789abcdefghijklmnopqrstuvwxyz"
```

### Database

```yaml
database:
  host: "localhost"
  port: 3306
  database: "dclink2"
  table_name: "dclink"
  username: "root"
  password: "password"
```

| Key | Description |
|---|---|
| `host` | MySQL server hostname or IP |
| `port` | MySQL server port |
| `database` | Database name (must exist before starting) |
| `table_name` | Table name used by DCLink2 (default: `dclink`). Useful if running multiple instances. |
| `username` | MySQL user |
| `password` | MySQL password |

### Website

```yaml
website_hook:
  host: "dogcraft.net"
  profile_url: "https://dogcraft.net/u/"
```

| Key | Description |
|---|---|
| `host` | Your website domain. Used in kick messages to direct players to register/verify. |
| `profile_url` | Base URL for player profiles on your website. |

### LuckPerms

```yaml
luckperms:
  linked_group: "cyberdog"
  patreon_group: "patreon"
```

| Key | Description |
|---|---|
| `linked_group` | LuckPerms group assigned to players who have linked their account. |
| `patreon_group` | Default LuckPerms group for Patreon supporters (used as fallback when no specific tier matches). |

### Patreon

```yaml
patreon:
  required: false
  min_level: 100
  patreon_levels:
    "100": "patreon"
```

| Key | Description |
|---|---|
| `required` | If `true`, players **must** have a Patreon pledge at or above `min_level` to join. |
| `min_level` | Minimum pledge amount (in cents) required to pass the Patreon check. |
| `patreon_levels` | Map of pledge amounts (in cents) to LuckPerms group names. Players are assigned the group matching their pledge or the nearest lower tier. |

### GamerSafer

```yaml
gamersafer:
  settings:
    required: true
    allowed_groups:
      - "ADULT"
```

| Key | Description |
|---|---|
| `required` | If `true`, players must verify their age through GamerSafer. |
| `allowed_groups` | List of GamerSafer age categories allowed on the server (e.g., `ADULT`). |

### Client Type Announcements

```yaml
client_type:
  enabled: true
  mods_policy_url: "https://dogcraft.net/wiki/Rules/Mods_policy"
```

| Key | Description |
|---|---|
| `enabled` | If `true`, announces each player's client type (vanilla, Fabric, Forge, etc.) to staff on join. |
| `mods_policy_url` | URL to your server's mods policy. Non-vanilla players are shown a reminder linking here. |

### Resource Pack

```yaml
resource_pack:
  enabled: false
  url: "https://example.com/pack.zip"
  hash: ""
  prompt: "Please accept our resource pack to play!"
  kick_on_decline: true
```

| Key | Description |
|---|---|
| `enabled` | If `true`, sends a resource pack offer to players when they connect to a backend server. |
| `url` | Direct download URL to your resource pack `.zip` file. |
| `hash` | SHA-1 hash of the pack file as a hex string (optional). Used by the client to verify the download and skip re-downloading if already applied. |
| `prompt` | Message shown on the resource pack accept/decline screen. |
| `kick_on_decline` | If `true`, the pack is marked as required. On 1.17+ clients the decline button is hidden (accept or disconnect). On older clients, players are kicked if they skip or close the prompt. |

### Cookie Cache

```yaml
cache:
  cookie_enabled: true
  cookie_ttl_minutes: 10
```

| Key | Description |
|---|---|
| `cookie_enabled` | If `true`, caches player linking profiles in memory and as Velocity cookies. Eliminates database queries on server switches. Requires Velocity 3.3+ and Minecraft 1.20.5+ clients for cookie persistence across reconnects. |
| `cookie_ttl_minutes` | How long a cached profile is valid before a fresh database lookup is forced. |

### Locales

All player-facing messages are configurable under the `locales` key. Messages support [MineDown](https://github.com/Phoenix616/MineDown) formatting and `%1%`, `%2%`, etc. placeholders.

See the generated `config.yml` for the full list of locale keys and their defaults.

---

## LuckPerms Setup

DCLink2 requires the following LuckPerms groups to exist. Create them before starting the plugin.

### Required Groups

1. **Linked group** (default: `cyberdog`) — Assigned to all players who have linked their account.

   ```
   /lp creategroup cyberdog
   ```

   This group should grant the `dogcraft.linking.linked` permission, which DCLink2 checks before allowing players onto backend servers:

   ```
   /lp group cyberdog permission set dogcraft.linking.linked true
   ```

2. **Patreon group** (default: `patreon`) — Only needed if using Patreon integration.

   ```
   /lp creategroup patreon
   ```

   Grant the Patreon permission so players can access Patreon-gated servers:

   ```
   /lp group patreon permission set dogcraft.linking.patreon true
   ```

### Optional Permissions

| Permission | Description |
|---|---|
| `dogcraft.linking.linked` | Required to join backend servers. Granted via the linked group. |
| `dogcraft.linking.patreon` | Grants access when Patreon is required. |
| `dclink.linkstatus.other` | Allows viewing other players' link status via `/linkstatus <player>`. |
| `dclink.join.hide` | Hides a player's join message from other players. |
| `dclink.join.seehidden` | Allows seeing hidden join messages. |
| `dogcraft.clienttype.announce` | Receives client type announcements when players connect. |
| `dogcraft.clienttype.bypass` | Hides the player's real client type from announcements. |
| `dogcraft.proxydata.reloadrank` | Allows using `/rankreload` to refresh cached rank permissions. |

---

## Commands

| Command | Description | Permission |
|---|---|---|
| `/linkstatus` | View your own linking status (linked, email, age, Patreon). | None (players only) |
| `/linkstatus <player>` | View another player's linking status. | `dclink.linkstatus.other` |

---

## How It Works

### Player Join Flow

1. Player connects to the Velocity proxy.
2. DCLink2 checks if the player exists in the database and updates their username.
3. If the player is on the **bypass list**, all checks are skipped.
4. If the player's account is **not linked**, they are kicked with a unique link code and a URL to your website's registration page.
5. If the player's account **is linked**, a welcome message is broadcast and they proceed to server connection checks.

### Server Connection Flow

When a linked player attempts to join a backend server, DCLink2 validates (in order):

1. **Email verification** — Player must have a verified email.
2. **Patreon check** (if `patreon.required: true`) — Player must meet the minimum pledge level.
3. **Age verification** (if `gamersafer.settings.required: true`) — Player must have verified their age and be in an allowed age group.
4. **Linked permission check** — The `dogcraft.linking.linked` permission must be present (granted via LuckPerms group).

If any check fails, the player is kicked with a descriptive message directing them to resolve the issue.

---

## Setup Guides

### Guide 1: Patreon-Only Setup

Use this setup if you want to run a Patreon-exclusive server where only paying supporters can play. Age verification is disabled.

#### Step 1: Configure `config.yml`

```yaml
# Disable GamerSafer age verification
gamersafer:
  settings:
    required: false

# Enable Patreon requirement
patreon:
  required: true
  min_level: 100  # Minimum pledge in cents ($1.00)
  patreon_levels:
    "100": "patreon"       # $1.00+ gets "patreon" group
    "500": "patreon-gold"  # $5.00+ gets "patreon-gold" group
    "1000": "patreon-vip"  # $10.00+ gets "patreon-vip" group
```

#### Step 2: Create LuckPerms Groups

```bash
# Required: linked group
/lp creategroup cyberdog
/lp group cyberdog permission set dogcraft.linking.linked true

# Required: Patreon groups (one per tier)
/lp creategroup patreon
/lp group patreon permission set dogcraft.linking.patreon true

/lp creategroup patreon-gold
/lp group patreon-gold permission set dogcraft.linking.patreon true

/lp creategroup patreon-vip
/lp group patreon-vip permission set dogcraft.linking.patreon true
```

#### Step 3: Website Integration

Your website needs to:

1. Accept new user registrations with a **link code** (read from the `linkcode` column in the database).
2. When a user registers and links their account, set `linked = 1` in the database.
3. Handle email verification and set `email_verified = 1` when complete.
4. When a user links their Patreon account, update the `pledge` column with their pledge amount in cents.

#### Step 4: Verification Flow for Players

1. Player joins the server for the first time and is kicked with a link code.
2. Player goes to your website, creates an account, and enters their link code.
3. Player verifies their email address.
4. Player links their Patreon account on your website (pledge amount is written to the database).
5. Player rejoins the server. DCLink2 checks their pledge meets `min_level` and assigns the appropriate LuckPerms group.

---

### Guide 2: GamerSafer-Only Setup

Use this setup if you want to require age verification but do not need Patreon gating.

#### Step 1: Configure `config.yml`

```yaml
# Enable GamerSafer age verification
gamersafer:
  settings:
    required: true
    allowed_groups:
      - "ADULT"

# Disable Patreon requirement
patreon:
  required: false
  min_level: 100
  patreon_levels:
    "100": "patreon"
```

#### Step 2: Create LuckPerms Groups

```bash
# Required: linked group
/lp creategroup cyberdog
/lp group cyberdog permission set dogcraft.linking.linked true
```

No Patreon groups are needed in this setup. You can still define them if you want to optionally reward Patreon supporters with cosmetic groups, but they won't be required to join.

#### Step 3: Website Integration

Your website needs to:

1. Accept new user registrations with a **link code**.
2. Set `linked = 1` when the account is linked.
3. Handle email verification and set `email_verified = 1`.
4. Integrate with the GamerSafer API. When a player completes age verification, write their age category to the `age_group` column (e.g., `ADULT`).

#### Step 4: Verification Flow for Players

1. Player joins and is kicked with a link code.
2. Player registers on your website and enters the link code.
3. Player verifies their email.
4. Player completes GamerSafer age verification through your website.
5. Player rejoins. DCLink2 confirms `age_group` matches an entry in `allowed_groups` and allows them in.

---

## Database Schema

DCLink2 automatically creates the following tables on startup.

### dclink Table (Account Linking)

| Column | Type | Description |
|---|---|---|
| `uuid` | `VARCHAR(36)` | Player's Minecraft UUID (primary key) |
| `linked` | `TINYINT(1)` | `1` if account is linked, `0` otherwise |
| `age_group` | `VARCHAR(255)` | GamerSafer age category (e.g., `ADULT`), or `NULL` |
| `email_verified` | `TINYINT(1)` | `1` if email is verified, `0` otherwise |
| `mcname` | `VARCHAR(16)` | Player's current Minecraft username |
| `linkcode` | `VARCHAR(12)` | Generated link code for account linking |
| `role` | `VARCHAR(30)` | Player's primary LuckPerms group |
| `pledge` | `INT` | Patreon pledge amount in cents (`-1` = no pledge) |
| `created_at` | `TIMESTAMP` | Row creation time |
| `updated_at` | `TIMESTAMP` | Last update time |

### playerdata Table (ProxyData)

| Column | Type | Description |
|---|---|---|
| `uuid` | `VARCHAR(36)` | Player's Minecraft UUID (primary key) |
| `username` | `VARCHAR(16)` | Player's current Minecraft username |
| `rank` | `VARCHAR(40)` | Primary LuckPerms group |
| `isOnline` | `BOOLEAN` | Whether the player is currently online |
| `server` | `VARCHAR(40)` | Current backend server name |
| `clientBrand` | `VARCHAR(40)` | Client type (e.g., `vanilla`, `fabric`, `forge`) |
| `remoteaddress` | `TEXT` | Player's IP address |
| `hostUsed` | `VARCHAR(40)` | Virtual host used to connect |
| `viewDistance` | `INT` | Player's render distance setting |
| `proxy` | `VARCHAR(40)` | Proxy instance name |
| `ping` | `BIGINT` | Network latency in milliseconds |
| `all_ranks` | `VARCHAR(255)` | Comma-separated list of all LuckPerms groups |
| `lastUpdate` | `TIMESTAMP` | Last time data was saved |

### rank_perms Table (ProxyData)

| Column | Type | Description |
|---|---|---|
| `id` | `INT` | Auto-increment primary key |
| `rank` | `VARCHAR(40)` | LuckPerms group name |
| `permission_node` | `VARCHAR(100)` | Permission string |

---

## ProxyData (Player Tracking)

DCLink2 includes built-in player activity tracking (formerly the standalone Dogcraft-ProxyData plugin). When enabled, it monitors and persists detailed player information to the `playerdata` table in real time.

### What It Tracks

- **Online status** — Which players are online right now
- **Current server** — Which backend server each player is on
- **Client brand** — Whether the player is using vanilla, Fabric, Forge, etc.
- **Network info** — IP address, virtual host used to connect, ping
- **Player settings** — View distance
- **LuckPerms roles** — Primary group and all inherited groups
- **Permission nodes** — Cached per-rank permission nodes in the `rank_perms` table

### ProxyData Configuration

```yaml
proxydata:
  # Set to false to disable player tracking entirely
  enabled: true
  # Identifier for this proxy (useful for multi-proxy setups)
  proxy_name: "proxy"
  # How often player data is saved to the database (in seconds)
  save_interval_seconds: 5
  table_names:
    playerdata: "playerdata"
    rank_perms: "rank_perms"
```

### ProxyData Commands

| Command | Description | Permission |
|---|---|---|
| `/rankreload <rank>` | Reload cached permissions for a LuckPerms group. Console only. | `dogcraft.proxydata.reloadrank` |

### How ProxyData Works

1. When a player begins connecting, their IP and virtual host are captured.
2. On full login, their UUID and view distance are recorded.
3. When they connect to a backend server, their online status, server name, role, ping, and full role list are updated.
4. Client brand is captured when the client sends it.
5. Every 5 seconds (configurable), all in-memory player data is flushed to the database and offline players are removed from memory.
6. On proxy shutdown, all players are marked offline and saved.
7. On startup, any players left marked as online (from a crash) are reset to offline.

LuckPerms permission nodes are lazily loaded per rank on first player join and cached in memory. They are persisted to the `rank_perms` table. When a group's permissions change in LuckPerms, the cache is automatically refreshed.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Plugin fails to start with database error | Check your `database.*` settings in `config.yml`. Ensure the MySQL server is running and the database exists. |
| Players kicked with "Account linking failed" | The `dogcraft.linking.linked` permission is not being granted. Verify the linked LuckPerms group exists and has the permission set. |
| Config reload breaks the plugin | DCLink2 keeps the previous valid config if a reload fails. Check the proxy logs for the specific YAML error. |
| Players not getting Patreon roles | Ensure `patreon_levels` keys match the pledge amounts (in cents) being written to the database. DCLink2 matches the nearest lower tier. |
| LuckPerms groups not updating | LuckPerms operations are async. If issues persist, check that the group names in `config.yml` exactly match the LuckPerms group names (case-sensitive). |

---

