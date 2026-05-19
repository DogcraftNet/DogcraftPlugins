# Dogcraft SuffixManager

A standalone suffix API plugin for Paper 1.21+ that lets multiple minigame plugins share a single cosmetic suffix system. Players unlock suffixes through gameplay and select which one to display via LuckPerms.

## How It Works

SuffixManager acts as a central registry. Each minigame plugin registers a **SuffixProvider** that defines its available suffixes and tracks unlock progress. SuffixManager handles everything else — the `/suffix` command, database persistence, LuckPerms integration, and the player-facing menu.

```
┌─────────────────────────────────────────────────┐
│               SuffixManager Plugin              │
│                                                 │
│  SuffixRegistry ─── DatabaseManager (SQLite)    │
│       │                                         │
│       ├── LuckPermsHook (soft-depend)           │
│       ├── /suffix command + menu                │
│       └── PlayerJoinListener                    │
│                                                 │
│  Registered via Bukkit ServicesManager           │
└──────────────┬──────────────┬───────────────────┘
               │              │
    ┌──────────▼──┐   ┌──────▼───────┐
    │  HNS Plugin │   │ BedWars Plugin│
    │  (provider) │   │  (provider)   │
    └─────────────┘   └──────────────┘
```

**Key principle**: each minigame owns its unlock logic and stat tracking. SuffixManager owns display, selection, and LuckPerms integration.

## Features

- **Provider-based architecture** — any plugin can register suffixes
- **Soft-depend friendly** — consumer plugins work with or without SuffixManager installed
- **LuckPerms integration** — automatically applies the selected suffix as a LuckPerms SuffixNode (soft-depend, works without it)
- **Async everything** — all database and provider queries return `CompletableFuture`, nothing blocks the main thread
- **Auto-cleanup** — providers are automatically unregistered when their owning plugin disables
- **Clickable menu** — `/suffix` shows an interactive chat menu with select buttons and progress bars
- **Event system** — `SuffixEquipEvent` (cancellable) and `SuffixUnlockEvent` for cross-plugin hooks

## Requirements

- **Paper 1.21+** (or any Paper fork)
- **Java 21+**
- **LuckPerms** (optional) — if installed, equipped suffixes are applied as LuckPerms suffix nodes. Without it, suffixes are tracked in the database but not displayed in-game.

## Installation

Drop `dogcraft-suffixmanager-1.0-SNAPSHOT.jar` into your server's `plugins/` folder and restart.

## Configuration

`plugins/Dogcraft-SuffixManager/config.yml`:

```yaml
# Database settings
database:
  # SQLite database file name (stored in plugin data folder)
  file: suffixes.db

# LuckPerms integration
luckperms:
  # Priority for the suffix node (higher = takes precedence)
  suffix-priority: 100
```

## Commands

| Command | Description | Permission |
|---|---|---|
| `/suffix` | Open the interactive suffix menu | `suffixmanager.use` (default: true) |
| `/suffix equip <namespace:id>` | Equip a specific suffix | `suffixmanager.use` |
| `/suffix clear` | Remove your active suffix | `suffixmanager.use` |
| `/suffix reload` | Reload the config | `suffixmanager.reload` (default: op) |

## Suffix Menu

Running `/suffix` displays an interactive chat menu:

```
═══ Your Suffixes ═══

  Hns
  [Ghost]        [Select]
  [Phantom]      Locked - Survive 50 games as hider (23/50)
  [Bloodhound]   [Select]

  Bedwars
  [Destroyer]    [Select]
  [Defender]     Locked - Win 100 games (45/100)

  Active: [Ghost]
  [Clear Suffix]
```

Unlocked suffixes show a clickable `[Select]` button. Locked suffixes show the unlock condition and current progress. The active suffix is highlighted with `[Equipped]`.

---

## API Usage (Soft-Depend via Reflection)

SuffixManager is a **pure soft dependency**. No Maven dependency, no compile-time references, no jar on the build path. Consumer plugins use reflection to access the API at runtime and gracefully skip suffix features if SuffixManager is not installed.

### How It Works

