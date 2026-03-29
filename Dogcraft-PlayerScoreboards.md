# PlayerScoreboard

A Paper plugin that displays player statistics on a sidebar scoreboard. View your own stats, check another player's stats, or right-click a player to see theirs. Stats also appear as a hoverable chat message that persists after the scoreboard fades.

**Requires:** Paper 1.21.x+ / Java 21+
**Optional:** [Vault](https://www.spigotmc.org/resources/vault.34315/) (for economy/balance display)

---

## Installation

1. Download `PlayerScoreboard-1.0.0-SNAPSHOT.jar` (or build from source with `mvn clean package`)
2. Place the JAR in your server's `plugins/` folder
3. Start or restart the server
4. Edit `plugins/PlayerScoreboard/config.yml` to customize
5. Use `/statsreload` to apply config changes without restarting

---

## Commands

| Command | Description | Permission |
|---|---|---|
| `/stats` | View your own stats | None (all players) |
| `/stats <player>` | View another player's stats (online or offline) | None (all players) |
| `/statsreload` | Reload the plugin config | `PlayerScoreboard.reload` |

`/stats` supports tab-completion for online player names.

When viewing stats for an offline player, cached statistics are displayed with an offline indicator. If the player has never joined the server, an error message is shown.

---

## Permissions

| Permission | Description | Default |
|---|---|---|
| `PlayerScoreboard.staffMember` | Shows a staff member badge on the player's scoreboard | OP only |
| `PlayerScoreboard.reload` | Allows use of `/statsreload` | OP only |
| `playerstats.name.random` | Gives the player a colorful name on the stats scoreboard (random hex color or rainbow) | OP only |

### Color Name Details

Players with `playerstats.name.random` get a randomly styled title each time their stats are viewed:
- **75% chance** - A random solid hex color (vibrant, unique each time)
- **25% chance** - A full rainbow gradient across the title

Players without the permission get a plain white title (gray for offline players).

---

## Viewing Stats

There are two ways to view player stats:

### Scoreboard (Sidebar)
A temporary sidebar scoreboard appears showing all configured stats. It automatically disappears after the configured duration (`Time_Displayed` in config). The player's original scoreboard is restored when it fades.

### Chat Message (Hoverable)
A chat message is sent alongside the scoreboard. Hovering over it displays a tooltip with all the same stats. Since the scoreboard is temporary, this gives players a persistent way to review stats in their chat history.

### Right-Click
Right-clicking another player shows their stats (both scoreboard and chat message). This has a configurable cooldown (`Cooldown` in config) to prevent spam.

---

## Configuration

The config file is located at `plugins/PlayerScoreboard/config.yml`. Use `/statsreload` to apply changes.

### General Settings

```yaml
# How long the scoreboard is shown (in ticks, 20 ticks = 1 second)
Time_Displayed: 100

# Cooldown between right-click stat checks (in ticks)
Cooldown: 60

# Enable Vault economy integration
UseVault: true

# Currency label for money display
Currency: 'dcd'
```

### Chat Message

The chat message uses [MiniMessage](https://docs.advntr.dev/minimessage/format.html) format. Use `%player%` as a placeholder for the target player's name.

```yaml
# Default style
ChatMessage: '<dark_gray>[<gray>Stats for <white>%player%</white></gray>]</dark_gray>'

# Gradient style
ChatMessage: '<gradient:gold:yellow>Stats for %player%</gradient>'

# Hex color style
ChatMessage: '<#ff6600>Stats for <bold>%player%</bold></#ff6600>'

# Disable the chat message entirely
ChatMessage: ''
```

The hover tooltip is automatically generated from the scoreboard entries and is not configurable separately.

### Scoreboard Entries

The `Scoreboard` section is an ordered list. Items appear on the scoreboard from top to bottom in the order listed. Only items in this list are displayed. **Maximum 15 entries.**

```yaml
Scoreboard:
  - type: STAFF
    format: '&4Staff Member'

  - type: MONEY
    format: '&6%stat% dcd'

  - type: DEATHS
    format: 'Deaths: &6%stat%'

  - type: PLAY_ONE_MINUTE
    format: 'Time played: &6%stat%'
```

Each entry has:
- **`type`** (required) - The stat name, `STAFF`, or `MONEY`
- **`format`** (optional) - Display text with `&` color codes and `%stat%` placeholder. If omitted, a default is generated from the stat name.
- **`convert`** (optional) - Force a conversion: `none`, `tick`, `time`, or `distance`. If omitted, the plugin auto-detects based on the stat type.

### Auto-Detection

The plugin automatically applies the correct conversion for known stat types:

| Conversion | Applied To | Output Format |
|---|---|---|
| **tick** | `PLAY_ONE_MINUTE`, `TOTAL_WORLD_TIME`, `TIME_SINCE_DEATH`, `TIME_SINCE_REST`, `SNEAK_TIME` | `0Days 5Hrs 30Min` |
| **distance** | All `*_ONE_CM` stats (walking, swimming, flying, vehicles, etc.) | `12km 450m` |
| **none** | Everything else | Raw number |

You can override auto-detection with the `convert` field:

```yaml
  - type: SNEAK_TIME
    convert: none
    format: 'Sneak ticks: &6%stat%'
```

---

## Available Entry Types

### Special Entries

| Type | Description | Requirements |
|---|---|---|
| `STAFF` | Staff member badge | `PlayerScoreboard.staffMember` permission |
| `MONEY` | Player balance | Vault + `UseVault: true` |

### Time Stats

Auto-converted to Days/Hours/Minutes.

| Type | Description |
|---|---|
| `PLAY_ONE_MINUTE` | Total time played |
| `TOTAL_WORLD_TIME` | Total world time |
| `TIME_SINCE_DEATH` | Time since last death |
| `TIME_SINCE_REST` | Time since last sleep |
| `SNEAK_TIME` | Time spent sneaking |

### Distance Stats

Auto-converted to kilometers/meters.

| Type | Description |
|---|---|
| `WALK_ONE_CM` | Distance walked |
| `WALK_ON_WATER_ONE_CM` | Distance walked on water |
| `WALK_UNDER_WATER_ONE_CM` | Distance walked under water |
| `SPRINT_ONE_CM` | Distance sprinted |
| `CROUCH_ONE_CM` | Distance crouched |
| `CLIMB_ONE_CM` | Distance climbed |
| `FLY_ONE_CM` | Distance flown |
| `SWIM_ONE_CM` | Distance swam |
| `FALL_ONE_CM` | Distance fallen |
| `AVIATE_ONE_CM` | Distance with elytra |
| `BOAT_ONE_CM` | Distance by boat |
| `HORSE_ONE_CM` | Distance on horse |
| `MINECART_ONE_CM` | Distance by minecart |
| `PIG_ONE_CM` | Distance on pig |
| `STRIDER_ONE_CM` | Distance on strider |

### Combat Stats

| Type | Description |
|---|---|
| `DEATHS` | Total deaths |
| `PLAYER_KILLS` | Players killed |
| `MOB_KILLS` | Mobs killed |
| `DAMAGE_DEALT` | Damage dealt |
| `DAMAGE_TAKEN` | Damage taken |
| `DAMAGE_ABSORBED` | Damage absorbed |
| `DAMAGE_RESISTED` | Damage resisted |
| `DAMAGE_BLOCKED_BY_SHIELD` | Damage blocked by shield |
| `DAMAGE_DEALT_ABSORBED` | Damage dealt absorbed |
| `DAMAGE_DEALT_RESISTED` | Damage dealt resisted |
| `KILL_ENTITY` | Entities killed |
| `ENTITY_KILLED_BY` | Deaths by entities |

### Interaction Stats

| Type | Description |
|---|---|
| `CHEST_OPENED` | Chests opened |
| `ENDERCHEST_OPENED` | Ender chests opened |
| `SHULKER_BOX_OPENED` | Shulker boxes opened |
| `OPEN_BARREL` | Barrels opened |
| `TRAPPED_CHEST_TRIGGERED` | Trapped chests triggered |
| `FURNACE_INTERACTION` | Furnace interactions |
| `CRAFTING_TABLE_INTERACTION` | Crafting table interactions |
| `BREWINGSTAND_INTERACTION` | Brewing stand interactions |
| `BEACON_INTERACTION` | Beacon interactions |
| `INTERACT_WITH_ANVIL` | Anvil interactions |
| `INTERACT_WITH_BLAST_FURNACE` | Blast furnace interactions |
| `INTERACT_WITH_CAMPFIRE` | Campfire interactions |
| `INTERACT_WITH_CARTOGRAPHY_TABLE` | Cartography table interactions |
| `INTERACT_WITH_GRINDSTONE` | Grindstone interactions |
| `INTERACT_WITH_LECTERN` | Lectern interactions |
| `INTERACT_WITH_LOOM` | Loom interactions |
| `INTERACT_WITH_SMITHING_TABLE` | Smithing table interactions |
| `INTERACT_WITH_SMOKER` | Smoker interactions |
| `INTERACT_WITH_STONECUTTER` | Stonecutter interactions |
| `DISPENSER_INSPECTED` | Dispensers inspected |
| `DROPPER_INSPECTED` | Droppers inspected |
| `HOPPER_INSPECTED` | Hoppers inspected |

### Item Stats

| Type | Description |
|---|---|
| `BREAK_ITEM` | Items broken |
| `CRAFT_ITEM` | Items crafted |
| `USE_ITEM` | Items used |
| `PICKUP` | Items picked up |
| `DROP` | Items dropped |
| `DROP_COUNT` | Total drop count |
| `MINE_BLOCK` | Blocks mined |
| `ITEM_ENCHANTED` | Items enchanted |

### Misc Stats

| Type | Description |
|---|---|
| `ANIMALS_BRED` | Animals bred |
| `FISH_CAUGHT` | Fish caught |
| `TALKED_TO_VILLAGER` | Villagers talked to |
| `TRADED_WITH_VILLAGER` | Villager trades |
| `CAKE_SLICES_EATEN` | Cake slices eaten |
| `ARMOR_CLEANED` | Armor cleaned |
| `BANNER_CLEANED` | Banners cleaned |
| `CLEAN_SHULKER_BOX` | Shulker boxes cleaned |
| `CAULDRON_FILLED` | Cauldrons filled |
| `CAULDRON_USED` | Cauldrons used |
| `FLOWER_POTTED` | Flowers potted |
| `NOTEBLOCK_PLAYED` | Noteblocks played |
| `NOTEBLOCK_TUNED` | Noteblocks tuned |
| `RECORD_PLAYED` | Records played |
| `SLEEP_IN_BED` | Times slept in bed |
| `BELL_RING` | Bells rung |
| `TARGET_HIT` | Targets hit |
| `RAID_TRIGGER` | Raids triggered |
| `RAID_WIN` | Raids won |
| `JUMP` | Times jumped |
| `LEAVE_GAME` | Times left the server |

> **Note:** Some stats (`KILL_ENTITY`, `ENTITY_KILLED_BY`, `MINE_BLOCK`, `BREAK_ITEM`, `CRAFT_ITEM`, `USE_ITEM`, `PICKUP`, `DROP`) are sub-statistic types in Minecraft. The plugin tracks their totals without filtering by specific entity or block type. If the server does not have data for these, they are silently skipped.

---

## Example Configs

### Minimal (just combat stats)

```yaml
Time_Displayed: 100
Cooldown: 60
UseVault: false
ChatMessage: '<gray>[Stats for <white>%player%</white>]</gray>'

Scoreboard:
  - type: DEATHS
    format: 'Deaths: &6%stat%'
  - type: PLAYER_KILLS
    format: 'Player Kills: &6%stat%'
  - type: MOB_KILLS
    format: 'Mob Kills: &6%stat%'
```

### Exploration focused

```yaml
Time_Displayed: 200
Cooldown: 60
UseVault: false
ChatMessage: '<green>%player% Explorer Stats</green>'

Scoreboard:
  - type: PLAY_ONE_MINUTE
    format: 'Time played: &a%stat%'
  - type: WALK_ONE_CM
    format: 'Walked: &a%stat%'
  - type: SWIM_ONE_CM
    format: 'Swam: &a%stat%'
  - type: AVIATE_ONE_CM
    format: 'Elytra: &a%stat%'
  - type: HORSE_ONE_CM
    format: 'Horse: &a%stat%'
  - type: BOAT_ONE_CM
    format: 'Boat: &a%stat%'
  - type: CLIMB_ONE_CM
    format: 'Climbed: &a%stat%'
```

### Full server with economy

```yaml
Time_Displayed: 100
Cooldown: 60
UseVault: true
Currency: 'coins'
ChatMessage: '<dark_gray>[<gray>Stats for <white>%player%</white></gray>]</dark_gray>'

Scoreboard:
  - type: STAFF
    format: '&4Staff Member'
  - type: MONEY
    format: '&6%stat% coins'
  - type: DEATHS
    format: 'Deaths: &6%stat%'
  - type: PLAYER_KILLS
    format: 'Player Kills: &6%stat%'
  - type: MOB_KILLS
    format: 'Mob Kills: &6%stat%'
  - type: PLAY_ONE_MINUTE
    format: 'Time played: &6%stat%'
  - type: TIME_SINCE_DEATH
    format: 'Last Death: &6%stat%'
  - type: WALK_ONE_CM
    format: 'Walked: &6%stat%'
  - type: FISH_CAUGHT
    format: 'Fish caught: &6%stat%'
  - type: ANIMALS_BRED
    format: 'Animals bred: &6%stat%'
```

---

## Building from Source

Requires Java 21+ and Maven.

```bash
git clone https://github.com/Ironboundred/Dogcraft-PlayerScoreboards.git
cd Dogcraft-PlayerScoreboards
mvn clean package
```

The compiled JAR will be at `target/PlayerScoreboard-1.0.0-SNAPSHOT.jar`.
