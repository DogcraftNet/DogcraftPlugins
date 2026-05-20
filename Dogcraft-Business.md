# DogcraftBusinesses

Player-owned businesses with employees, shareholders, scheduled payroll, and dividend distribution for Paper servers.

**Requirements:** Paper 1.21+, Java 21+, DogcraftEconomy 1.1.2+

---

## Features

- **Player-owned businesses** with UUID-based accounts managed through DogcraftEconomy
- **Hierarchical employee roles** — Owner, President, Vice President, Treasurer, Secretary, Employee
- **Shareholder system** with ownership invariant enforcement (owner must always hold the most shares)
- **Automated payroll** on configurable schedules (monthly, weekly, biweekly) with salary and dividend phases
- **Income-based dividends** computed on-demand from the economy ledger — no stored counters to desync
- **Peer-to-peer share trading** with offer/accept/decline flow and auto-expiry
- **Cross-server support** via Redis pub/sub — payroll assignment, balance sync, and notifications
- **Full admin toolkit** — freeze, audit, reassign, force-pay, list overdue/inactive, and more
- **Public API** for external plugin integration (shop plugins, quest systems, etc.) via reflection
- **MiniMessage chat UI** with clickable buttons, hover details, and interactive chat-input prompts
- **Config auto-migration** — new keys added on upgrade, unused keys tagged with version comments

---

## Installation

1. Place the `DogcraftBusinesses-1.0-SNAPSHOT.jar` into your server's `plugins/` directory.
2. Ensure **DogcraftEconomy** (1.1.2+) is installed and configured.
3. Ensure `server_id.conf` is present in your server's working directory with `uuid` and `name` properties. This file is managed by an external plugin and synced with the Velocity proxy.
4. Start the server. The plugin will generate `config.yml` and `messages.yml` on first run.
5. Edit `config.yml` to configure database connection, creation tax, limits, and other settings.
6. Reload with `/businessadmin reload` or restart the server.

---

## Configuration

The plugin ships two YAML files: `config.yml` (settings and limits) and `messages.yml` (all player-facing strings in MiniMessage format). Both are auto-updated on startup — new keys are added from defaults, and keys you have added that are not recognized are tagged with `# UNUSED (as of v...)`.

### `business.creation`

| Key | Default | Description |
|-----|---------|-------------|
| `tax` | `1000.0` | Flat fee charged to the player when creating a business |
| `tax-destination` | `burn` | Where the tax goes: `"burn"` destroys it, `"treasury:<UUID>"` sends it to an account |
| `starting-balance` | `0.0` | Initial balance funded from the creator's wallet |
| `starting-shares` | `100` | Shares issued to the owner at creation |
| `name-regex` | `^[A-Za-z0-9 _-]{3,32}$` | Validation regex for business names |
| `reserved-names` | *(subcommand names)* | Names rejected at create/rename to avoid command parser ambiguity |

### `business.limits`

| Key | Default | Description |
|-----|---------|-------------|
| `max-employees` | `50` | Maximum employees per business |
| `max-shareholders` | `100` | Maximum shareholders per business |
| `max-businesses-per-owner` | `3` | Maximum businesses a single player can own (`-1` for unlimited) |
| `min-salary` / `max-salary` | `0.0` / `100000.0` | Allowed salary range |
| `min-dividend-percent` / `max-dividend-percent` | `0.0` / `100.0` | Allowed dividend percentage range |

### `business.payroll`

| Key | Default | Description |
|-----|---------|-------------|
| `check-interval-minutes` | `5` | How often the scheduler checks for pending payrolls |
| `skip-on-shortfall` | `true` | If `true`, skip payroll and alert when funds are insufficient. If `false`, pay proportionally |
| `notify-owner-on-success` | `false` | Send a cross-server notification on successful payroll |
| `notify-owner-on-failure` | `true` | Send a cross-server notification when payroll fails |
| `stale-server-threshold-hours` | `48` | Hours past pay date before a business appears in `/bizadmin list-overdue` |

### `business.income-counting`

| Key | Default | Description |
|-----|---------|-------------|
| `count-owner-deposits` | `false` | Whether owner deposits count as income for dividend calculation |
| `count-shareholder-deposits` | `false` | Whether shareholder deposits count as income for dividend calculation |

### `business.dissolve`

| Key | Default | Description |
|-----|---------|-------------|
| `distribute-to-shareholders` | `true` | If `true`, remaining balance is distributed proportionally to shareholders on dissolve. If `false`, refunded to the owner |

### `business.shares`

| Key | Default | Description |
|-----|---------|-------------|
| `offer-expiry-minutes` | `30` | How long a pending share-sale offer stays valid |
| `expiry-sweep-interval-minutes` | `5` | How often the cleanup task sweeps expired offers |

### `business.rename`

