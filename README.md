# Dogcraft Plugins

Custom plugins built for the **Dogcraft.net** Minecraft server network. Everything here is developed in-house to give our players a seamless multi-server experience — shared inventories, cross-server chat, a unified economy, and more.

Our network runs on **Paper 1.21+** backends behind a **Velocity** proxy, with **MySQL** for persistent storage and **Redis** for real-time cross-server sync.

---

## The Plugins

### Core Infrastructure

### [Dogcraft-Sync](Dogcraft-Sync.md)
Player data synchronization across servers. Inventories, stats, advancements, potion effects, maps, and player state all follow you when you switch servers. Includes admin tools for viewing and editing any player's inventory remotely, plus a public API for plugins that mutate inventories (so they can flush state before crediting on the other side and avoid dupe windows).

### [Dogcraft-Economy](Dogcraft-Economy.md)
Shared economy with atomic balance operations via Redis Lua scripts. Provides a Vault integration so any Vault-compatible plugin works automatically. Full transaction ledger with audit support and optional `server_id.conf` integration for shared server identity across plugins.

### [Dogcraft-NetworkSwitch](Dogcraft-NetworkSwitch.md)
Server switching across the network with per-server commands, a GUI selector, server capacity limits, backend health tracking, and automatic server identity discovery. Velocity owns all configuration and enforces transfers; Paper backends are thin clients. Writes a `server_id.conf` file every other plugin can read for unified server identity.

### [Dogcraft-Linking](Dogcraft-Linking.md)
Account linking, whitelisting, and verification via a Velocity proxy plugin. Players link their Minecraft account through the website, verify their email, and optionally pass age verification or Patreon pledge requirements. Includes player activity tracking (ProxyData) and client type announcements.

### Protection & Moderation

### [Dogcraft-Claims](Dogcraft-Claims.md)
Land claiming and block protection inspired by GriefPrevention. Single-stick tool (right-click inspects, sneak shows borders, sneak + click creates/resizes), four-tier trust system, block locks with named groups and access/container categorization, subdivisions, **claim rentals** with auto-renewal and prorated refunds, claim flags with global defaults, per-player flag preferences, tamed mob protection (anywhere on the server), `/transferpet` and `/transferclaim`, and a claim block economy — all synced across servers via Redis.

### [Dogcraft-Logging](Dogcraft-Logging.md)
Block, container, chat, command, kill, drop/pickup, beacon, and interaction logging with full rollback and restore capabilities. Features include selective rollbacks, two-person approval for large operations, xray investigation tools, trust/suspicion scoring, container break-snapshots so chest-break thefts are recoverable, multi-material filters (`i:iron,gold,diamond`), cross-server scope (`s:#all`), tiered data retention with cold storage, and a developer API.

### [Dogcraft-Vanish](Dogcraft-Vanish.md)
Staff vanish with full detection suppression — mobs, item pickups, pressure plates, sculk sensors, projectiles, and more are all blocked. Vanish state persists across server switches via Redis. Includes audit logging and plugin message broadcasting for integration with other plugins.

### [Dogcraft-AFK](Dogcraft-AFK.md)
Two-phase AFK detection (marked AFK, then kicked) with active anti-trick measures — detects minecart loops, bubble columns, water streams, piston pushers, and auto-clickers via timing deviation analysis. Freezes playtime stats while AFK, adds a LuckPerms suffix, and forwards status across the network.

### Player Features

### [Dogcraft-Homes](Dogcraft-Homes.md)
Home and full teleportation suite: cross-server homes, `/tpa`/`/tpahere`, `/back` (tracks death and external-plugin teleports), `/spawn`, `/rtp` with safe-location scanning, admin warps with optional per-warp permissions, and admin `/tp`/`/tppos`/`/tphere`. Five color-themed portals, `~now` instant-teleport flag for bypass holders, per-player visual preferences (`/homeprefs` for motion sickness opt-out), Asgard-beam donor effects, configurable pricing curves (CONSTANT / LINEAR / EXPONENTIAL / POLYNOMIAL), discount tiers, refunds, vanish-aware effects, and DogcraftClaims integration so `/sethome` requires ACCESS trust.

