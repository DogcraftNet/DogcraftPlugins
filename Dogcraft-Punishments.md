# Dogcraft-Punishments

A custom punishment plugin for the Dogcraft Minecraft network. Velocity proxy + Paper backend, with full standalone (Paper-only) support.

Full design rationale lives in [PLAN.md](PLAN.md). This README covers what it does, how to install it, and how to operate it.

## What it does

- **Bans**, **temp-bans**, **IP-bans**, **mutes**, **temp-mutes**, **kicks**, **warnings**, with permanent pardons (`/unban`, `/unmute`).
- **Login enforcement** — Velocity blocks banned UUIDs and IP-bans before the connection reaches any backend; dual-key enforcement (UUID OR IP match) for IP-bans.
- **Mute enforcement** — Paper cancels signed chat (`AsyncChatEvent`), legacy chat (`AsyncPlayerChatEvent`), and configured chat-bypass commands (`/me`, `/msg`, etc.) at `EventPriority.LOWEST`.
- **Cross-server consistency** — Redis pub/sub keeps every Paper backend's mute cache current within milliseconds of issuance.
- **Soft-alert alt detection** — when a player connects from an IP linked to an actively-banned UUID, staff get an alert. The player is **not** auto-blocked. Avoids the CGNAT/shared-IP collateral problem.
- **`/alts` investigation tool** with fuzzy username matching (Damerau-Levenshtein + longest common substring) across current and historical names.
- **Warn-based escalation** — configurable thresholds auto-issue temp-bans / bans (idempotent against duplicate warns via `dc_escalation_log`).
- **Staff notes** — `/note`, `/notes`, `/delnote`, interleaved into `/history` for staff with the view permission.
- **Discord webhooks** for every action, with a separate `sensitive-webhook-url` for IP-bearing detail.
- **Tier-based immunity** — fully config-driven; staff can punish anyone whose tier is `<=` their own.
- **Silent flag (`-s`)** — suppresses public broadcasts and Discord; only staff with `dogcraft.punishment.alerts.silent` see the action.
- **Reason presets** — `/ban Steve #hacking` expands from `reasons.yml`.
- **gsbans auto-import** — on first boot against a MySQL database that contains `gamersafer_reportlog_v1` or `gamersafer_reportlog`, imports the legacy history (two-pass — pardons resolve back to imported rows). Idempotent.
- **LuckPerms integration (soft-dependency)** — if LuckPerms is installed, ban/mute actions remove the player from a configurable LP group, and unban/unmute (or temp expiry) adds them back. Use case: gate website chat access on group membership so in-game punishments revoke off-site permissions too. See "LuckPerms integration" section below.

## IP-address privacy

The actual IP value is hidden from staff who don't hold `dogcraft.punishment.ipban`. This applies everywhere:

- In-game alerts use the `alert-ipban` template (no IP) by default; `alert-ipban-detail` (with IP) only goes to permission holders.
- `/history` and `/alts` redact IPs in the output for unprivileged viewers.
- Discord webhooks: the default `webhook-url` never carries an IP. IP detail goes only to the optional `sensitive-webhook-url`. If `sensitive-webhook-url` is empty, no IP data ever leaves the server via Discord.

## Requirements

| | Network mode | Solo mode |
|---|---|---|
| Java | 21+ | 21+ |
| Proxy | Velocity 3.4.x | n/a |
| Backend(s) | Paper 1.21.x | Paper 1.21.x |
| Database | MySQL 8+ or MariaDB 10.6+ | SQLite (bundled — no setup) |
| Cache / message bus | Redis 7+ | none |
| Permissions plugin | LuckPerms (recommended; any plugin that implements `hasPermission` works) | same |

## Building

```bash
mvn clean package
```

Produces two shaded jars:

```
velocity/target/dogcraft-punishments-velocity-1.0.0-SNAPSHOT.jar
paper/target/dogcraft-punishments-paper-1.0.0-SNAPSHOT.jar
```

Each jar bundles HikariCP, Jackson, Jedis, Configurate, MySQL connector, and SQLite driver — no extra installation needed.