| Key | Default | Description |
|-----|---------|-------------|
| `fee` | `2500.0` | Fee charged from the business account on rename |
| `cooldown-days` | `30` | Minimum days between successive renames |

### `business.shop-integration`

Maps each `BusinessRole` to a `ShopTier` for seeding shop permissions when a chest is registered to a business:

```yaml
tier-mapping:
  OWNER: MANAGER
  PRESIDENT: MANAGER
  VICE_PRESIDENT: MANAGER
  TREASURER: STAFF
  SECRETARY: STAFF
  EMPLOYEE: STAFF
```

### `storage`

| Key | Default | Description |
|-----|---------|-------------|
| `override` | `false` | Set to `true` to use a separate database connection instead of DogcraftEconomy's shared pool |
| `jdbc-url` | `jdbc:mysql://localhost:3306/dogcraft` | JDBC URL (only used when `override: true`) |
| `username` | `dogcraft` | Database username |
| `password` | `changeme` | Database password |

---

## Commands

### Player Commands — `/business` (alias `/biz`)

Most commands accept two forms: `/business <subcommand>` (infers the business if you have only one) or `/business <name> <subcommand>` (explicit). Tab completion suggests your associated business names and all subcommands.

#### Lifecycle

| Command | Description | Required Role |
|---------|-------------|---------------|
| `/business create <name>` | Create a new business (charges creation tax) | `dogcraftbusinesses.create` perm |
| `/business info [name]` | View business details, balance, roster, recent activity | Any role |
| `/business dissolve [name]` | Dissolve a business (two-step confirmation) | Owner |
| `/business rename <newname>` | Rename a business (fee + cooldown) | Owner |
| `/business list [page]` | Browse all businesses (paginated) | Any player |
| `/business help [subcommand]` | Show help for commands | Any player |

#### Staff Management

| Command | Description | Required Role |
|---------|-------------|---------------|
| `/business hire <player> <role> <salary>` | Hire an employee | Owner, President, VP |
| `/business fire <player>` | Fire an employee (cannot fire higher/equal rank) | Owner, President, VP |
| `/business promote <player> <role>` | Change an employee's role | Owner, President |
| `/business setsalary <player> <amount>` | Change an employee's salary | Owner, President, VP |
| `/business settitle <player> <title>` | Set a free-text display title (max 64 chars) | Owner, President, VP |
| `/business cleartitle <player>` | Clear display title, revert to role name | Owner, President, VP |
| `/business roster` | View employee roster with roles and salaries | Any role |

#### Money

| Command | Description | Required Role |
|---------|-------------|---------------|
| `/business deposit <amount>` | Deposit personal funds into the business | Shareholder or Owner |
| `/business withdraw <amount>` | Withdraw from business to personal wallet | Owner |
| `/business pay <player> <amount> [message]` | Pay a player from the business | Owner, President, Treasurer |
| `/business pay @business <name> <amount> [message]` | Pay another business | Owner, President, Treasurer |

#### Shares

| Command | Description | Required Role |
|---------|-------------|---------------|
| `/business shares issue <player> <count>` | Issue new shares (increases total supply) | Owner |
| `/business shares revoke <player> <count>` | Revoke shares (decreases total supply) | Owner |
| `/business shares give <player> <count>` | Gift your shares to another player | Any shareholder |
| `/business shares sell <buyer> <count> <price>` | Create a sale offer | Any shareholder |
| `/business shares list` | View all shareholders with counts and percentages | Any role |
| `/business shares-offer list` | View your pending incoming and outgoing offers | Any player |
| `/business shares-offer accept <id>` | Accept a share offer | Offer recipient |
| `/business shares-offer decline <id>` | Decline a share offer | Offer recipient |
| `/business shares-offer cancel <id>` | Cancel your own pending offer | Offer creator |

#### Scheduling

| Command | Description | Required Role |
|---------|-------------|---------------|
| `/business setschedule monthly <day>` | Set monthly payroll (day 1-28) | Owner, President |
| `/business setschedule weekly <day>` | Set weekly payroll (e.g., `friday`) | Owner, President |
| `/business setschedule biweekly <day>` | Set biweekly payroll (anchor is today) | Owner, President |
| `/business setschedule off` | Disable automatic payroll | Owner, President |
| `/business setdividend <percent>` | Set dividend percentage (0-100) | Owner |
| `/business payroll now` | Force an immediate payroll run | Owner |
| `/business payroll preview` | Preview next payroll without executing | Owner, President |

#### Communication & Ownership

| Command | Description | Required Role |
|---------|-------------|---------------|
| `/business broadcast <message>` | Send a cross-server message to all employees | Owner, President, Secretary |
| `/business transfer-ownership <player>` | Initiate ownership transfer (recipient must accept) | Owner |
| `/business accept-ownership <name>` | Accept a pending ownership transfer | Transfer recipient |