1. SuffixManager registers its `SuffixRegistry` via Bukkit's `ServicesManager`
2. Consumer plugins declare `softdepend: [Dogcraft-SuffixManager]` in `plugin.yml`
3. At runtime, consumers check if the plugin is present and use reflection to get the registry and register a provider
4. `java.lang.reflect.Proxy` is used to implement the `SuffixProvider` interface without any compile-time reference to SuffixManager classes

### plugin.yml

```yaml
name: MyMinigame
version: '1.0'
main: com.example.myminigame.MyMinigame
softdepend:
  - Dogcraft-SuffixManager
```

### SuffixManagerHook.java

This is a self-contained utility class that uses **only reflection** — no imports from `net.dogcraft.suffixmanager` anywhere. Drop it into your project and it compiles on its own.

The `SuffixProvider` interface has 4 methods — `getNamespace()`, `getSuffixes()`, `getUnlockStatus()`, and `getUnlockedSuffixes()`. The provider is the authoritative source for unlock tracking. SuffixManager mirrors the results to its shared database so other servers can access unlock data even without the provider plugin installed.

```java
import org.bukkit.Bukkit;
import org.bukkit.plugin.java.JavaPlugin;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.logging.Level;

/**
 * Pure-reflection hook for Dogcraft-SuffixManager.
 * No compile-time dependency on any SuffixManager classes.
 */
public class SuffixManagerHook {

    private final JavaPlugin plugin;
    private Object registry;
    private boolean available;

    // Reflected methods cached after init
    private Method equipSuffixMethod;
    private Method clearSuffixMethod;
    private Method updateProgressMethod;
    private Method unlockSuffixMethod;

    // Reflected classes/constructors
    private Constructor<?> suffixDefinitionCtor;
    private Constructor<?> unlockStatusCtor;
    private Class<?> providerInterface;

    public SuffixManagerHook(JavaPlugin plugin) {
        this.plugin = plugin;
        this.available = false;
    }

    /**
     * Attempt to hook into SuffixManager. Call in onEnable()
     * after confirming the plugin is present.
     */
    public boolean hook() {
        try {
            Class<?> apiClass = Class.forName("net.dogcraft.suffixmanager.api.SuffixAPI");
            Method getRegistry = apiClass.getMethod("getRegistry");
            registry = getRegistry.invoke(null);

            if (registry == null) {
                plugin.getLogger().warning("SuffixManager is installed but registry not available yet.");
                return false;
            }

            providerInterface = Class.forName("net.dogcraft.suffixmanager.api.SuffixProvider");
            Class<?> suffixDefClass = Class.forName("net.dogcraft.suffixmanager.api.SuffixDefinition");
            Class<?> unlockStatusClass = Class.forName("net.dogcraft.suffixmanager.api.UnlockStatus");
            Class<?> registryInterface = Class.forName("net.dogcraft.suffixmanager.api.SuffixRegistry");

            suffixDefinitionCtor = suffixDefClass.getConstructor(
                    String.class, String.class, String.class, String.class, String.class, String.class);
            unlockStatusCtor = unlockStatusClass.getConstructor(boolean.class, int.class, int.class);

            equipSuffixMethod = registryInterface.getMethod("equipSuffix", UUID.class, String.class);
            clearSuffixMethod = registryInterface.getMethod("clearSuffix", UUID.class);
            updateProgressMethod = registryInterface.getMethod("updateProgress",
                    UUID.class, String.class, int.class, int.class);
            unlockSuffixMethod = registryInterface.getMethod("unlockSuffix", UUID.class, String.class);

            available = true;
            return true;
        } catch (ClassNotFoundException e) {
            plugin.getLogger().info("SuffixManager classes not found — suffix features disabled.");
            return false;
        } catch (Exception e) {
            plugin.getLogger().log(Level.WARNING, "Failed to hook into SuffixManager", e);
            return false;
        }
    }

    public boolean isAvailable() {
        return available;
    }

    /**
     * Register a suffix provider. Definitions are persisted to the shared DB.
     * The unlock checker is the authoritative source — SuffixManager mirrors
     * results to its DB for cross-server access.
     *
     * @param namespace     unique namespace (e.g. "hns", "bedwars")
     * @param suffixes      list of suffix data maps with keys:
     *                      "id", "displayText", "description", "category", "iconMaterial", "frameType"
     * @param unlockChecker function: (UUID player, String suffixId) -> int[] { current, target }
     */
    public void registerProvider(String namespace, List<Map<String, String>> suffixes,
                                 SuffixUnlockChecker unlockChecker) {
        if (!available) return;

        try {
            List<Object> definitionObjects = new ArrayList<>();
            Map<String, Object> definitionMap = new LinkedHashMap<>();
            for (Map<String, String> data : suffixes) {
                Object def = suffixDefinitionCtor.newInstance(
                        data.get("id"),
                        data.get("displayText"),
                        data.get("description"),
                        data.getOrDefault("category", "general"),
                        data.getOrDefault("iconMaterial", "PAPER"),
                        data.getOrDefault("frameType", "task")
                );
                definitionObjects.add(def);
                definitionMap.put(data.get("id"), def);
            }

            Object provider = Proxy.newProxyInstance(
                    providerInterface.getClassLoader(),
                    new Class<?>[]{ providerInterface },
                    (proxy, method, args) -> switch (method.getName()) {
                        case "getNamespace" -> namespace;
                        case "getSuffixes" -> List.copyOf(definitionObjects);

                        case "getUnlockStatus" -> {
                            UUID playerUuid = (UUID) args[0];
                            String suffixId = (String) args[1];
                            yield CompletableFuture.supplyAsync(() -> {
                                try {
                                    int[] progress = unlockChecker.getProgress(playerUuid, suffixId);
                                    return unlockStatusCtor.newInstance(
                                            progress[0] >= progress[1], progress[0], progress[1]);
                                } catch (Exception e) {
                                    plugin.getLogger().log(Level.WARNING,
                                            "Error checking unlock for " + suffixId, e);
                                    return unlockStatusCtor.newInstance(false, 0, 1);
                                }
                            });
                        }

                        case "getUnlockedSuffixes" -> {
                            UUID playerUuid = (UUID) args[0];
                            yield CompletableFuture.supplyAsync(() -> {
                                Set<String> unlocked = new HashSet<>();
                                for (String suffixId : definitionMap.keySet()) {
                                    try {
                                        int[] progress = unlockChecker.getProgress(playerUuid, suffixId);
                                        if (progress[0] >= progress[1]) unlocked.add(suffixId);
                                    } catch (Exception e) {
                                        plugin.getLogger().log(Level.WARNING,
                                                "Error checking unlock for " + suffixId, e);
                                    }
                                }
                                return unlocked;
                            });
                        }

                        case "toString" -> "SuffixProvider[" + namespace + "]";
                        case "hashCode" -> namespace.hashCode();
                        case "equals" -> proxy == args[0];
                        default -> null;
                    }
            );

            Method registerMethod = registry.getClass().getMethod(
                    "registerProvider", JavaPlugin.class, providerInterface);
            registerMethod.invoke(registry, plugin, provider);

            plugin.getLogger().info("Registered suffix provider: " + namespace
                    + " (" + suffixes.size() + " suffixes)");
        } catch (Exception e) {
            plugin.getLogger().log(Level.WARNING,
                    "Failed to register suffix provider: " + namespace, e);
        }
    }

    /**
     * Functional interface for checking a player's progress toward a suffix.
     * Return int[] { currentProgress, targetProgress }.
     */
    @FunctionalInterface
    public interface SuffixUnlockChecker {
        int[] getProgress(UUID player, String suffixId);
    }

    /**
     * Update a player's progress toward a suffix. Automatically unlocks
     * when current >= target. Persisted to the shared DB (cross-server).
     *
     * @param player       the player's UUID
     * @param namespacedId fully qualified suffix ID (e.g. "myminigame:rookie")
     * @param current      current progress value
     * @param target       target value to unlock
     */
    public void updateProgress(UUID player, String namespacedId, int current, int target) {
        if (!available) return;
        try {
            updateProgressMethod.invoke(registry, player, namespacedId, current, target);
        } catch (Exception e) {
            plugin.getLogger().log(Level.WARNING, "Failed to update progress", e);
        }
    }

    /**
     * Explicitly mark a suffix as unlocked for a player.
     */
    public void unlockSuffix(UUID player, String namespacedId) {
        if (!available) return;
        try {
            unlockSuffixMethod.invoke(registry, player, namespacedId);
        } catch (Exception e) {
            plugin.getLogger().log(Level.WARNING, "Failed to unlock suffix", e);
        }
    }

    /**
     * Equip a suffix for a player.
     */
    public void equipSuffix(UUID player, String namespacedId) {
        if (!available) return;
        try {
            equipSuffixMethod.invoke(registry, player, namespacedId);
        } catch (Exception e) {
            plugin.getLogger().log(Level.WARNING, "Failed to equip suffix", e);
        }
    }

    /**
     * Clear a player's active suffix.
     */
    public void clearSuffix(UUID player) {
        if (!available) return;
        try {
            clearSuffixMethod.invoke(registry, player);
        } catch (Exception e) {
            plugin.getLogger().log(Level.WARNING, "Failed to clear suffix", e);
        }
    }
}
```

