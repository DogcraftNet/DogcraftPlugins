# Dogcraft-Fallen

A Paper plugin that adds a **PvP toggle** system and a **death drops** system to your server. When a player dies, their items are stored inside a mannequin at the death location instead of scattering on the ground. Players can opt in or out of PvP, with protections against spawn-killing, combat logging, and new-player griefing.

**Requires:** Paper 1.21+ (uses the Mannequin entity)

---

## How It Works

### PvP Toggle

PvP is **off by default**. Players must opt in with `/pvp on` before they can deal or receive player damage. Both the attacker and defender need PvP enabled for combat to happen.

- If either player has PvP off, the hit is cancelled and both players are notified.
- After hitting or being hit, both players are **combat tagged** for a configurable duration (default 5s). While tagged, PvP cannot be toggled off.
- There is a **toggle cooldown** (default 10s) to prevent spamming `/pvp` on and off.
- **Respawn protection** grants temporary PvP immunity after respawning (default 10s).
- **New player protection** shields players who have less than a configurable amount of total playtime (default 5 minutes). New players cannot attack or be attacked.
- **Combat logging** (optional, off by default) kills players who disconnect while combat tagged, causing their items to enter the death drops system.

### Death Drops

When a player dies, instead of items scattering on the ground:

1. A **mannequin** spawns at the death location wearing the player's armor and holding their items.
2. The mannequin displays the player's skin, name, and a countdown timer.
3. **Soul particles** float above it so it is easy to spot.
4. A **sound effect** plays when drops are placed.
5. The player receives a chat message with the coordinates and a clickable **[Unlock Drops]** button.

**Retrieving items:** Right-click the mannequin to open a loot GUI. Take what you need and close the inventory. Any items left behind are dropped on the ground and the mannequin is removed.

**Timer behavior:** The countdown only ticks while the chunk is loaded, matching vanilla item despawn behavior. If nobody is near the drops, the timer pauses.

**Multiple drops:** If a player dies again before retrieving their previous drops, a new mannequin is created. All drops are tracked independently — nothing is lost from earlier deaths.

**XP:** Dropped experience is stored in the death drop and returned to whoever loots the mannequin.

**Unlocking:** By default, only the owner (and admins) can loot a mannequin. The owner can run `/fallen unlock` to make all their drops available to anyone. This is useful if you die in an inconvenient location and want a friend to grab your gear.

**Expiry:** When the timer runs out, the mannequin and all items inside are permanently lost. The owner is notified in chat. Periodic reminders are sent while drops are active (configurable interval, default 60s).

**Respawn reminder:** When a player respawns, they receive a message listing all their active drops with coordinates and remaining time.

---

## Commands

### `/pvp`

| Usage | Description |
|---|---|
| `/pvp` | Toggle your PvP on/off |
| `/pvp on` | Enable your PvP |
| `/pvp off` | Disable your PvP |
| `/pvp status` | Check your own PvP status |
| `/pvp status <player>` | Check another player's PvP status |
| `/pvp admin <player> <on\|off>` | Force-set a player's PvP state |

### `/fallen`

| Usage | Description |
|---|---|
| `/fallen` | List all your active death drops with coordinates and timers |
| `/fallen unlock` | Unlock all your death drops so anyone can loot them |
| `/fallen admin list` | List all active death drops on the server |
| `/fallen admin remove <player>` | Remove all death drops for a player |
| `/fallen admin unlock <player>` | Unlock all death drops for a player |

The admin `list` command shows clickable **[Unlock]** and **[Remove]** buttons next to each entry.

---

## Permissions

| Permission | Description | Default |
|---|---|---|
| `dogcraftfallen.pvp` | Use the `/pvp` command | Everyone |
| `dogcraftfallen.pvp.status.other` | Check other players' PvP status | Everyone |
| `dogcraftfallen.deathdrops` | Use the `/fallen` command | Everyone |
| `dogcraftfallen.admin` | Access all admin subcommands for both `/pvp` and `/fallen` | OP |

---

## Configuration

All settings are in `config.yml` with inline comments. Key options:

### PvP

| Setting | Default | Description |
|---|---|---|
| `pvp.default-state` | `false` | PvP state for players who have never toggled |
| `pvp.cooldown-seconds` | `10` | Seconds between PvP toggles (0 = none) |
| `pvp.combat-tag-seconds` | `5` | Seconds of combat tag after PvP damage (0 = disabled) |
| `pvp.combat-log-kill` | `false` | Kill players who disconnect while combat tagged |
| `pvp.respawn-protection-seconds` | `10` | PvP immunity after respawning (0 = disabled) |
| `pvp.new-player-protection-minutes` | `5` | Playtime before protection wears off (0 = disabled) |
| `pvp.notify-attacker` | `true` | Tell the attacker when PvP is blocked |
| `pvp.notify-defender` | `true` | Tell the defender when someone tries to hit them |
| `pvp.world-whitelist` | `[]` | Only enable PvP toggle in these worlds |
| `pvp.world-blacklist` | `[]` | Disable PvP toggle in these worlds |

### Death Drops

| Setting | Default | Description |
|---|---|---|
| `death-drops.enabled` | `true` | Master toggle for the death drops system |
| `death-drops.timer-seconds` | `300` | Seconds before drops expire (timer pauses in unloaded chunks) |
| `death-drops.safe-placement` | `true` | Find safe ground near the death point for the mannequin |
| `death-drops.notify-on-spawn` | `true` | Tell the player where drops were placed |
| `death-drops.notify-on-expiry` | `true` | Warn the player when drops expire |
| `death-drops.notify-interval-seconds` | `60` | Periodic reminder interval (0 = disabled) |
| `death-drops.particles` | `true` | Soul particles above the mannequin |
| `death-drops.sound-on-spawn` | `true` | Sound effect when drops are placed |
| `death-drops.world-whitelist` | `[]` | Only enable death drops in these worlds |
| `death-drops.world-blacklist` | `[]` | Disable death drops in these worlds |

**World restrictions:** If the whitelist is set, only those worlds are active. If the blacklist is set, those worlds are excluded. Whitelist takes priority. If both are empty, all worlds are active. When a world is excluded, vanilla behavior is used instead.

---

## Data Files

| File | Purpose |
|---|---|
| `pvp-data.yml` | Persists each player's PvP toggle state across restarts |
| `death-drops.yml` | Persists active death drops across restarts (items, XP, timer, location) |

Both files are managed automatically. Death drops are saved on shutdown and rehydrated on startup — mannequins and timers resume where they left off.
