# DogcraftEconomy

Economy plugin for the [Dogcraft.net](https://dogcraft.net) Minecraft server network. Provides a shared economy across multiple servers using Redis for real-time balance synchronization and MySQL for persistent storage.

## Features

- **Cross-server balance sync** — Balances are stored in Redis and shared across all servers in real time. No more balance resets on world/server changes.
- **Atomic operations** — All balance modifications use Redis Lua scripts to prevent double-spend and race conditions, even when multiple servers modify the same player concurrently.
- **Offline player support** — Deposits and payments work for offline players (e.g. QuickShop purchases while the shop owner is on another server or offline).
- **Transaction ledger** — Every balance change is logged to a MySQL `transaction` table with timestamps, amounts, types, and running balances. Supports auditing to verify ledger consistency.
- **Cross-server messaging** — Payment notifications are delivered to players regardless of which server they're on via Redis pub/sub.
- **Vault provider** — Registers as a Vault `Economy` provider, so any plugin using Vault (QuickShop, Essentials, etc.) automatically uses DogcraftEconomy.
- **Graceful degradation** — If Redis goes down, falls back to per-player JVM locks for single-server safety. Balances are always persisted to MySQL with retry logic.
- **Shared server identity** — Optionally reads the server name from NetworkSwitch's `server_id.conf` instead of a per-plugin config value. Automatically migrates transaction history when the server name changes.

## Requirements

- Paper 1.18+ (developed against 1.21.4)
- Java 21+
- [Vault](https://github.com/MilkBowl/Vault)
- MySQL/MariaDB
- Redis

## Commands

| Command | Description | Permission |
|---------|-------------|------------|
| `/balance` | Check your balance | — |
| `/balance <player>` | Check another player's balance | `dogcrafteconomy.balance.other` |
| `/pay <player> <amount>` | Pay another player | — |
| `/economy add <player> <amount>` | Add to a player's balance | `dogcrafteconomy.admin.add` |
| `/economy remove <player> <amount>` | Remove from a player's balance | `dogcrafteconomy.admin.remove` |
| `/economy set <player> <amount>` | Set a player's balance | `dogcrafteconomy.admin.set` |
| `/economy audit <player>` | Audit a player's transaction history | `dogcrafteconomy.admin.audit` |

**Aliases:** `/bal`, `/eco`

## Permissions

| Permission | Description |
|------------|-------------|
| `dogcrafteconomy.balance.other` | Check another player's balance |
| `dogcrafteconomy.admin` | Access to `/economy` command |
| `dogcrafteconomy.admin.all` | All admin sub-permissions |
| `dogcrafteconomy.admin.add` | Add to a player's balance |
| `dogcrafteconomy.admin.remove` | Remove from a player's balance |
| `dogcrafteconomy.admin.set` | Set a player's balance |
| `dogcrafteconomy.admin.audit` | Audit a player's transaction history |

## Configuration

The plugin generates a `config.yml` on first run. Key settings:

```yaml
general:
  Debug: false

currency:
  Name: DCD
  Symbol: "\u0110"
  Decimal: 2
  start:
    Balance: 100.0

network:
  server:
    Name: server              # Unique name for this server instance
    UseServerIdConf: false    # Use server_id.conf from NetworkSwitch instead of Name

transaction:
  log:
    Saves: true
    Loads: true
    Withdraws: true
    Deposits: true
    Payments: true
    admin: true

database:
  settings:
    database: eco
    Username: user
    Password: password
    Host: localhost:3306
    pool:
      maxSize: 5
      minIdle: 2
      connectionTimeout: 5000

redis:
  settings:
    Host: localhost:6379
    Expiry_seconds: 7200       # Redis key TTL (2 hours)
```

**Important:** Each server on the network must have a unique server name. All servers must point to the same MySQL database and Redis instance.

### Server Identity

By default, the server name comes from `network.server.Name` in the config. If you use [NetworkSwitch](https://github.com/DogcraftNet/NetworkSwitch) and want all plugins to share the same Velocity-registered server name, set `UseServerIdConf: true`. The plugin will read the name from `server_id.conf` in the server root directory.

When `UseServerIdConf` is enabled:
- If `server_id.conf` has a name, it's used immediately and any existing transaction rows with the old config name are migrated automatically.
- If the name isn't available yet (first startup before any player joins), the config `Name` is used as a temporary fallback. The name resolves on the first player join and transaction rows are migrated at that point.

## Architecture

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│   Server A   │   │   Server B   │   │   Server C   │
│  (survival)  │   │   (mall)     │   │  (creative)  │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       └──────────┬───────┴──────────┬───────┘
                  │                  │
           ┌──────┴──────┐   ┌──────┴──────┐
           │    Redis    │   │    MySQL    │
           │  (live bal) │   │ (persistent)│
           └─────────────┘   └─────────────┘
```

- **Redis** is the single source of truth for live balances. All servers read/write through shared Redis keys using atomic Lua scripts.
- **MySQL** is the persistent store. Balances are asynchronously written to the database after every change, with 3-attempt retry on failure.
- **Reconciliation** runs every 5 minutes, comparing Redis and MySQL for all online players and correcting any drift.
- **Shutdown hook** synchronously saves all online players to MySQL before the server stops.

### Transaction Ledger

The `transaction` table acts as an append-only ledger. Every balance change is recorded with:

| Column | Description |
|--------|-------------|
| `id` | Auto-increment transaction ID |
| `player_uuid` | Player UUID |
| `player_name` | Player name at time of transaction |
| `server` | Server that processed the transaction |
| `transaction` | Type: `withdraw`, `deposit`, `payment`, `load`, `save`, `admin` |
| `balance` | Transaction amount |
| `tbalance` | Player's balance after the transaction |
| `date` | Timestamp |
| `message` | Description of the transaction |

The `/economy audit <player>` command compares the database balance against the last recorded ledger balance to detect inconsistencies.

## API

See [API.md](API.md) for the full developer API reference, including dependency setup, method documentation, and migration notes.

### Quick Start

**Gradle:**
```groovy
repositories {
    maven { url = 'https://repo.dogcraft.net/releases' }
}

dependencies {
    compileOnly 'net.dogcraft:DogcraftEconomy:1.0.3'
}
```

**Usage:**
```java
DogcraftEconomyApi api = DogcraftEconomy.getApi();

// Withdraw / deposit
api.withdraw(offlinePlayer, 100.0);
api.deposit(offlinePlayer, 50.0);

// Atomic transfer (prevents double-spend)
BalanceResult result = api.atomicTransfer(fromUuid, toUuid, 50.0);

// Get balance
double balance = api.getBalance(uuid);

// Format currency
String formatted = api.format(100.0); // "100.00 Đ"
```

## Building

```bash
./gradlew shadowJar
```

The output jar will be in `target/`.

## Publishing

Artifacts are published to [repo.dogcraft.net](https://repo.dogcraft.net) via Reposilite.

```bash
./gradlew publish
```

Credentials should be in your user-level `~/.gradle/gradle.properties` (not in the project):

```properties
dogcraftRepositoryReleasesUsername=deploy
dogcraftRepositoryReleasesPassword=<your-token>
```

## License

Developed for the Dogcraft.net Minecraft server network.