---

## Example: Full Usage

A complete example showing how a minigame plugin registers three suffixes and reports progress using pure reflection — **no SuffixManager imports anywhere in the project**.

### MyMinigame.java (Main Plugin Class)

```java
import org.bukkit.plugin.java.JavaPlugin;

public class MyMinigame extends JavaPlugin {

    private SuffixManagerHook suffixHook;

    @Override
    public void onEnable() {
        if (getServer().getPluginManager().getPlugin("Dogcraft-SuffixManager") != null) {
            suffixHook = new SuffixManagerHook(this);
            if (suffixHook.hook()) {
                registerSuffixes();
                getLogger().info("SuffixManager found — suffix features enabled!");
            }
        } else {
            getLogger().info("SuffixManager not installed, suffix features disabled.");
        }
    }

    private void registerSuffixes() {
        // Define suffixes as plain data maps — persisted to the shared DB on registration
        List<Map<String, String>> suffixes = List.of(
            Map.of(
                "id", "rookie",
                "displayText", "<green>[Rookie]</green>",
                "description", "Win 10 games",
                "category", "general",
                "iconMaterial", "IRON_SWORD",
                "frameType", "task"
            ),
            Map.of(
                "id", "veteran",
                "displayText", "<gold>[Veteran]</gold>",
                "description", "Win 100 games",
                "category", "general",
                "iconMaterial", "DIAMOND_SWORD",
                "frameType", "goal"
            ),
            Map.of(
                "id", "legend",
                "displayText", "<gradient:#FFD700:#FF4500>[Legend]</gradient>",
                "description", "Win 500 games",
                "category", "general",
                "iconMaterial", "NETHERITE_SWORD",
                "frameType", "challenge"
            )
        );

        // Provider is authoritative for unlocks — SuffixManager mirrors to DB for cross-server
        suffixHook.registerProvider("myminigame", suffixes, (player, suffixId) -> {
            int wins = getStatsManager().getWins(player); // your own stats system
            int threshold = switch (suffixId) {
                case "rookie"  -> 10;
                case "veteran" -> 100;
                case "legend"  -> 500;
                default -> Integer.MAX_VALUE;
            };
            return new int[]{ wins, threshold };
        });
    }

    public SuffixManagerHook getSuffixHook() {
        return suffixHook;
    }
}
```