### Admin Commands — `/businessadmin` (alias `/bizadmin`)

All admin commands require the `dogcraftbusinesses.admin` permission.

| Command | Description |
|---------|-------------|
| `/businessadmin force-pay <name>` | Force a payroll run for a business |
| `/businessadmin force-dissolve <name>` | Force dissolve a business |
| `/businessadmin reassign <name> <server>` | Reassign a business's payroll to another server |
| `/businessadmin freeze <name> [reason]` | Freeze a business (blocks all operations except admin) |
| `/businessadmin unfreeze <name>` | Unfreeze a business |
| `/businessadmin audit <name>` | Audit a business against the economy ledger |
| `/businessadmin list-overdue` | List businesses past their pay date on stale servers |
| `/businessadmin list-inactive [days]` | List businesses whose owners haven't logged in recently |
| `/businessadmin orphans` | List businesses assigned to servers with no recent heartbeat |
| `/businessadmin refresh-server-names` | Update cached server display names from heartbeat keys |
| `/businessadmin confirm-server-identity-change` | Confirm a detected `server_id.conf` UUID change |
| `/businessadmin reload` | Reload `config.yml` and `messages.yml` |

---

## Permissions

| Permission | Default | Description |
|------------|---------|-------------|
| `dogcraftbusinesses.use` | `true` | Use `/business` commands |
| `dogcraftbusinesses.create` | `true` | Create businesses via `/business create` |
| `dogcraftbusinesses.admin` | `op` | Use all `/businessadmin` commands and `/business reload` |
| `dogcraftbusinesses.admin.bypass-stake-check` | `op` | Bypass the shareholder-only check on `/business deposit` |

These are Bukkit/Paper permission nodes (configurable via LuckPerms or similar). They control who can run commands at all, before in-business role checks apply.

---

## Roles & Permission Matrix

Each business has a fixed set of roles. The owner is determined by `businesses.owner_uuid` and always has full permissions regardless of any employee role they may also hold. The owner can also be hired as an employee (e.g. President) to receive a salary — their owner permissions always take precedence. Employees are assigned one of five roles.

| Permission | Owner | President | VP | Treasurer | Secretary | Employee |
|------------|:-----:|:---------:|:--:|:---------:|:---------:|:--------:|
| View business info | Y | Y | Y | Y | Y | Y |
| Hire | Y | Y | Y | | | |
| Fire | Y | Y | Y | | | |
| Promote/demote (below own rank) | Y | Y | | | | |
| Set salaries | Y | Y | Y | | | |
| Pay players/businesses | Y | Y | | Y | | |
| Set employee display title | Y | Y | Y | | | |
| Create/manage shops | Y | Y | Y | | | |
| Withdraw to self | Y | | | | | |
| Set pay schedule | Y | Y | | | | |
| Set dividend % | Y | | | | | |
| Issue/revoke shares | Y | | | | | |
| Send broadcast | Y | Y | | | Y | |
| Rename business | Y | | | | | |
| Transfer ownership | Y | | | | | |
| Dissolve business | Y | | | | | |

**Shareholder rights** (independent of role): Any shareholder can give their own shares to another player, sell shares via the offer system, and deposit personal funds into the business. The owner is always treated as an implicit shareholder even if they hold zero literal shares.

**Share issuance:** Only the owner can issue new shares (`/business shares issue`) or revoke existing shares (`/business shares revoke`). There is no public stock market — all shares originate from the owner and are distributed at their discretion. Share trading between players happens through the peer-to-peer offer system (`/business shares sell`).

---

## Payroll System

### Schedule Types

- **Monthly** — runs on a specific day of the month (1-28).
- **Weekly** — runs on a specific day of the week.
- **Biweekly** — runs every two weeks on a specific day, anchored from the date the schedule was set.
- **Disabled** — no automatic payroll. The owner can still trigger manually with `/business payroll now`.

### How It Works

Each server runs an async scheduler task every `check-interval-minutes` (default 5). On each tick, the server processes only businesses assigned to it via `assigned_server_uuid`.

**Phase 1 — Salary:** Each employee is paid their salary via `businessToPlayerTransfer`. If the business cannot cover the full payroll, the run is skipped (configurable), the owner is notified cross-server, and `next_pay_date` is not advanced — the business retries on the next tick after being funded.

**Phase 2 — Dividends:** Period income is computed on-demand by querying the economy ledger for incoming `business_pay` transactions since the last payroll. The dividend pool is `income * dividend_percent / 100`, capped at the remaining balance. Each shareholder receives their pro-rata share based on shares held.

**Rounding:** Individual payments are floored to two decimal places. The last shareholder in the list receives the remainder to absorb rounding error — no pennies are lost.

**Missed payroll catch-up:** When a server starts and finds businesses with `next_pay_date` in the past, it runs their payroll once (not N times for N missed periods) and logs a warning.