### [Dogcraft-Chat](Dogcraft-Chat.md)
Cross-server chat forwarding via Velocity with custom formatting, LuckPerms prefix support, private messaging, named group messaging, player ignore (rendered as `[Ignored]` with hover), staff chat, and socialspy. Adds **per-tag MiniMessage chat permissions** (gradient/hover/click for trusted ranks), **AI toxicity detection** (Detoxify ONNX model with optional Discord webhook), **scheduled rotating broadcasts**, and an optional **WebSocket bridge** to the desktop chat broker. Uses Netty packet interception to preserve chat signing on the same server.

### [Dogcraft-Mail](Dogcraft-Mail.md)
In-game mail system running on the Velocity proxy. Players can send, receive, read, and manage mail with support for blocking, moderation spy mode, pagination, and Discord webhook notifications.

### [Dogcraft-Tab](Dogcraft-Tab.md)
Network-wide tab list that shows all players across every server with correct skins, LuckPerms ranks, configurable sorting, and vanish support. Uses NMS packet injection for remote player entries.

### [Dogcraft-Shops](Dogcraft-Shops.md)
Chest-based player shops with floating item displays. Place a chest, hold an item, run `/shop create`, and you're live. Supports bundle quantities, member roles (Manager/Refiller), discount codes, sales history, low stock alerts, `/shop find` search and `/shop teleport` navigation, cross-server `/shop restock` plans, server-owned shops with unlimited stock, ghost-shop auto-cleanup, and explosion/hopper protection.

### [Dogcraft-Fallen](Dogcraft-Fallen.md)
PvP toggle system and death drops. When a player dies, their items are stored inside a mannequin at the death location with a countdown timer instead of scattering on the ground. PvP is opt-in with combat tagging, respawn protection, and new player protection.

### [Dogcraft-PlayerBuffs](Dogcraft-PlayerBuffs.md)
Server-wide buff system where players can purchase temporary potion effects that apply to everyone on the server. Active buffs sync across the network using Redis TTL keys. Players can opt out of receiving buffs.

### [Dogcraft-PlayerScoreboards](Dogcraft-PlayerScoreboards.md)
Displays player statistics on a temporary sidebar scoreboard and hoverable chat message. View your own or another player's stats including playtime, deaths, distance traveled, economy balance, and more. Right-click a player to see their stats.

### [Dogcraft-MobHeads](Dogcraft-MobHeads.md)
Custom mob head drops on kill with configurable drop rates, Looting enchantment bonuses, and 80+ entity types with variant-specific heads (colored sheep, cat breeds, villager professions, powered creepers, biome-specific cows/pigs/chickens, and more). Supports MySQL and Redis for cross-server stackable items.

### [Dogcraft-MobCapture](Dogcraft-MobCapture.md)
Tier-based capture eggs (copper / iron / gold / diamond / emerald / netherite) for trapping and relocating mobs. Higher tiers preserve full NBT — captured villagers keep their trades, captured pets keep their name, color, and ownership. Soft-integrates with DogcraftEconomy (per-tier activation cost) and DogcraftClaims (BUILD trust required to capture/release inside a claim). Hard-blocks capturing other players' pets even with bypass perms.

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
| **`server_id.conf`** | Shared server-identity file written by NetworkSwitch and consumed by Sync, Economy, Claims, AFK, and others |

---

## Permissions by Group

The Dogcraft network uses LuckPerms with the following group hierarchy:

```
default (unlinked)
└── cyberdog (linked player)
    ├── pioneer → vip → patreon → ironpatreon → goldpatreon → emeraldpatreon → diamondpatreon
    ├── server-staff track:    staff → chatmod → mod → headmod
    ├── discord-staff track:   staff → dismod → discordheadmod
    └── admin (inherits both headmod and discordheadmod)
```

Each group below lists **only the permissions it explicitly adds** — inherited permissions from parent groups are not repeated. Every group inherits `cyberdog` (and so the base player permissions) at the bottom of the chain.

### `cyberdog` — linked player