### Updating Progress After Games

```java
public void onGameEnd(Player player, int totalWins) {
    SuffixManagerHook hook = plugin.getSuffixHook();
    if (hook == null || !hook.isAvailable()) return;

    UUID uuid = player.getUniqueId();

    // The provider's unlock checker is queried automatically when the /suffix menu
    // is opened or when equipSuffix is called — results are mirrored to the shared DB.
    //
    // You can also explicitly push progress to the DB for immediate cross-server sync:
    hook.updateProgress(uuid, "myminigame:rookie",  totalWins, 10);
    hook.updateProgress(uuid, "myminigame:veteran", totalWins, 100);
    hook.updateProgress(uuid, "myminigame:legend",  totalWins, 500);
}
```

### What the Consumer Plugin Needs

| File | SuffixManager imports? |
|---|---|
| `plugin.yml` | No — just `softdepend: [Dogcraft-SuffixManager]` |
| `pom.xml` | No — no dependency needed |
| `MyMinigame.java` | No — only references `SuffixManagerHook` (your own class) |
| `SuffixManagerHook.java` | No — pure reflection, only standard Java + Bukkit imports |

Zero compile-time coupling. If SuffixManager isn't on the server, `getPlugin()` returns null and your plugin runs without suffix features.

---

## API Reference

