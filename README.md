# Dogcraft Plugins

Custom plugins built for the **Dogcraft.net** Minecraft server network. Everything here is developed in-house to give our players a seamless multi-server experience — shared inventories, cross-server chat, a unified economy, and more.

Our network runs on **Paper 1.21+** backends behind a **Velocity** proxy, with **MySQL** for persistent storage and **Redis** for real-time cross-server sync.

---

## The Plugins

### Core Infrastructure

### [Dogcraft-Sync](Dogcraft-Sync.md)
Player data synchronization across servers. Inventories, stats, advancements, potion effects, maps, and player state all follow you when you switch servers. Includes admin tools for viewing and editing any player's inventory remotely.

### [Dogcraft-Economy](Dogcraft-Economy.md)
Shared economy with atomic balance operations via Redis Lua scripts. Provides a Vault integration so any Vault-compatible plugin works automatically. Full transaction ledger with audit support.

### [Dogcraft-NetworkSwitch](Dogcraft-NetworkSwitch.md)
Server switching across the network with per-server commands, a GUI selector, server capacity limits, backend health tracking, and automatic server identity discovery. Velocity owns all configuration and enforces transfers; Paper backends are thin clients.

### [Dogcraft-Linking](Dogcraft-Linking.md)
Account linking, whitelisting, and verification via a Velocity proxy plugin. Players link their Minecraft account through the website, verify their email, and optionally pass age verification or Patreon pledge requirements. Includes player activity tracking (ProxyData) and client type announcements.

### Protection & Moderation

### [Dogcraft-Claims](Dogcraft-Claims.md)
Land claiming and block protection inspired by GriefPrevention. Golden shovel claims, four-tier trust system, block locks with group management, subdivisions, claim flags with global defaults, and a claim block economy — all synced across servers.

### [Dogcraft-Logging](Dogcraft-Logging.md)
Block, container, chat, command, and kill logging with full rollback and restore capabilities. Features include selective rollbacks, two-person approval for large operations, xray investigation tools, trust/suspicion scoring, tiered data retention with cold storage, and a developer API.

### [Dogcraft-Vanish](Dogcraft-Vanish.md)
Staff vanish with full detection suppression — mobs, item pickups, pressure plates, sculk sensors, projectiles, and more are all blocked. Vanish state persists across server switches via Redis. Includes audit logging and plugin message broadcasting for integration with other plugins.

### [Dogcraft-AFK](Dogcraft-AFK.md)
Two-phase AFK detection (marked AFK, then kicked) with active anti-trick measures — detects minecart loops, bubble columns, water streams, piston pushers, and auto-clickers via timing deviation analysis. Freezes playtime stats while AFK, adds a LuckPerms suffix, and forwards status across the network.

### Player Features

### [Dogcraft-Homes](Dogcraft-Homes.md)
Home and teleportation plugin with inventory GUIs, cross-server teleporting, `/tpa`, `/back`, economy-integrated pricing with exponential scaling, discount tiers, refunds, home sharing, and a teleport warmup system with themed portal visual effects. Vanish-aware.

### [Dogcraft-Chat](Dogcraft-Chat.md)
Cross-server chat forwarding via Velocity with custom formatting, LuckPerms prefix support, private messaging, named group messaging, player ignore, staff chat, and socialspy. Uses Netty packet interception to preserve chat signing on the same server.

### [Dogcraft-Mail](Dogcraft-Mail.md)
In-game mail system running on the Velocity proxy. Players can send, receive, read, and manage mail with support for blocking, moderation spy mode, pagination, and Discord webhook notifications.

### [Dogcraft-Tab](Dogcraft-Tab.md)
Network-wide tab list that shows all players across every server with correct skins, LuckPerms ranks, configurable sorting, and vanish support. Uses NMS packet injection for remote player entries.

### [Dogcraft-Shops](Dogcraft-Shops.md)
Chest-based player shops. Place a chest, hold an item, and run a command to create a shop with a floating item display. Buyers right-click to purchase with a confirmation prompt. Includes sale notifications, low stock alerts, explosion/hopper protection, and sales history.

### [Dogcraft-Fallen](Dogcraft-Fallen.md)
PvP toggle system and death drops. When a player dies, their items are stored inside a mannequin at the death location with a countdown timer instead of scattering on the ground. PvP is opt-in with combat tagging, respawn protection, and new player protection.

### [Dogcraft-PlayerBuffs](Dogcraft-PlayerBuffs.md)
Server-wide buff system where players can purchase temporary potion effects that apply to everyone on the server. Active buffs sync across the network using Redis TTL keys. Players can opt out of receiving buffs.