## Installing — network mode

1. Drop the **Velocity** jar into `<velocity>/plugins/` and start the proxy once. It creates `<velocity>/plugins/dogcraft-punishments/` with default `config.yml`, `messages.yml`, `escalation.yml`, `tiers.yml`, `discord.yml`, `reasons.yml`.
2. Edit `config.yml`:
   - `database.host`, `database.port`, `database.name`, `database.username`, `database.password`
   - `redis.host`, `redis.port`, `redis.password` (leave empty for unauth Redis)
3. Restart the proxy. The plugin runs the v1 schema migration and (if legacy `gamersafer_reportlog*` tables exist in the database) imports them.
4. Drop the **Paper** jar into each backend's `plugins/`. The Paper plugin auto-detects PROXY_COMPANION mode by reading `paper-global.yml` (`proxies.velocity.enabled: true`).
5. Configure each backend with the **same** database + Redis credentials as Velocity. Paper backends connect to the same database for fallback queries; Redis carries the live mute events.
6. Restart each backend.

You'll see `INFO: Dogcraft-Punishments enabled in PROXY_COMPANION mode` on each Paper backend; the proxy log shows the service wiring and any gsbans import progress.

## Installing — solo mode

For single-server installations with no proxy:

1. Drop the **Paper** jar into `plugins/` and start the server once.
2. Edit `<dataFolder>/dogcraft-punishments/config.yml`:
   - `mode.paper-mode: SOLO` (forces solo; otherwise it auto-detects)
   - `database.type: SQLITE` (uses `<dataFolder>/dogcraft-punishments/punishments.db`)
   - `redis.enabled: false`
3. Restart the server.

Solo mode registers the full staff command set on Paper. PROXY_COMPANION mode does not — commands live on Velocity.

## Commands

| Command | Permission | Description |
|---|---|---|
| `/ban <player> [-s] <reason>` | `dogcraft.punishment.ban` | Permanent ban |
| `/tempban <player> [-s] <duration> <reason>` | `dogcraft.punishment.tempban` | Temporary ban |
| `/ipban <player> [-s] <reason>` | `dogcraft.punishment.ipban` | Permanent IP ban (dual-key: UUID + IP) |
| `/tempipban <player> [-s] <duration> <reason>` | `dogcraft.punishment.tempipban` | Temporary IP ban |
| `/mute <player> [-s] <reason>` | `dogcraft.punishment.mute` | Permanent mute |
| `/tempmute <player> [-s] <duration> <reason>` | `dogcraft.punishment.tempmute` | Temporary mute |
| `/kick <player> [-s] <reason>` | `dogcraft.punishment.kick` | Disconnect + audit |
| `/warn <player> [-s] <reason>` | `dogcraft.punishment.warn` | Warn (may trigger escalation) |
| `/unban <player> [reason]` | `dogcraft.punishment.unban` | Pardon a ban / IP-ban |
| `/unmute <player> [reason]` | `dogcraft.punishment.unmute` | Pardon a mute |
| `/history [player] [page]` | `.history.self` / `.history.others` | Punishments + notes interleaved by timestamp |
| `/alts <player\|uuid\|ip>` | `dogcraft.punishment.alts` | Same-IP + fuzzy-name buckets (IP query needs `.ipban`) |
| `/alts trust <player>` | `dogcraft.punishment.alts.trust` | Mark a player as trusted (suppress alt soft-alerts on their joins) |
| `/alts untrust <player>` | `dogcraft.punishment.alts.trust` | Remove a trust mark |
| `/alts trust list` | `dogcraft.punishment.alts.trust` | List every trusted player |
| `/note <player> <text>` | `dogcraft.punishment.notes.add` | Add a staff note |
| `/notes <player>` | `dogcraft.punishment.notes.view` | List notes on a player |
| `/delnote <player> <id>` | `dogcraft.punishment.notes.delete` | Delete a note |
| `/punishment reload` | `dogcraft.punishment.reload` | Reload config files (see "Reload scope" below) |

### Duration format

