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
- Activity leaderboards — chat, voice, reactions, replies, mentions (queryable via `/leaderboard` or read directly from the DB for the website)
- Message + scheduled-event archival for the website (replaces the separate SiteLink bot) — per-channel opt-in, edit / delete tracking, bulk backfill via `/archive dump`
- Attachment downloader + FastAPI server — fetches images/files to local disk on archive, serves them via `GET /attachments/{id}` with an `X-API-Key` gate (Discord CDN URLs expire otherwise)
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
| `ATTACHMENT_DIR` | `./attachments` | Where the bot saves downloaded Discord attachments |
| `API_SECRET` | *(empty)* | Shared secret for the FastAPI attachment endpoint. Leave empty to disable the server. |
| `API_HOST` | `127.0.0.1` | Bind address for the attachment API |
| `API_PORT` | `8765` | Port for the attachment API |

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

### Leaderboards (any member)

| Command | Description |
|---|---|
| `/leaderboard <category> [period] [limit]` | Top N on the chosen metric |

### Archive (Manage Server)

| Command | Description |
|---|---|
| `/archive enable <channel>` | Start archiving messages from this channel |
| `/archive disable <channel>` | Stop archiving (keeps existing rows) |
| `/archive list` | Show archive-enabled channels |
| `/archive dump <channel> [limit] [force]` | Backfill recent history (up to 1000 messages) |
| `/archive refresh_events` | Re-sync all scheduled events to the archive |

Categories: `messages`, `words`, `avg_length`, `days_active`, `streak`, `channels_used`, `replies_sent`, `mentions_received`, `voice_time`, `reactions_received`, `reactions_given`, `unique_reactors`, `emoji_variety`. The `period` parameter (`all` / `today` / `week` / `month`) only affects `messages` and `words` — other metrics are always all-time.

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
| `/unban` | `modbot.mod.unban` | `manage_guild` |
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
| `/ranks list` | `modbot.ranks.list` | `manage_guild` |
| `/ranks sync` | `modbot.ranks.sync` | `manage_guild` |
| `/archive enable` | `modbot.archive.enable` | `manage_guild` |
| `/archive disable` | `modbot.archive.disable` | `manage_guild` |
| `/archive list` | `modbot.archive.list` | `manage_guild` |
| `/archive dump` | `modbot.archive.dump` | `manage_guild` |
| `/archive refresh_events` | `modbot.archive.refresh_events` | `manage_guild` |

Permission lookups are cached per Discord ID for 60 seconds. Adding/removing rows in `rank_perms` or `playerdata.all_ranks` will take effect on the next cache refresh.

## Website integration

> For a full schema reference hand-off to your website dev, see [DATABASE.md](DATABASE.md). The summary below is the quick version. **Migrating from SiteLink?** See [SITELINK_MIGRATION.md](SITELINK_MIGRATION.md).



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

### Leaderboard tables (bot-owned, read directly from the site)

- `stats_daily (guild_id, user_id, day, messages, words, chars)` — daily buckets
- `stats_counters (guild_id, user_id, replies_sent, mentions_received, voice_seconds)` — rolling all-time counters
- `stats_channels_used (guild_id, user_id, channel_id)` — distinct channels a user has posted in
- `reaction_events (message_id, reactor_id, author_id, guild_id, emoji)` — per-reaction rows; PK prevents double-count and `on_raw_reaction_remove` deletes the row

Example queries the website can run:

```sql
-- Messages this week, top 10
SELECT user_id, SUM(messages) AS n
FROM stats_daily
WHERE guild_id = ? AND day >= CURRENT_DATE - INTERVAL 6 DAY
GROUP BY user_id ORDER BY n DESC LIMIT 10;

-- Reactions received
SELECT author_id, COUNT(*) AS n FROM reaction_events
WHERE guild_id = ? GROUP BY author_id ORDER BY n DESC LIMIT 10;

-- Voice hours all-time
SELECT user_id, voice_seconds / 3600.0 AS hours FROM stats_counters
WHERE guild_id = ? ORDER BY voice_seconds DESC LIMIT 10;
```

### Anti-spam baked in