### [Dogcraft-PlayerScoreboards](Dogcraft-PlayerScoreboards.md)
Displays player statistics on a temporary sidebar scoreboard and hoverable chat message. View your own or another player's stats including playtime, deaths, distance traveled, economy balance, and more. Right-click a player to see their stats.

### [Dogcraft-MobHeads](Dogcraft-MobHeads.md)
Custom mob head drops on kill with configurable drop rates, Looting enchantment bonuses, and 80+ entity types with variant-specific heads (colored sheep, cat breeds, villager professions, powered creepers, and more). Supports MySQL and Redis for cross-server stackable items.

### [ArmorstandArms](ArmorstandArms.md)
Lightweight armor stand customization. Right-click with a stick to add arms, shears to remove them, a stone slab for the base plate, flint to take it off, or an iron nugget to lock the armor stand so only the owner (or staff) can modify it. Paper and Folia compatible.

---

### Integrations

### [Dogcraft-Discord](Dogcraft-Discord.md)
A Python + discord.py moderation bot that ties our Discord server to our Minecraft network. Handles full moderation (warn/kick/ban/timeout/lockdown), logging (messages, members, roles, channels, invites, AutoMod), message + scheduled event archival for the website, activity leaderboards, and automatic Discord role sync based on in-game rank.

---

## Shared Infrastructure

All plugins share a common backend stack:

| Component | Role |
|-----------|------|
| **MySQL / MariaDB** | Persistent storage for all plugin data |
| **Redis** | Real-time cross-server sync, distributed locking, pub/sub messaging |
| **Velocity** | Proxy layer for cross-server teleporting, chat forwarding, and tab list |
| **LuckPerms** | Permissions and prefix/suffix display across the network |
| **Vault** | Economy API bridge used by third-party plugins |

---

## Permissions by Rank

A consolidated list of every permission across all plugins, grouped by the rank tier it's intended for. Tiers are cumulative — **Staff** includes everything **Player** has, **Senior Staff** includes everything **Staff** has, etc.

### Player