The base group every linked player joins. Granted on successful account linking via Dogcraft-Linking.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraft.linking.linked` | Linking | Required to join backend servers |
| `dogcraft.chat.web.connect` | Chat | Connect via the desktop chat broker |
| `dogcraftclaims.claim` | Claims | Create and manage own claims |
| `dogcraftclaims.trust` | Claims | Use trust commands inside claims |
| `dogcraftclaims.lock` | Claims | Place and manage block locks |
| `dogcraftclaims.claimblocks.buy` | Claims | Purchase claim blocks with currency |
| `dogcraftshops.create` | Shops | Create chest shops |
| `dogcraftshops.use` | Shops | Buy from chest shops |
| `dogcraftfallen.pvp` | Fallen | Use `/pvp` toggle |
| `dogcraftfallen.deathdrops` | Fallen | View own death drops via `/fallen` |
| `networkswitch.server` | NetworkSwitch | Use `/servers` and per-server commands |
| `armorstandarms.use` | ArmorstandArms | Modify armor stands |

> **Plugin defaults applied to all linked players:** `dogcraftclaims.tame`, `dogcrafthomes.back`/`spawn`/`rtp`/`warp.teleport`/`homeprefs`, `captureeggs.craft`/`activate`/`capture`/`release`, `dogcraftfallen.pvp.status.other`. These default to `true` in their respective plugins, so they aren't explicitly listed in `cyberdog`.

### Donor groups (`pioneer` → `vip` → `patreon` → `ironpatreon` → `goldpatreon` → `emeraldpatreon` → `diamondpatreon`)

Donor and supporter perks. Each tier inherits the previous one.

| Group | Permission | Plugin | Description |
|---|---|---|---|
| `pioneer` | `playerstats.name.random` | PlayerScoreboards | Random colored name on stats scoreboard |
| `patreon` | `serverbuff.command` | PlayerBuffs | Open the buff shop and purchase buffs |
| `ironpatreon` | `MobHead.HeadRate.Tier1` | MobHeads | +5% mob head drop rate |
| `ironpatreon` | `dogcrafthomes.discount.Tier1` | Homes | 5% discount on home pricing |
| `goldpatreon` | `MobHead.HeadRate.Tier2` | MobHeads | +10% mob head drop rate |
| `goldpatreon` | `dogcrafthomes.discount.Tier2` | Homes | 10% discount on home pricing |
| `emeraldpatreon` | `MobHead.HeadRate.Tier3` | MobHeads | +25% mob head drop rate |
| `emeraldpatreon` | `dogcrafthomes.discount.Tier3` | Homes | 25% discount on home pricing |
| `diamondpatreon` | `MobHead.HeadRate.Tier4` | MobHeads | +50% mob head drop rate |
| `diamondpatreon` | `dogcrafthomes.discount.Tier4` | Homes | 50% discount on home pricing |

### `staff` — base staff

The shared parent for all server and Discord staff. Members aren't typically given `staff` directly — they're assigned `chatmod`/`mod`/`headmod`/`dismod`/`discordheadmod`, which all inherit `staff`.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraft.staffchat` | Chat | Access to staff chat (`/sc`) |
| `dclink.linkstatus.other` | Linking | View other players' link status |
| `captureeggs.bypass.cost` | MobCapture | Skip economy cost on capture-egg activation |
| `playerscoreboard.staffmember` | PlayerScoreboards | "Staff Member" badge on stats scoreboard |

### `chatmod` — chat moderation

First step on the server-staff track. Inherits `staff`.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraft.socialspy` | Chat | See private and group messages between players |
| `dogcraft.ignore.bypass` | Chat | Messages always shown even if recipient ignores you |
| `dogcraft.moderation.alerts` | Chat | Receive in-game toxicity alerts from the AI moderator |
| `dogcraft.clienttype.announce` | Linking | Receive client type announcements on join |
| `dogcraft.chat.format.color` | Chat | Use `<red>`, `<#ff0000>` colors in chat |
| `dogcraft.chat.format.decoration` | Chat | Use `<bold>`, `<italic>`, etc. |
| `dogcraft.chat.format.gradient` | Chat | Use `<gradient>` and `<rainbow>` |
| `dogcraft.chat.format.click` | Chat | Use safe `<click>` actions |
| `dogcraft.chat.format.url` | Chat | Use `<click:open_url>` for clickable links |
| `dogcraftmail.command.mail.spy` | Mail | Read any player's mail; notified on send |
| `networkswitch.staff` | NetworkSwitch | Use reserved staff capacity slots on full servers |