---

## Shares & Ownership

### Ownership Invariant

The owner must always hold the maximum number of shares (ties are OK). Every share-modifying operation enforces this rule. Operations that would put another player above the owner's share count are rejected with a message pointing to `/business transfer-ownership`.

### Share Offers

Players can create sale offers with `/business shares sell`. The recipient receives a notification with clickable Accept/Decline buttons. Offers auto-expire after `offer-expiry-minutes` (default 30). The ownership invariant is checked both at offer creation and at acceptance.

### Business-Held Shares

Businesses can hold shares in other businesses (holder type `BUSINESS`). These shares cannot be sold through the player offer flow. They are forfeited when the holding business is dissolved, or can be managed through admin intervention.

### Ownership Transfer

Transferring ownership requires an explicit command (`/business transfer-ownership <player>`) followed by acceptance from the recipient. Share purchases alone cannot shift ownership — this is a deliberate safety constraint.

---

## Cross-Server

DogcraftBusinesses operates across a network of Paper servers using Redis for caching and pub/sub.

### Redis Keyspace

- `dogcraft:business:meta:<uuid>` — JSON metadata (name, owner, schedule, etc.)
- `dogcraft:business:name_index:<lowercase_name>` — UUID lookup by name
- `dogcraft:business:owner_index:<owner_uuid>` — set of business UUIDs per owner
- `dogcraft:business:server_seen:<server_uuid>` — heartbeat key with server display name (24h TTL, refreshed every 12h)

### Pub/Sub Channels

- `dogcraft:business:update` — metadata changes (rename, schedule, freeze/unfreeze)
- `dogcraft:business:roster` — employee/shareholder changes
- `dogcraft:business:payroll` — payroll run results for cross-server employee notifications
- `dogcraft:economy:business_balance_update` — balance changes (published by DogcraftEconomy)

### Payroll Assignment

Each business is assigned to a specific server at creation. Only that server runs the scheduled payroll. Money operations (deposit, withdraw, pay) work from any server since the economy API is cross-server.

### Server Identity

On startup, the plugin compares the current `server_id.conf` UUID against a persisted value. If they differ (file was regenerated), the scheduler halts until an admin runs `/businessadmin confirm-server-identity-change`. This prevents silently orphaning businesses assigned to the old UUID.

Server display names are kept in sync via heartbeat keys. Use `/businessadmin refresh-server-names` to pull updated names from other servers without a restart.

---

## API for Developers

External plugins integrate with DogcraftBusinesses via the `net.dogcraft.businesses.api` package. See `docs/api.md` for full documentation.

### Quick Start

```java
// Reflection-based access (no compile-time dependency)
Class<?> apiClass = Class.forName("net.dogcraft.businesses.api.BusinessAPI");
Object registry = apiClass.getMethod("getRegistry").invoke(null);
```

Or with a direct dependency:

```java
BusinessRegistry registry = BusinessAPI.getRegistry();
CompletableFuture<Optional<Business>> biz = registry.getBusinessByName("AcmeCorp");
```

### Key Points

- `BusinessAPI.getRegistry()` returns the singleton `BusinessRegistry` (null until `onEnable` completes).
- All lookup methods return `CompletableFuture` — businesses live in MySQL + Redis and callers should not block the main thread.
- The API is **read-only** in v1. Mutations (hire, fire, share changes) should be dispatched as console commands.
- Money operations go through the DogcraftEconomy API directly (`playerToBusinessTransfer`, `businessAtomicTransfer`, etc.). Income for dividends is computed from the economy ledger automatically — there is no counter for external plugins to maintain.
- Register a `BusinessEventListener` to react to business changes (creation, dissolution, payroll, employee changes, etc.). Each callback uses default methods so you only override what you need.

---

## Building

```bash
mvn clean package
```

Output jar: `target/DogcraftBusinesses-1.0-SNAPSHOT.jar`

---

## Project Structure

```
net.dogcraft.businesses
├── api              Public API — stable contract, break only on major version bumps
│   ├── BusinessAPI, BusinessRegistry, BusinessEventListener
│   ├── Business, Employee, Shareholder, PayrollResult (data records)
│   └── BusinessRole, PayScheduleType, BusinessPermission, ShopTier (enums)
├── command          Brigadier command tree (Paper's LifecycleEvents.COMMANDS API)
├── config           Config + messages loading, auto-migration with unused key tagging
├── message          MiniMessage utilities, Messages.java (typed message methods)
├── payroll          Payroll scheduler, income calculator, dividend distribution
├── permission       Role permission matrix (dynamic checks per business)
├── prompt           Chat-input capture (AsyncChatEvent listener, pending prompts)
├── redis            Redis cache, pub/sub subscribers, heartbeat management
└── storage          Database repositories, Flyway schema migrations
```