### Core Interfaces

#### SuffixProvider

Implement this in your minigame plugin to register suffixes. The provider is the authoritative source for unlock tracking — SuffixManager mirrors results to its shared database for cross-server access.

| Method | Returns | Description |
|---|---|---|
| `getNamespace()` | `String` | Unique lowercase identifier (e.g. `"hns"`) |
| `getSuffixes()` | `List<SuffixDefinition>` | All suffix definitions your plugin offers |
| `getUnlockStatus(UUID, String)` | `CompletableFuture<UnlockStatus>` | Check if a player has unlocked a specific suffix (authoritative) |
| `getUnlockedSuffixes(UUID)` | `CompletableFuture<Set<String>>` | Get all unlocked suffix IDs for a player (authoritative) |

#### SuffixRegistry

Central API obtained via `SuffixAPI.getRegistry()`.

**Provider Registration:**

| Method | Returns | Description |
|---|---|---|
| `registerProvider(SuffixProvider)` | `void` | Register a provider (upserts definitions to DB) |
| `registerProvider(JavaPlugin, SuffixProvider)` | `void` | Register with ownership tracking (auto-unregister on disable) |
| `unregisterProvider(String)` | `void` | Unregister by namespace (definitions stay in DB for cross-server) |
| `getProviders()` | `Collection<SuffixProvider>` | All providers registered on this server |
| `getProvider(String)` | `SuffixProvider` | Get provider by namespace (nullable) |
| `getAllSuffixes()` | `List<NamespacedSuffix>` | All suffixes from in-memory providers |
| `getAllSuffixesFromDatabase()` | `CompletableFuture<List<NamespacedSuffix>>` | All suffixes from DB (cross-server) |

**Unlock Tracking (DB-backed, cross-server):**

| Method | Returns | Description |
|---|---|---|
| `updateProgress(UUID, String, int, int)` | `CompletableFuture<Void>` | Update progress — auto-unlocks when current >= target |
| `unlockSuffix(UUID, String)` | `CompletableFuture<Void>` | Explicitly mark a suffix as unlocked |
| `getUnlockStatus(UUID, String)` | `CompletableFuture<UnlockStatus>` | Get a player's unlock status for a suffix |
| `getUnlockedSuffixes(UUID, String)` | `CompletableFuture<Set<String>>` | Get all unlocked IDs (namespace filter nullable) |
| `getAllProgress(UUID)` | `CompletableFuture<Map<String, UnlockStatus>>` | Get all progress data for a player |

**Equip / Clear:**

| Method | Returns | Description |
|---|---|---|
| `getEquippedSuffix(UUID)` | `CompletableFuture<String>` | Get equipped suffix ID (e.g. `"hns:ghost"`) |
| `equipSuffix(UUID, String)` | `CompletableFuture<Boolean>` | Equip a suffix (validates unlock from DB, fires event, applies to LP) |
| `clearSuffix(UUID)` | `CompletableFuture<Void>` | Clear the active suffix |

### Data Records

#### SuffixDefinition

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique within namespace (e.g. `"ghost"`) |
| `displayText` | `String` | MiniMessage format (e.g. `"<gray>[Ghost]</gray>"`) |
| `description` | `String` | Human-readable unlock condition |
| `category` | `String` | Grouping key for display |
| `iconMaterial` | `String` | Material name for advancement icon |
| `frameType` | `String` | `"task"`, `"goal"`, or `"challenge"` |

#### UnlockStatus

| Field | Type | Description |
|---|---|---|
| `unlocked` | `boolean` | Whether the suffix is unlocked |
| `currentProgress` | `int` | Current progress value |
| `targetProgress` | `int` | Required value to unlock |