### `mod` — server moderation

Server moderator. Inherits `chatmod`.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraft.vanish` | Vanish | Toggle own vanish state |
| `dogcraft.logging.inspect` | Logging | Toggle block inspector, view container snapshots |
| `dogcraft.logging.lookup` | Logging | Search logs with `/dcl lookup` and `/dcl activity` |
| `dogcraft.logging.blockping` | Logging | Use `/dcl blockping` for xray investigation |
| `dogcraft.logging.alerts` | Logging | Receive suspicion and cross-server alerts |
| `dogcraft.logging.trust` | Logging | View player trust tiers and scores |
| `dogcraft.logging.signnotify` | Logging | Receive sign placement notifications |
| `dogcraft.logging.rollback` | Logging | Run `/dcl rollback` and `/dcl confirm` |
| `dogcraft.logging.restore` | Logging | Run `/dcl restore` |
| `dogcraft.logging.approve` | Logging | Approve/deny large rollbacks (two-person mode) |
| `dogcraftclaims.admin.ignoreclaims.container` | Claims | Bypass Access + Container checks (open any chest) |
| `dogcraftclaims.admin.entities` | Claims | `/dcc entities` — read-only entity overview for lag triage |
| `dogcraftclaims.lock.locksmith` | Claims | Manage/inspect any player's locks |
| `dogcraftclaims.lock.ghost` | Claims | Bypass all locks |
| `dogcraftclaims.notify.proximity` | Claims | Receive proximity alerts on claim creation |
| `dogcrafthomes.admin.tp` | Homes | Teleport to any home, plus `/tp`/`/tppos`/`/tphere`/`/tpahereall` |
| `dogcrafthomes.vanish.see` | Homes | See vanished players in TPA tab completion |
| `dogcraftsync.invsee` | Sync | View any player's inventory (read-only) |
| `dogcraftsync.enderchest` | Sync | View any player's enderchest (read-only) |
| `afk.notify` | AFK | Receive AFK + auto-clicker + trick notifications |

### `headmod` — head moderator

Senior server staff. Inherits `mod`.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraft.vanish.others` | Vanish | Force vanish/unvanish other players |
| `dogcraft.vanish.see` | Vanish | See vanished players in-world (already on the chatmod-level wildcard but explicit here) |
| `dogcraft.broadcast` | Chat | Send manual `/broadcast` messages to the network |
| `dogcraft.chat.format.hover` | Chat | Use `<hover:show_text>` (added on top of chatmod's set) |
| `dogcraftclaims.admin` | Claims | Parent permission — all admin commands and admin flags |
| `dogcraftclaims.admin.claim` | Claims | Create admin claims |
| `dogcraftclaims.admin.delete` | Claims | Delete any player's claims |
| `dogcraftclaims.admin.ignoreclaims.owner` | Claims | Full owner access to all claims (also overrides tamed-pet protection) |
| `dogcraftclaims.admin.lastseen` | Claims | See claim owner's last play time and last server in `/claiminfo` |
| `dogcraftclaims.admin.rental` | Claims | Toggle rental auto-reset on rented subdivisions |
| `dogcraftclaims.bypass.build` | Claims | Bypass `require-claim` mode and `DENY_FLIGHT` claim flag |
| `dogcraftclaims.bypass.pvp` | Claims | Ignore PvP claim flags |
| `dogcraftclaims.claim.fly` | Claims | Allowed to claim while flying |
| `dogcrafteconomy.balance.other` | Economy | Check other players' balances |
| `dogcrafthomes.admin.delete` | Homes | Delete any home by ID |
| `dogcrafthomes.admin.info` | Homes | View, list, and search any player's homes |
| `dogcraftshops.admin` | Shops | `/shopadmin` — reload, force-remove, inspect, plus per-shop overrides |
| `dogcraftsync.invsee.edit` | Sync | Edit any player's inventory remotely |
| `dogcraftsync.enderchest.edit` | Sync | Edit any player's enderchest remotely |
| `dogcraftsync.status` | Sync | View sync lock/freeze status |
| `dogcraftsync.unfreeze` | Sync | Unfreeze a stuck player |
| `dogcrafttab.vanish.see` | Tab | See vanished players in tab list with `[V]` tag |
| `serverbuff.toggleother` | PlayerBuffs | Toggle buff reception for other players |
| `dclink.join.hide` | Linking | Hide own join message |
| `dclink.join.seehidden` | Linking | See hidden join messages |
| `armorstandarms.bypass` | ArmorstandArms | Modify or break locked armor stands owned by others |

### `dismod` — discord moderation

First step on the discord-staff track. Inherits `staff`. These permissions are granted via the website's `rank_perms` table, not LuckPerms directly — see the note below.

| Permission | Plugin | Description |
|---|---|---|
| `modbot.mod.warn` | Discord | `/warn` — log a warning, DM user, may trigger auto-escalation |
| `modbot.mod.kick` | Discord | `/kick` — kick a Discord member |
| `modbot.mod.ban` | Discord | `/ban` — ban a Discord user |
| `modbot.mod.tempban` | Discord | `/tempban` — auto-unban after duration |
| `modbot.mod.timeout` | Discord | `/timeout` — time out a Discord member (up to 28 days) |
| `modbot.mod.purge` | Discord | `/purge` — delete up to 200 recent messages from a user |
| `modbot.mod.userinfo` | Discord | `/userinfo` — account age, roles, warns, MC link |
| `modbot.mod.history` | Discord | `/history` — infractions, notes, join/leave history |
| `modbot.mod.case.view` | Discord | `/case view` — view a single moderation case |
| `modbot.mod.lockdown` | Discord | `/lockdown` — lock a single channel |
| `modbot.notes.add` | Discord | `/note add` — staff-only note on a member |
| `modbot.notes.list` | Discord | `/note list` — view notes |
| `modbot.notes.remove` | Discord | `/note remove` — delete a note |

### `discordheadmod` — head discord mod

Senior Discord staff. Inherits `dismod`.

| Permission | Plugin | Description |
|---|---|---|
| `modbot.mod.unban` | Discord | `/unban` — lift a ban |
| `modbot.mod.lockdown_server` | Discord | `/lockdown_server` — lock every text channel at once (raids) |
| `modbot.mod.bans.export` | Discord | `/bans export` — JSON export of the guild ban list |
| `modbot.mod.bans.import` | Discord | `/bans import` — bulk-import a ban list |
| `modbot.mod.case.edit` | Discord | `/case edit` — update a case's reason |
| `modbot.mod.case.revoke` | Discord | `/case revoke` — mark a case inactive |
| `modbot.config.view` | Discord | `/config view` — view bot settings for the guild |
| `modbot.config.logs` | Discord | `/config set_log` — configure log channels |
| `modbot.config.dm` | Discord | `/config toggle_dm` — toggle DMing users on infractions |
| `modbot.config.thresholds` | Discord | `/config set_threshold` — auto-kick/ban thresholds |
| `modbot.config.account_flag` | Discord | `/config set_account_flag_days` — flag young accounts |
| `modbot.config.cache_days` | Discord | `/config set_cache_days` — message cache retention |
| `modbot.ranks.map` | Discord | `/ranks map` — map a site rank to a Discord role |
| `modbot.ranks.unmap` | Discord | `/ranks unmap` — remove a mapping and strip the role |
| `modbot.archive.enable` | Discord | `/archive enable` — start archiving a channel |
| `modbot.archive.disable` | Discord | `/archive disable` — stop archiving |
| `modbot.archive.list` | Discord | `/archive list` — show archive-enabled channels |
| `modbot.archive.dump` | Discord | `/archive dump` — backfill recent history |
| `modbot.archive.refresh_events` | Discord | `/archive refresh_events` — re-sync scheduled events |

### `admin` — full control

Top tier. Inherits both `headmod` and `discordheadmod`.

| Permission | Plugin | Description |
|---|---|---|
| `dogcraft.*` | All | Wildcard for every `dogcraft.*` permission |
| `dogcraft.chat.format.*` | Chat | All MiniMessage chat formatting tags |
| `dogcraft.logging.*` | Logging | All logging permissions including `purge` and `admin` |
| `dogcraftsync.*` | Sync | All sync permissions including `reload` and `debug` |
| `dogcraft.broadcast.reload` | Chat | Reload `broadcasts.properties` rotating announcements |
| `dogcraft.clienttype.bypass` | Linking | Hide own client type from announcements |
| `dogcraft.proxydata.reloadrank` | Linking | Refresh cached rank permissions on the proxy |
| `dogcraft.socialspy.exempt` | Chat | Exempt from being seen by socialspy |
| `dogcraftclaims.admin.adjust` | Claims | Adjust any player's claim block balance |
| `dogcrafteconomy.admin` | Economy | Access to `/economy` command |
| `dogcrafteconomy.admin.add`/`.remove`/`.set`/`.all` | Economy | All balance manipulation perms |
| `dogcraftfallen.admin` | Fallen | Admin `/pvp` and `/fallen` subcommands |
| `dogcrafthome.teleport.bypass` | Homes | Use `~now` flag to skip warmup/cooldown on any teleport |
| `dogcrafthomes.admin` | Homes | Parent — all home admin sub-permissions |
| `dogcrafthomes.teleport.asgard.#00ffff` | Homes | Cyan Asgard beam effect |
| `dogcrafttab.reload` | Tab | Reload tab config and push to all servers |
| `mobhead.alwaysdrop` | MobHeads | Heads always drop on mob kills |
| `mobhead.reload` | MobHeads | Reload all head config and rebuild cache |
| `mobhead.spawn` | MobHeads | `/mhspawn` — spawn heads at your location |
| `networkswitch.admin` | NetworkSwitch | `/ns` and `/nslimit` — player transfers, capacity overrides |
| `networkswitch.bypass` | NetworkSwitch | Bypass all server capacity limits |
| `networkswitch.reload` | NetworkSwitch | Reload backend config from Redis |
| `playerscoreboard.reload` | PlayerScoreboards | Reload the stats config |
| `serverbuffs.admin` | PlayerBuffs | Spawn the buff NPC |
| `afk.exempt` | AFK | Exempt from AFK detection and kick |

> **Plugin-default-only permissions:** A few admin-tier perms aren't explicitly assigned to any group in LuckPerms — they fall back to their `default: op` plugin defaults, so anyone with op (typically just admins) gets them automatically: `captureeggs.admin`, `captureeggs.bypass.tier`, `dogcraftclaims.admin.reload`, `dogcrafthomes.warp.set`/`.delete`, `dogcraftshops.admin.create`/`.transferserver`/`.unlimited`, `dogcrafteconomy.admin.audit`, `dogcraftsync.save`/`.load`. If you want a non-op rank to use these, add them to the appropriate group.

> **Note on `modbot.*`:** The Discord bot reads permissions from the website's `rank_perms` table, not directly from LuckPerms. The mappings in this section reflect what `dismod` and `discordheadmod` get assigned in `rank_perms` — so any Discord member linked to a player with one of those ranks gains the matching commands.

> **Note on `dogcraft.chat.format.*`:** Tags default to `false` so they can be granted incrementally per rank. `<click:run_command>` is hardcoded as never-allowed regardless of permissions to prevent privilege-escalation exploits.

> **Note on tamed-pet override:** Pet protection is global — claim trust does NOT unlock it, and there's no permanent permission to bypass it. Staff who need to interact with another player's pet must toggle `/ignoreclaims owner` (session-scoped, resets on login).

---

## Links

- **Server:** dogcraft.net
