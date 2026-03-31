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

## Links

- **Server:** dogcraft.net