`30m`, `2h`, `1d`, `2w`, `1mo` (= 30d), `1y` (= 365d). Concatenate for combined units: `1d12h` = 36 hours.

### Reason presets

If a reason starts with `#`, it's looked up in `reasons.yml`:

```
/ban Steve #hacking caught on screenshare
  → reason: "Use of unauthorized client modifications caught on screenshare"
```

Unknown `#keys` fall through as literal text.

### Silent flag

`-s` immediately after the player name (or after the duration for temp commands) suppresses the public broadcast, the standard staff alert, and the Discord webhook. Only staff with `dogcraft.punishment.alerts.silent` see a single `[silent]` line.

## Permissions

### Command permissions

All command permissions follow `dogcraft.punishment.<command>` — see the table above.

### Alert permissions (gated; not default-on)

Every command action has its own alert permission — grant only the ones each staff role should hear.

| Permission | Fires for |
|---|---|
| `dogcraft.punishment.alerts.ban` | `/ban` (permanent ban) |
| `dogcraft.punishment.alerts.tempban` | `/tempban` |
| `dogcraft.punishment.alerts.ipban` | `/ipban` |
| `dogcraft.punishment.alerts.tempipban` | `/tempipban` |
| `dogcraft.punishment.alerts.unban` | `/unban` (covers both regular and IP-ban pardons) |
| `dogcraft.punishment.alerts.mute` | `/mute` (permanent mute) |
| `dogcraft.punishment.alerts.tempmute` | `/tempmute` |
| `dogcraft.punishment.alerts.unmute` | `/unmute` |
| `dogcraft.punishment.alerts.kick` | `/kick` |
| `dogcraft.punishment.alerts.warn` | `/warn` |
| `dogcraft.punishment.alerts.escalation` | Auto-escalations |
| `dogcraft.punishment.alerts.altdetect` | Soft alert when a banned alt joins |
| `dogcraft.punishment.alerts.silent` | One-line alert for `-s` silent actions (any command) |

### IP-detail visibility

`dogcraft.punishment.ipban` doubles as the "see IP values" gate. Without it, IPs are redacted in `/history`, `/alts`, alert messages, and Discord embeds. With it, the `-detail` alert templates and the sensitive Discord webhook send the IP.

### Immunity tiers

Defined entirely in `tiers.yml` — no hardcoded tier nodes. Default example:

| Permission | Tier name | Tier id |
|---|---|---|
| `dogcraft.punishment.tier.1` | Staff | 1 |
| `dogcraft.punishment.tier.2` | Senior Staff | 2 |
| `dogcraft.punishment.tier.3` | Admin | 3 |
| `dogcraft.punishment.tier.4` | Owner | 4 |

Staff can punish anyone whose highest matching tier id is `<=` their own. Console always bypasses immunity.

## Configuration files

All under `<dataFolder>/dogcraft-punishments/`.