Granted to everyone by default. These are the core player-facing features.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraft.linking.linked` | Linking | Required to join backend servers (granted via linked group on account link) |
| `dogcraft.linking.patreon` | Linking | Access to Patreon-gated servers |
| `dogcraftclaims.claim` | Claims | Create and manage own claims |
| `dogcraftclaims.trust` | Claims | Use trust commands inside claims |
| `dogcraftclaims.lock` | Claims | Place and manage block locks |
| `dogcraftclaims.claimblocks.buy` | Claims | Purchase claim blocks with currency |
| `dogcrafthome.teleport.bypass` | Homes | Skip teleport warmup (granted to donors/op) |
| `dogcrafthomes.discount.Tier1`–`Tier4` | Homes | Home pricing discounts (5%/10%/25%/50%, donor perks) |
| `dogcraftshops.create` | Shops | Create chest shops |
| `dogcraftshops.use` | Shops | Buy from chest shops |
| `dogcraftfallen.pvp` | Fallen | Use `/pvp` toggle |
| `dogcraftfallen.pvp.status.other` | Fallen | Check other players' PvP status |
| `dogcraftfallen.deathdrops` | Fallen | Use `/fallen` to view own death drops |
| `serverbuff.command` | PlayerBuffs | Open the buff shop and purchase buffs |
| `networkswitch.server` | NetworkSwitch | Use `/servers` and per-server commands |
| `armorstandarms.use` | ArmorstandArms | Modify armor stands |
| `playerstats.name.random` | PlayerScoreboards | Cosmetic — randomized colored name on stats (can be given as a perk) |

### Staff (Moderator)

Basic moderation: inspection, lookups, staff chat, alerts.

| Permission | Plugin | Description |
|---|---|---|
| `dogcrafteconomy.balance.other` | Economy | Check other players' balances |
| `dogcraftclaims.admin.ignoreclaims.container` | Claims | Bypass Access + Container checks (open any chest) |
| `dogcraftclaims.admin.delete` | Claims | Delete any player's claims |
| `dogcraftclaims.lock.locksmith` | Claims | Manage/inspect any player's locks |
| `dogcraftclaims.lock.ghost` | Claims | Bypass all locks |
| `dogcraftclaims.notify.proximity` | Claims | Receive proximity alerts on claim creation |
| `dogcraftclaims.bypass.pvp` | Claims | Ignore PvP claim flags |
| `dogcraft.logging.inspect` | Logging | Toggle block inspector, view container snapshots |
| `dogcraft.logging.lookup` | Logging | Search logs with `/dcl lookup` and `/dcl activity` |
| `dogcraft.logging.blockping` | Logging | Use `/dcl blockping` for xray investigation |
| `dogcraft.logging.alerts` | Logging | Receive suspicion and cross-server alerts |
| `dogcraft.logging.trust` | Logging | View player trust tiers and scores |
| `dogcraft.logging.signnotify` | Logging | Receive sign placement notifications |
| `dogcraft.vanish` | Vanish | Toggle own vanish state |
| `dogcraft.vanish.see` | Vanish | See vanished players in-world and receive notifications |
| `dogcraft.staffchat` | Chat | Access to staff chat (`/sc`) |
| `dogcraft.socialspy` | Chat | See private and group messages between players |
| `dogcraft.socialspy.exempt` | Chat | Exempt from being seen by socialspy |
| `dogcraftmail.command.mail.spy` | Mail | Read any player's mail; notified when mail is sent |
| `dogcrafttab.vanish.see` | Tab | See vanished players in tab list with `[V]` tag |
| `dclink.linkstatus.other` | Linking | View other players' link status |
| `dclink.join.hide` | Linking | Hide own join message |
| `dclink.join.seehidden` | Linking | See hidden join messages |
| `dogcraft.clienttype.announce` | Linking | Receive client type announcements on join |
| `dogcraft.clienttype.bypass` | Linking | Hide own client type from announcements |
| `dogcraftsync.invsee` | Sync | View any player's inventory (read-only) |
| `dogcraftsync.enderchest` | Sync | View any player's enderchest (read-only) |
| `afk.notify` | AFK | Receive AFK + auto-clicker + trick notifications |
| `afk.exempt` | AFK | Exempt from AFK detection and kick |
| `networkswitch.staff` | NetworkSwitch | Use reserved staff capacity slots on full servers |
| `PlayerScoreboard.staffMember` | PlayerScoreboards | Show Staff Member badge on stats scoreboard |
| `MobHead.AlwaysDrop` | MobHeads | Heads always drop when killing mobs (donor/staff perk) |
| `modbot.mod.warn` | Discord | `/warn` — log a warning, DM user, may trigger auto-escalation |
| `modbot.mod.kick` | Discord | `/kick` — kick a Discord member |
| `modbot.mod.timeout` | Discord | `/timeout` — time out a Discord member (up to 28 days) |
| `modbot.mod.purge` | Discord | `/purge` — delete up to 200 recent messages from a user |
| `modbot.mod.userinfo` | Discord | `/userinfo` — view account age, roles, warns, MC link |
| `modbot.mod.history` | Discord | `/history` — view infractions, notes, join/leave history |
| `modbot.mod.case.view` | Discord | `/case view` — view a single moderation case |
| `modbot.mod.lockdown` | Discord | `/lockdown` — lock a single channel |
| `modbot.notes.add` | Discord | `/note add` — add a staff-only note on a member |
| `modbot.notes.list` | Discord | `/note list` — view notes on a member |
| `modbot.notes.remove` | Discord | `/note remove` — delete a note |
| `modbot.ranks.list` | Discord | `/ranks list` — view rank → role mappings |
| `modbot.ranks.sync` | Discord | `/ranks sync` — trigger immediate rank reconciliation |

### Senior Staff (Senior Mod)

Destructive and sensitive actions: rollbacks, restores, force-vanish, admin economy actions that aren't permanent.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraftclaims.admin.ignoreclaims.owner` | Claims | Full owner access to all claims (bypass all protection) |
| `dogcraftclaims.admin.adjust` | Claims | Adjust any player's claim block balance |
| `dogcraftclaims.claim.fly` | Claims | Allowed to claim while flying |
| `dogcraftclaims.bypass.build` | Claims | Bypass build protection |
| `dogcraft.logging.rollback` | Logging | Run `/dcl rollback` and `/dcl confirm` |
| `dogcraft.logging.restore` | Logging | Run `/dcl restore` |
| `dogcraft.logging.approve` | Logging | Approve/deny large rollbacks (two-person mode) |
| `dogcraft.vanish.others` | Vanish | Force vanish/unvanish other players |
| `dogcrafteconomy.admin.audit` | Economy | Audit a player's transaction history |
| `serverbuff.toggleother` | PlayerBuffs | Toggle buff reception for other players |
| `dogcraftsync.invsee.edit` | Sync | Edit any player's inventory remotely |
| `dogcraftsync.enderchest.edit` | Sync | Edit any player's enderchest remotely |
| `dogcraftsync.save` | Sync | Force-save a player's data |
| `dogcraftsync.load` | Sync | Force-load a player's data from the database |
| `dogcraftsync.unfreeze` | Sync | Unfreeze a stuck player |
| `dogcraftsync.status` | Sync | View sync lock/freeze status |
| `modbot.mod.ban` | Discord | `/ban` — ban a Discord user |
| `modbot.mod.unban` | Discord | `/unban` — lift a ban |
| `modbot.mod.tempban` | Discord | `/tempban` — ban with auto-unban after duration |
| `modbot.mod.lockdown_server` | Discord | `/lockdown_server` — lock every text channel at once (raids) |
| `modbot.mod.bans.export` | Discord | `/bans export` — JSON export of the guild ban list |
| `modbot.mod.bans.import` | Discord | `/bans import` — bulk-import a ban list from JSON |
| `modbot.mod.case.edit` | Discord | `/case edit` — update a case's reason |
| `modbot.mod.case.revoke` | Discord | `/case revoke` — mark a case inactive (removes from warn tally) |