#### NamespacedSuffix

| Field | Type | Description |
|---|---|---|
| `namespace` | `String` | Provider namespace |
| `definition` | `SuffixDefinition` | The suffix definition |
| `getFullId()` | `String` | Returns `"namespace:id"` |

### Events

#### SuffixEquipEvent (Cancellable)

Fired when a player equips, changes, or clears their suffix. Cancel to block the change.

| Method | Returns | Description |
|---|---|---|
| `getPlayer()` | `UUID` | The player |
| `getPreviousSuffix()` | `String` | Previous suffix ID (empty if none) |
| `getNewSuffix()` | `String` | New suffix ID (empty if clearing) |

#### SuffixUnlockEvent

Fired automatically when `updateProgress()` or `unlockSuffix()` results in a new unlock.

| Method | Returns | Description |
|---|---|---|
| `getPlayer()` | `UUID` | The player |
| `getNamespace()` | `String` | Provider namespace |
| `getSuffixId()` | `String` | Suffix ID within namespace |
| `getFullId()` | `String` | Full namespaced ID |
| `getDefinition()` | `SuffixDefinition` | The suffix definition |

---

## Architecture

### Database

SuffixManager owns all persistent state — definitions, unlocks, and equipped suffixes. This makes everything accessible cross-server when using MySQL.

```sql
-- Which suffix a player has equipped
CREATE TABLE suffix_players (
    uuid VARCHAR(36) PRIMARY KEY,
    equipped_suffix VARCHAR(128) DEFAULT ''
);

-- All registered suffix definitions (upserted on provider registration)
CREATE TABLE suffix_definitions (
    namespace VARCHAR(64) NOT NULL,
    suffix_id VARCHAR(64) NOT NULL,
    display_text VARCHAR(256) NOT NULL DEFAULT '',
    description VARCHAR(256) NOT NULL DEFAULT '',
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    icon_material VARCHAR(64) NOT NULL DEFAULT 'PAPER',
    frame_type VARCHAR(16) NOT NULL DEFAULT 'task',
    PRIMARY KEY (namespace, suffix_id)
);

-- Player unlock progress (updated by providers via updateProgress/unlockSuffix)
CREATE TABLE suffix_unlocks (
    uuid VARCHAR(36) NOT NULL,
    namespace VARCHAR(64) NOT NULL,
    suffix_id VARCHAR(64) NOT NULL,
    unlocked BOOLEAN NOT NULL DEFAULT 0,
    current_progress INT NOT NULL DEFAULT 0,
    target_progress INT NOT NULL DEFAULT 1,
    PRIMARY KEY (uuid, namespace, suffix_id)
);
```

### Cross-Server Support

When using MySQL, all servers share the same database. The system uses a **hybrid** approach:

- **Provider is authoritative**: When a provider is registered on this server, SuffixManager queries it for unlock status and mirrors the result to the DB
- **DB is the fallback**: When a provider is NOT on this server (e.g. the HNS plugin isn't installed on the lobby server), unlock data is read from the DB
- **Explicit sync**: Providers can also call `updateProgress()` / `unlockSuffix()` to push data to the DB immediately after a game ends
- **Definitions persist**: Provider registration upserts definitions to the DB, so any server can display them in the `/suffix` menu
- Players can unlock a suffix on one server and equip it on another

### LuckPerms Integration

When a suffix is equipped, SuffixManager:
1. Loads the LuckPerms user
2. Clears **all** existing `SuffixNode` entries
3. Adds a new `SuffixNode` with the MiniMessage display text and configured priority (default 100)
4. Saves the user

`PrefixNode` entries are never touched — the server's global prefix is preserved. MiniMessage format is written directly to LuckPerms (no legacy code conversion).

### Thread Safety

- Provider registry: `ConcurrentHashMap`
- Database: single-thread `ExecutorService` (write serialization)
- All player-facing methods: `CompletableFuture`
- Bukkit events: always fired on the main thread, bridged from async chains via `Bukkit.getScheduler().runTask()`

---

## Building

```bash
mvn clean package
```

Output: `target/dogcraft-suffixmanager-1.0-SNAPSHOT.jar`
