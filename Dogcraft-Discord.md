# Dogcraft Moderation Bot

Python + discord.py + MySQL moderation bot. Per-guild config lives in the database so the Dogcraft website can share it. Syncs Discord roles to a linked user's Minecraft ranks.

## Features

- Slash-command moderation: `/warn`, `/kick`, `/ban`, `/unban`, `/timeout`, `/history`, `/case`
- Staff notes (`/note`)
- Configurable per-guild log channels (member / mod / role)
- Message delete & edit logging from a message cache
- Member join / leave logging with kick/ban disambiguation
- Role change logging: member role changes, role create/delete/update (name, permissions, color, hoist, mentionable)
- Channel / category / thread create / delete / rename + permission-overwrite diffing + topic / slowmode / NSFW / bitrate / user-limit
- Pin & unpin tracking with audit-log actor lookup
- Server-wide logging: guild settings, invites, webhooks, integrations (incl. bot-added), AutoMod rules & triggers, scheduled events
- Discord-native timeout detection (catches mods using the Discord UI instead of `/timeout`)
- Auto-escalation: configurable warn thresholds for auto-kick / auto-ban
- Rank sync: pulls `playerdata.all_ranks` from the site DB and applies mapped Discord roles every 5 min

## Requirements

- Python 3.11+
- MySQL 8.0+ with the Dogcraft site schema (`users`, `playerdata`, etc.)
- A Discord Application with a Bot user

## Discord Developer Portal setup