| File | Purpose |
|---|---|
| `config.yml` | Database + Redis credentials, plugin mode, blocked-while-muted command list, public broadcast toggle |
| `messages.yml` | All player-facing and staff-facing message templates (Adventure MiniMessage) |
| `escalation.yml` | Warn → action thresholds (network: Velocity only; solo: Paper) |
| `tiers.yml` | Immunity tier definitions |
| `discord.yml` | Webhook URLs (incl. sensitive variant), per-event enable flags, colors |
| `reasons.yml` | Preset reason text accessed via `#key` |
| `lp.yml` | LuckPerms group integration (no-op if LuckPerms isn't installed) |

PROXY_COMPANION Paper backends technically only need `config.yml` + `messages.yml`; the others can be left at defaults since Velocity owns issuance.

## How alts detection actually works (read this)

Soft-alert at login does **not** block anyone. When player `X` connects from IP `Y`, the plugin:

1. Lets `X` in.
2. Asynchronously queries `dc_ip_links` for all UUIDs ever seen on `Y` (excluding `X`).
3. Bulk-checks active bans on those UUIDs (one Redis `HMGET`, MySQL fallback).
4. If any are actively banned, posts an alert to staff holding `dogcraft.punishment.alerts.altdetect` and fires the Discord `alt-detected` webhook.

`X`'s connection is unaffected. Staff investigate and decide whether to act.

**Trusted players** (`/alts trust <player>`) are exempt from the soft-alert pass entirely — when they connect, no alt alerts fire even if their IP links to actively-banned UUIDs. Use this to whitelist confirmed-not-alts (CGNAT collisions, siblings/roommates of banned players, etc.). Removable with `/alts untrust <player>`. Trust state is per-UUID and persists across reconnects.

`/alts <target>` returns four buckets:
- **Same-IP accounts** — distinct UUIDs that have ever shared an IP with the target.
- **Similar names — same IP** — fuzzy-matched names from the same-IP set.
- **Similar names — different IP** — fuzzy matches across all of `dc_players` + `dc_player_names`.
- **Known IPs** — IPs the target has used (values gated by `dogcraft.punishment.ipban`).

Fuzzy matching: Damerau-Levenshtein distance `<= max(2, length/4)` OR longest common substring `>= 4 chars`. Names normalize via lowercase + trailing-digit/underscore strip (so `Steve123` matches `Steve_VIP`).

Buckets cap at 25 per call; overflow shows `(+ more results — refine search)`.

## LuckPerms integration

If [LuckPerms](https://luckperms.net/) is installed, in-game ban/mute actions can revoke a configurable LP group. The intended use case: a player's website chat, web-panel access, or any off-server permission gated on group membership gets revoked the moment they're banned in-game, and restored when they're unbanned (or when a temp expires).

**Soft dependency.** The plugin runs fine without LuckPerms — `lp.yml` is just ignored if LP isn't on the classpath. The factory detects LP at boot via `Class.forName` and falls back to a no-op hook if absent.

**Default `lp.yml`** uses the same group for both, suitable for the "one group gates everything" pattern:

```yaml
luckperms:
  enabled: true
  ban-groups:
    - verified
  mute-groups:
    - verified
```

Operators can split them (`ban-groups: [banned]`, `mute-groups: [chat-blocked]`) or use multiple groups per action — the config takes a list.

**Behaviour:**

| Trigger | Action |
|---|---|
| `/ban`, `/tempban`, `/ipban`, `/tempipban` | Remove player from `ban-groups` |
| `/mute`, `/tempmute` | Remove player from `mute-groups` |
| `/unban` | Add player back to `ban-groups` (if no other active ban applies) |
| `/unmute` | Add player back to `mute-groups` (if no other active mute applies) |
| Temp punishment expires while online | Add back via the same multi-active-safe path |
| Temp punishment expires while plugin offline | Caught at next plugin boot via `scheduleExpiryRestorations` — past-due rows process immediately, future ones get scheduled `runLater` tasks |
| Silent (`-s`) punishment | LP groups still get removed/restored — silent only suppresses alerts, not enforcement |
| gsbans data import | LP is **not** touched during bulk legacy imports |

**Multi-active safety:** before restoring a group, the service checks whether the player has another active ban (or active mute, for mute groups). If yes, restore is skipped — they stay out of the group until *all* relevant active punishments end.

**Required setup:**

1. Install LuckPerms on the proxy (for Velocity-mode networks) or the server (for solo Paper).
2. Create the group(s) you reference in `lp.yml` if they don't already exist (`/lp creategroup verified`).
3. Configure your gates (website chat, web panel, etc.) to require membership in that group.
4. Edit `lp.yml`'s `ban-groups` / `mute-groups` to match. Run `/punishment reload` (or restart).

**What about LuckPerms tier permissions?** The plugin's immunity-tier system (section 12 of PLAN.md) reads any standard `hasPermission()` call, so LuckPerms grants `dogcraft.punishment.tier.N` the same as any perm plugin — no special hookup needed for tiers.

## Schema and migrations

V1 ships these tables (auto-created on first boot):

- `dc_punishments` — every issued punishment, never deleted
- `dc_ip_links` — login IP → UUID history
- `dc_notes` — staff notes
- `dc_escalation_log` — auto-escalation idempotency ledger
- `dc_players` — UUID → current name
- `dc_player_names` — full username history
- `dc_schema_version` — applied migration ledger
- `dc_import_state` — one-shot import markers (e.g. gsbans)

Future schema changes ship as numbered scripts (`V002__add_some_column.sql`) under `core/src/main/resources/migrations/`. `MigrationRunner` runs them in order on boot and aborts with a clear error if a previously-applied script's checksum changes (so accidental in-place edits get caught).

## gsbans migration

If the configured MySQL database contains `gamersafer_reportlog_v1` and/or `gamersafer_reportlog`, the plugin imports them on first startup:

- Two-pass: non-pardon rows first (with old-id → new-id mapping), then UNBAN/UNMUTE rows resolve via the map and call the normal pardon path.
- `dc_players` is seeded from `gamePlayerUsername` so offline UUID lookups work immediately.
- 1000-row batched transactions; idempotent via `dc_import_state` marker.
- Legacy tables are never modified — operators verify and drop them manually.

You'll see `INFO: gsbans import: imported N rows from gamersafer_reportlog_v1` on the run that does the import; subsequent boots skip it.

## Behaviour during outages

| Scenario | Behaviour |
|---|---|
| Redis unreachable at boot | Continue in MySQL-only mode; pub/sub disabled until Redis returns |
| Redis drops mid-session | Each call falls back to MySQL; subscriber thread reconnects on a 5s backoff |
| Paper starts, Redis empty | MuteCache pre-warms from MySQL `dc_punishments WHERE status='ACTIVE' AND type IN ('MUTE','TEMP_MUTE')` |
| **MySQL AND Redis both unreachable** at login | **Fail-closed.** Login denied with the configured `system-unavailable-kick` message. Banned players cannot slip through during an outage. |

## Reload scope

`/punishment reload` re-reads the YAML configs and pushes updated values into:

- `EscalationService` (warn thresholds)
- `ImmunityService` (tier list + clears offline-tier cache)
- `ReasonPresetService` (`#key` table)

It does **not** rebuild connection pools (DB / Redis / HTTP). Connection-config changes require a plugin restart — this is deliberate, to avoid disrupting in-flight queries.

## Discord webhook setup

Two URLs in `discord.yml`:

- `webhook-url` — main staff channel. Receives every enabled event, but IP-ban / alt-detected embeds **never** include the actual IP value.
- `sensitive-webhook-url` — optional. Only IP-bearing detail embeds go here. Use a private channel only senior staff can see. Leave empty to skip — no IP data will leave the server via Discord.

Both webhooks are async — Discord latency never delays a command.

## Known limitations

- `/history` interleaves notes and punishments by pulling up to 1000 punishments + all notes into memory. Players with massive histories may see noticeable latency. A proper paginated-merge at the repository level is future work.
- `/alts` bucket overflow shows "(+ more)" rather than a precise count — internal cap is `BUCKET_CAP + 1` for true detection, but the rendering doesn't report the exact remainder.
- IPv6 addresses match exactly (no `/64` prefix grouping). Realistic for v1 since IPv6-heavy traffic is rare on Minecraft networks today; promote to prefix matching if needed.
- No alt-exemption mechanism — if staff confirm "these two accounts are siblings, not the same person," the soft alert will keep firing on every login. Add `dc_alt_exemptions` if this becomes painful.
- No VPN/proxy detection (listed as future work in PLAN.md section 21).

## Project layout

```
api/        — pure-Java models, enums, repository + command interfaces, utilities
core/       — business logic: services, repositories, command executors, Redis layer
velocity/   — proxy plugin (thin platform adapters wrapping core executors)
paper/      — backend plugin (mute enforcement, mode detection, optional solo mode)
PLAN.md     — full design document
```

Both platform jars shade api + core + all transitive runtime dependencies (Hikari, Jedis, Jackson, Configurate, MySQL connector, SQLite driver). Drop-in deployable.

## License

Internal Dogcraft network use. See `LICENSE` if/when one is added.
