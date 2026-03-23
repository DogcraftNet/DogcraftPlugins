# Dogcraft Plugins

Custom plugins built for the **Dogcraft.net** Minecraft server network. Everything here is developed in-house to give our players a seamless multi-server experience — shared inventories, cross-server chat, a unified economy, and more.

Our network runs on **Paper 1.21+** backends behind a **Velocity** proxy, with **MySQL** for persistent storage and **Redis** for real-time cross-server sync.

---

## The Plugins

### [Dogcraft-Sync](Dogcraft-Sync.MD)
Player data synchronization across servers. Inventories, stats, advancements, potion effects, maps, and player state all follow you when you switch servers. Includes admin tools for viewing and editing any player's inventory remotely.

### [Dogcraft-Economy](Dogcraft-Economy.md)
Shared economy with atomic balance operations via Redis Lua scripts. Provides a Vault integration so any Vault-compatible plugin works automatically. Full transaction ledger with audit support.

### [Dogcraft-Claims](Dogcraft-Claims.md)
Land claiming and block protection inspired by GriefPrevention. Golden shovel claims, four-tier trust system, block locks with group management, subdivisions, claim flags, and a claim block economy — all synced across servers.

### [Dogcraft-Homes](Dogcraft-Homes.md)
Home management with inventory GUIs, cross-server teleporting, economy-integrated pricing with exponential scaling, discount tiers, refunds, home sharing, and a teleport warmup system with portal visual effects.

### [Dogcraft-Chat](Dogcraft-Chat.md)
Cross-server chat forwarding via Velocity with custom formatting, LuckPerms prefix support, private messaging, group messaging, staff chat, and socialspy. Uses Netty packet interception to preserve chat signing on the same server.

### [Dogcraft-Tab](Dogcraft-Tab.md)
Network-wide tab list that shows all players across every server with correct skins, LuckPerms ranks, configurable sorting, and vanish support. Uses NMS packet injection for remote player entries.

### [Dogcraft-Vanish](Dogcraft-Vanish.md)
Staff vanish with full detection suppression — mobs, item pickups, pressure plates, sculk sensors, projectiles, and more are all blocked. Vanish state persists across server switches via Redis. Includes audit logging and plugin message broadcasting for integration with other plugins.

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