1. **Create the app** — https://discord.com/developers/applications → **New Application**.
2. **Bot tab** → **Reset Token** → copy the token (you'll paste this into `.env` as `DISCORD_TOKEN`). Keep **Public Bot** *off* for a self-hosted mod bot.
3. **Privileged Gateway Intents** (same tab) — enable both:
   - **SERVER MEMBERS INTENT**
   - **MESSAGE CONTENT INTENT**
4. **Installation tab** → **Install Link** → set to **None** (otherwise private apps throw *"Private application cannot have a default authorization link"*).
5. **OAuth2 → URL Generator:**
   - Scopes: `bot`, `applications.commands`
   - Bot Permissions: `Moderate Members`, `Kick Members`, `Ban Members`, `Manage Roles`, `View Audit Log`, `Send Messages`, `Embed Links`, `Read Message History`
   - Copy the generated URL and open it to invite the bot to your server.

> The bot's role must sit **above** any role it manages via `/ranks map` — otherwise role assignment silently fails.

## Installation

```bash
git clone <repo> Dogcraft-discord
cd Dogcraft-discord

# create and activate a virtualenv
python -m venv .venv
# Windows (PowerShell)
.venv\Scripts\Activate.ps1
# Unix
source .venv/bin/activate

pip install -r bot/requirements.txt
```

## Configuration

Copy the template and fill it in:

```bash
cp bot/.env.example bot/.env
```

| Variable | Default | Purpose |
|---|---|---|
| `DISCORD_TOKEN` | *(required)* | Bot token from the Developer Portal |
| `MYSQL_HOST` | `localhost` | MySQL server hostname |
| `MYSQL_PORT` | `3306` | MySQL port |
| `MYSQL_USER` | *(required)* | DB user (needs DDL on bot DB, SELECT on site DBs) |
| `MYSQL_PASSWORD` | *(required)* | DB password |
| `MYSQL_DATABASE` | *(required)* | The bot's own DB (holds `guild_config`, `infractions`, etc.) |
| `LOG_LEVEL` | `INFO` | Python logging level |
| `SITE_DB` | `dogcraft_website` | Schema that holds `users` (read-only) |
| `MC_DB` | *(empty)* | Schema that holds `playerdata`. Leave empty if it's in `MYSQL_DATABASE`. |

### Database migrations

Run Alembic from the `bot/` directory:

```bash
cd bot
alembic upgrade head
cd ..
```

This creates the bot's tables: `guild_config`, `infractions`, `notes`, `message_cache`, `member_events`, `role_mappings`, `managed_member_roles`.

## Running

**Run from the project root, not from inside `bot/`:**

```bash
python -m bot.main
```

Running `python -m main` from inside `bot/` breaks relative imports.

## First-time guild configuration

Once the bot is in a server, run these as a user with **Manage Server**:

```
/config set_log mod #mod-log          # required
/config set_log member #member-log    # optional — falls back to mod-log
/config set_log role #role-log        # optional — falls back to mod-log
/config set_log channel #channel-log  # optional — falls back to mod-log
/config set_log rank #rank-log        # optional — falls back to mod-log
/config set_threshold kick 3          # optional: auto-kick at 3 active warns
/config set_threshold ban 5           # optional: auto-ban at 5 active warns
/config view                          # review
```

To wire up Minecraft rank sync:

```
/ranks map default @Member
/ranks map vip     @VIP
/ranks map admin   @Admin
/ranks list
/ranks sync        # kick off an immediate full-guild sync
```

## Command reference

### Moderation

| Command | Description |
|---|---|
| `/warn <user> <reason>` | Logs a warning, DMs user, may trigger auto-escalation |
| `/kick <user> <reason>` | Kicks member |
| `/ban <user> <reason> [delete_days]` | Bans user (by member or ID); `delete_days` 0–7 |
| `/unban <user_id> [reason]` | Lifts a ban |
| `/timeout <user> <duration> [reason]` | Durations like `10m`, `2h`, `7d`; `0` clears. Max 28 days. |
| `/purge <user> <count> [reason]` | Delete up to 200 recent messages from that user in current channel (14-day Discord cap). A user target is required — the command will not wipe a channel wholesale. |
| `/history <user>` | Shows infractions, notes, and join/leave history |
| `/case view <case_id>` | View a single case |
| `/case edit <case_id> <new_reason>` | Update a case's reason |
| `/case revoke <case_id> [reason]` | Mark a case inactive |

### Notes

| Command | Description |
|---|---|
| `/note add <user> <content>` | Add a staff-only note |
| `/note list <user>` | List notes on a member |
| `/note remove <note_id>` | Delete a note |

### Config

| Command | Description |
|---|---|
| `/config view` | Current settings |
| `/config set_log <member\|mod\|role\|channel\|rank> [channel]` | Configure a log channel (omit channel to clear) |
| `/config toggle_dm` | Toggle DMing users on infractions |
| `/config set_threshold <kick\|ban> <value>` | Auto-escalate at N active warns (0 disables) |
| `/config set_account_flag_days <days>` | Flag joins with accounts younger than this |
| `/config set_cache_days <days>` | Message cache retention |

### Rank sync

| Command | Description |
|---|---|
| `/ranks map <rank_name> <role>` | Map a site rank → Discord role (per guild) |
| `/ranks unmap <rank_name>` | Remove mapping *and* strip the role from everyone |
| `/ranks list` | Show current mappings |
| `/ranks sync [user]` | Force immediate reconciliation (whole guild if omitted) |

## Permissions

Authorization comes from the site's `rank_perms` table. Each slash command declares a permission node; if any rank in the invoker's `playerdata.all_ranks` grants that node in `rank_perms` (with Bukkit-style wildcards), the command runs.

**Fallback:** if the site lookup yields no match, the bot checks the Discord guild permission associated with the command (`moderate_members` for mod commands, `manage_guild` for config/ranks.map). Administrator always passes via the fallback.

**Wildcard rules:** `*` matches everything. `modbot.mod.*` matches `modbot.mod.warn`, `modbot.mod.case.view`, etc. (but not `modbot.config.*`).

**Example `rank_perms` rows:**

```sql
INSERT INTO rank_perms (rank, permission_node) VALUES
  ('admin',   '*'),                      -- full access
  ('mod',     'modbot.mod.*'),           -- all moderation
  ('mod',     'modbot.notes.*'),
  ('mod',     'modbot.ranks.list'),
  ('mod',     'modbot.ranks.sync'),
  ('trial',   'modbot.mod.warn'),        -- trial mods can only warn
  ('trial',   'modbot.mod.history');
```

**Command → node reference:**

| Command | Node | Discord fallback |
|---|---|---|
| `/warn` | `modbot.mod.warn` | `moderate_members` |
| `/kick` | `modbot.mod.kick` | `moderate_members` |
| `/ban` | `modbot.mod.ban` | `moderate_members` |
| `/unban` | `modbot.mod.unban` | `moderate_members` |
| `/timeout` | `modbot.mod.timeout` | `moderate_members` |
| `/purge` | `modbot.mod.purge` | `moderate_members` |
| `/history` | `modbot.mod.history` | `moderate_members` |
| `/case view` | `modbot.mod.case.view` | `moderate_members` |
| `/case edit` | `modbot.mod.case.edit` | `moderate_members` |
| `/case revoke` | `modbot.mod.case.revoke` | `moderate_members` |
| `/note add` | `modbot.notes.add` | `moderate_members` |
| `/note list` | `modbot.notes.list` | `moderate_members` |
| `/note remove` | `modbot.notes.remove` | `moderate_members` |
| `/config view` | `modbot.config.view` | `manage_guild` |
| `/config set_log` | `modbot.config.logs` | `manage_guild` |
| `/config toggle_dm` | `modbot.config.dm` | `manage_guild` |
| `/config set_threshold` | `modbot.config.thresholds` | `manage_guild` |
| `/config set_account_flag_days` | `modbot.config.account_flag` | `manage_guild` |
| `/config set_cache_days` | `modbot.config.cache_days` | `manage_guild` |
| `/ranks map` | `modbot.ranks.map` | `manage_guild` |
| `/ranks unmap` | `modbot.ranks.unmap` | `manage_guild` |
| `/ranks list` | `modbot.ranks.list` | `moderate_members` |
| `/ranks sync` | `modbot.ranks.sync` | `moderate_members` |

Permission lookups are cached per Discord ID for 60 seconds. Adding/removing rows in `rank_perms` or `playerdata.all_ranks` will take effect on the next cache refresh.

## Website integration

The bot reads the site's tables **read-only** — no writes, no bot-owned roster. Source of truth:

- `users.discord_id` — set by the site's Discord OAuth flow
- `users.uuid` — set when the user links their Minecraft account
- `playerdata.all_ranks` — comma-separated rank names consumed by the sync loop

Linking / unlinking is purely site-driven:

```sql
-- Link
UPDATE users SET discord_id = ?, uuid = ? WHERE id = ?;

-- Unlink Discord
UPDATE users SET discord_id = NULL WHERE id = ?;
```

The bot's 5-minute reconcile loop picks up both directions automatically. Unlinking causes the next cycle to strip every role the bot had assigned. Soft-deleted users (`users.deleted_at IS NOT NULL`) are skipped.

## Rank sync behavior

- Source of truth: `playerdata.all_ranks` (comma-separated rank names).
- Per guild, wire each rank to a Discord role with `/ranks map <rank> <role>`.
- The bot only touches roles it assigned (tracked in `managed_member_roles`); manual roles are never removed.
- If a linked user has a rank that isn't mapped in a given guild, the bot posts a one-time notice to that guild's mod-log until the mapping is added.
- `/ranks unmap` also strips the previously-mapped role from every member who had it.

## Operational notes

- **Message cache** writes every non-bot message to `message_cache`. Pruned daily per each guild's `message_cache_days`.
- **Leave disambiguation** — when a member is removed, the bot waits 500 ms then checks the audit log to tell apart kick / ban / genuine leave. Bot-initiated bans/kicks are tracked in a 5 s in-memory TTL set to avoid double-logging.
- **Audit log actor lookup** for role changes uses 500 ms + one retry to dodge Discord's write lag.
- **Auto-escalation thresholds** count **active** warns. `/case revoke` removes a warn from the tally.
- **DMs** are best-effort; a failed DM never blocks the command (noted in the ephemeral reply).

## Project structure

```
Dogcraft-discord/
├── plan.md
├── README.md                       # ← you are here
└── bot/
    ├── main.py                     # bot entry point
    ├── config.py                   # .env loader
    ├── db.py                       # aiomysql pool + helpers
    ├── requirements.txt
    ├── .env.example
    ├── alembic.ini
    ├── alembic/
    │   ├── env.py
    │   └── versions/
    │       ├── 0001_initial.py
    │       ├── 0002_site_integration.py
    │       ├── 0003_discord_members.py
    │       └── 0004_drop_discord_members.py
    ├── cogs/
    │   ├── guild_config_cog.py     # /config
    │   ├── moderation.py           # /warn /kick /ban /unban /timeout /history /case
    │   ├── notes.py                # /note
    │   ├── member_logs.py          # joins, leaves, deletes, edits
    │   ├── role_logs.py            # role change tracking
    │   ├── channel_logs.py         # channels, categories, threads, pins, overwrites
    │   ├── server_logs.py          # guild settings, invites, webhooks, integrations, automod, scheduled events
    │   ├── role_sync.py            # /ranks + reconcile loop
    │   └── tasks.py                # message cache pruner
    └── utils/
        ├── checks.py               # permission decorators
        ├── config_cache.py         # in-memory guild_config
        ├── audit.py                # audit-log lookup helpers
        ├── recent_actions.py       # TTL set for bot's own mod actions
        └── embeds.py               # embed builders
```

## Troubleshooting

**`ImportError: attempted relative import with no known parent package`**
You're running from inside `bot/`. Run `python -m bot.main` from the **project root**.

**`discord.errors.LoginFailure: Improper token has been passed.`**
Token in `.env` is wrong, is the placeholder, or got invalidated (Discord auto-resets tokens it sees posted publicly). Reset under Bot → Reset Token and re-paste with no quotes / no `Bot ` prefix.

**`PrivilegedIntentsRequired`**
You haven't enabled Server Members + Message Content intents in the Developer Portal. See setup step 3.

**"Private application cannot have a default authorization link"**
Installation tab → Install Link → **None**. Use OAuth2 URL Generator to build the invite.

**Roles aren't being assigned by `/ranks sync`**
The bot's own role must sit above the target role in Server Settings → Roles. If it does and sync still fails, check the bot's logs — it logs `WARNING` when `add_roles` returns Forbidden.

**Audit log actor shows as `[UNKNOWN]`**
Grant the bot `View Audit Log` permission in the server.

## Development

Adding a new migration:

```bash
cd bot
alembic revision -m "describe the change"
# edit the generated file in alembic/versions/
alembic upgrade head
```

Re-syncing slash commands: restart the bot. `setup_hook` calls `bot.tree.sync()` on every boot.