- Per-user 3-second cooldown on the message counter (rapid-fire spam won't inflate)
- Word / char stats ignore messages shorter than 2 chars
- Deleted messages don't decrement stats (prevents "spam then delete" gaming)
- AFK voice channel is excluded from voice-time totals
- Reactions add / remove cleanly net to zero via the unique primary key
- Bots excluded from every counter on both author and reactor sides

## Rank sync behavior

- Source of truth: `playerdata.all_ranks` (comma-separated rank names).
- Per guild, wire each rank to a Discord role with `/ranks map <rank> <role>`.
- The bot only touches roles it assigned (tracked in `managed_member_roles`); manual roles are never removed.
- If a linked user has a rank that isn't mapped in a given guild, the bot posts a one-time notice to that guild's mod-log until the mapping is added.
- `/ranks unmap` also strips the previously-mapped role from every member who had it.

## Event logging

Every event below is posted as a Discord embed with the triggering actor (from the audit log where applicable). Every channel falls back to `mod_log_channel` if unset, so you can run the bot with just a single log channel if you want.

### Mod log (`mod_log_channel`)

Moderation and security activity.

- `/warn`, `/kick`, `/ban`, `/unban`, `/timeout` — case embed with case ID, target, moderator, reason, duration
- `/purge` — summary (channel, moderator, deleted count, target, reason)
- `/case edit` — old vs. new reason
- `/case revoke` — case marked inactive
- **Auto-escalation** — auto-kick / auto-ban triggered by warn thresholds (logged as a separate case, moderator = bot)
- **Native timeout** — when a mod uses Discord's built-in timeout UI instead of `/timeout`. Distinguishes started / cleared / extended, with moderator and reason from the audit log
- **Server settings** — name, icon, verification level, explicit-content filter, default notifications, AFK/system channel
- **Invites** — invite created (code, channel, inviter, expiry, max uses, temporary flag) and deleted (with uses-at-delete-time)
- **Webhooks** — created / updated / deleted (channel + actor)
- **Integrations** — bot added, integration added / updated / removed
- **AutoMod** — rule created / updated / deleted, and every rule trigger (rule ID, action, matched content, target member)

### Member log (`member_log_channel`)

Per-user activity.

- **Message deleted** — author, channel, original content (from cache), attachments, message ID. Logs even if not cached (`content not cached` placeholder).
- **Message edited** — author, channel, before, after, jump link. Uncached edits still log with `Before: not cached`.
- **Member joined** — user, account age, member count; flags accounts younger than `flag_new_account_days`
- **Member left / kicked / banned** — disambiguated via audit log (bot's own bans/kicks are suppressed here since the mod log already has them)
- **Pins** — message pinned / unpinned, with the actor and a jump link when the audit log exposes the message ID
- **Scheduled events** — created / updated / cancelled (name, start time, channel, creator)

### Role log (`role_log_channel`)

- **Member role changes** — tagged `[BOT]`, `[MEMBER]`, or `[SELF]` (reaction-role / self-assign). Respects `log_bot_role_changes` and `log_self_role_changes` toggles.
- **Role created** — color, hoist, mentionable, initial permissions
- **Role deleted** — name, ID, actor
- **Role updated** — name, permissions granted / revoked, color, hoist, mentionable

### Channel log (`channel_log_channel`)

- **Channel / category created** — type, parent category, actor
- **Channel / category deleted** — name, ID, actor
- **Channel / category updated** — any of: name, parent category, topic, slowmode, NSFW, bitrate, user limit
- **Permission overwrites** — per-target diffs showing `+allow`, `-allow`, `+deny`, `-deny` permission flag changes; added / removed targets shown with full allow/deny lists
- **Thread created / deleted** — parent channel, owner/actor
- **Thread updated** — name, archived, locked, slowmode, auto-archive duration

### Rank log (`rank_log_channel`)

- **Unmapped rank warning** — fires once per `(guild, rank)` pair per bot session when a linked member has a site rank without a Discord role mapping. Cleared when the rank gets mapped via `/ranks map`.

### Not logged (intentional)

- Position / drag-reorder events (too noisy)
- Embed-load "edits" (Discord resends MESSAGE_UPDATE for link previews — we skip when content is unchanged)
- Bulk message deletes (cache is cleaned up quietly; the triggering `/purge` is already logged)
- Voice channel joins / moves / leaves
- Nickname changes, avatar changes, global username changes

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
    │   ├── stats.py                # leaderboard collectors + /leaderboard
    │   ├── archive.py              # message/event archival (replaces SiteLink)
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