### Admin

Full control: config reloads, economy adjustments, purging data, bypassing all systems.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraftclaims.admin` | Claims | Parent permission — all claim admin commands |
| `dogcraftclaims.admin.claim` | Claims | Create admin claims |
| `dogcrafteconomy.admin` | Economy | Access to `/economy` command |
| `dogcrafteconomy.admin.all` | Economy | All economy admin sub-permissions |
| `dogcrafteconomy.admin.add` | Economy | Add to a player's balance |
| `dogcrafteconomy.admin.remove` | Economy | Remove from a player's balance |
| `dogcrafteconomy.admin.set` | Economy | Set a player's balance |
| `dogcrafthomes.admin` | Homes | Parent — all home admin sub-permissions |
| `dogcrafthomes.admin.info` | Homes | View, list, and search any player's homes |
| `dogcrafthomes.admin.delete` | Homes | Delete any home by ID |
| `dogcrafthomes.admin.tp` | Homes | Teleport to any home (skips warmup and cost) |
| `dogcraft.logging.*` | Logging | All logging permissions |
| `dogcraft.logging.purge` | Logging | Purge old data (moves to cold storage or deletes) |
| `dogcraft.logging.admin` | Logging | Stats, reload, audit log |
| `dogcraftshops.admin` | Shops | `/shopadmin` — reload, force-remove shops, inspect records |
| `dogcraftfallen.admin` | Fallen | Admin `/pvp` and `/fallen` subcommands |
| `serverBuffs.admin` | PlayerBuffs | Spawn the buff NPC |
| `networkswitch.admin` | NetworkSwitch | `/ns` and `/nslimit` — player transfers, capacity overrides |
| `networkswitch.bypass` | NetworkSwitch | Bypass all server capacity limits |
| `networkswitch.reload` | NetworkSwitch | Reload backend config from Redis |
| `dogcrafttab.reload` | Tab | Reload tab config and push to all servers |
| `dogcraft.proxydata.reloadrank` | Linking | Refresh cached rank permissions on the proxy |
| `dogcraftsync.*` | Sync | All sync permissions |
| `dogcraftsync.reload` | Sync | Reload plugin config |
| `dogcraftsync.debug` | Sync | Toggle debug logging |
| `MobHead.reload` | MobHeads | Reload all head config and rebuild cache |
| `MobHead.spawn` | MobHeads | `/mhspawn` — spawn heads at your location |
| `PlayerScoreboard.reload` | PlayerScoreboards | Reload the stats config |
| `armorstandarms.bypass` | ArmorstandArms | Modify or break locked armor stands owned by others |
| `modbot.config.view` | Discord | `/config view` — view bot settings for the guild |
| `modbot.config.logs` | Discord | `/config set_log` — configure log channels |
| `modbot.config.dm` | Discord | `/config toggle_dm` — toggle DMing users on infractions |
| `modbot.config.thresholds` | Discord | `/config set_threshold` — set warn → auto-kick/ban thresholds |
| `modbot.config.account_flag` | Discord | `/config set_account_flag_days` — flag young accounts on join |
| `modbot.config.cache_days` | Discord | `/config set_cache_days` — message cache retention |
| `modbot.ranks.map` | Discord | `/ranks map` — map a site rank to a Discord role |
| `modbot.ranks.unmap` | Discord | `/ranks unmap` — remove a mapping and strip the role |
| `modbot.archive.enable` | Discord | `/archive enable` — start archiving a channel to the website |
| `modbot.archive.disable` | Discord | `/archive disable` — stop archiving a channel |
| `modbot.archive.list` | Discord | `/archive list` — show archive-enabled channels |
| `modbot.archive.dump` | Discord | `/archive dump` — backfill recent history |
| `modbot.archive.refresh_events` | Discord | `/archive refresh_events` — re-sync all scheduled events |

> **Note on `modbot.*`:** The Discord bot reads permissions from the website's `rank_perms` table rather than LuckPerms. Its auth is driven by the linked user's Minecraft ranks — so giving a MC rank `modbot.mod.*` automatically grants that set to any Discord member linked to a player with that rank.

---

## Links

- **Server:** dogcraft.net
