# Dogcraft-PlayerMessager

A network-wide message broker for Minecraft servers. Other plugins call a small API to send messages to players — this plugin handles delivery, queueing, cross-server routing, and offline persistence. No plugin ever has to write its own "deliver now or queue for next login" code again.

## Features

- **Cross-server delivery** — send a message to a player on any backend server via Redis pub/sub
- **Offline queueing** — messages persist in MariaDB and are delivered on the player's next login
- **Ordered groups** — send multi-part messages that are always delivered in sequence
- **Dedup keys** — collapse duplicate notifications (e.g. "shop low on stock" x50 becomes one notice)
- **Delivery receipts** — opt-in ack callbacks and durable delivery history
- **Cancel / edit** — retract or update queued messages before they're delivered
- **Proxy delivery** — optional Velocity module for proxy-level message delivery, and for proxy plugins that want to send
- **Write-buffer** — Redis-backed overflow when MariaDB is saturated; no message loss
- **Permission-based broadcast** — send to all online players with a permission, network-wide
- **Player exclusions** — exclude specific players from broadcasts (e.g. opt-out lists)
- **Admin commands** — `/pmstats`, `/pmpeek`, `/pmpurge`, `/pmcancel`

## Architecture

```
dogcraft-playermessager/
├── api/                 ← Interfaces only. Other plugins compile against this.
├── core/                ← Shared implementation: storage, redis, routing, codec.
│                          Pure Java — no Bukkit or Velocity imports.
└── platform/
    ├── paper/           ← Paper plugin. Primary delivery target.
    └── velocity/        ← Velocity plugin. Optional; proxy-level delivery,
                           plus an opt-in send API for proxy plugins.
```

All backend servers are peers — they all subscribe to Redis and read/write the DB. No master.

## Requirements

- Java 21+
- Paper 1.21+ (or compatible fork)
- MariaDB 10.5+ (for `RETURNING` clause support)
- Redis 6+
- Velocity 3.3+ (optional, for proxy delivery)

## Setup

### 1. Create `server_id.conf`

Each backend server needs a `server_id.conf` file in its root directory:

```properties
name=lobby-1
uuid=550e8400-e29b-41d4-a716-446655440000
```

Generate a unique UUID per server. The name is for logging; the UUID is the identity.

The Velocity proxy does not use `server_id.conf` — it auto-generates `proxy_id.conf` in its plugin data directory on first start.

### 2. Configure the plugin

On first run, `plugins/Dogcraft-PlayerMessager/config.yml` is created:

```yaml
database:
  jdbc-url: jdbc:mariadb://db.internal:3306/dogcraft
  user: pm
  password: ${DC_PM_DB_PASSWORD}     # env var expansion supported
  pool-size: 8

redis:
  uri: redis://redis.internal:6379/0
  password: ${DC_PM_REDIS_PASSWORD}

defaults:
  message-ttl: 30d
  presence-ttl: 90s
  heartbeat-interval: 30s
  drain-batch-size: 50
  claim-lease: 30s
  delivery-log-retention: 30d
  write-buffer-max: 10000
  write-buffer-key-ttl: 24h

rate-limits:
  default: 50/sec
  per-source:
    friends-plugin: 200/sec
    mail-plugin: 20/sec
```

The schema is created automatically on first startup.

### 3. Deploy

- Drop the Paper shadow JAR into `plugins/` on every backend server.
- (Optional) Drop the Velocity shadow JAR into `plugins/` on the proxy.
- If Redis is unreachable, the plugin falls back to single-server mode automatically.

## API Usage

### Add the dependency

**Gradle (Kotlin DSL):**
```kotlin
repositories {
    maven("https://repo.dogcraft.net/releases")
}

dependencies {
    compileOnly("net.dogcraft:DogcraftPlayerMessager-API:0.1.3-d8337d3-indev")
}
```

**Gradle (Groovy):**
```groovy
repositories {
    maven { url = 'https://repo.dogcraft.net/releases' }
}

dependencies {
    compileOnly 'net.dogcraft:DogcraftPlayerMessager-API:0.1.3-d8337d3-indev'
}
```

Add `Dogcraft-PlayerMessager` as a `depend` or `softdepend` in your `plugin.yml`:
```yaml
depend:
  - Dogcraft-PlayerMessager
```

### Getting the API handle

`PlayerMessager` is the entry point on both platforms. Call `as(senderId)` to get a `MessagerHandle` scoped to your plugin. The sender ID is a trust boundary — plugins sharing the same sender ID can cancel each other's messages.

#### On Paper

Retrieved from Bukkit's service manager:

```java
import net.dogcraft.playermessager.api.PlayerMessager;
import net.dogcraft.playermessager.api.MessagerHandle;

public class MyPlugin extends JavaPlugin {

    private MessagerHandle pm;

    @Override
    public void onEnable() {
        PlayerMessager api = getServer().getServicesManager().load(PlayerMessager.class);
        if (api == null) {
            getLogger().severe("PlayerMessager not found!");
            return;
        }
        // The sender ID scopes your messages. Use your plugin name.
        pm = api.as(getName());
    }
}
```

#### On Velocity

Velocity has no service manager, so the plugin instance itself implements `PlayerMessager`. Declare a dependency and cast it:

```java
import com.velocitypowered.api.plugin.Dependency;
import com.velocitypowered.api.plugin.Plugin;
import com.velocitypowered.api.plugin.PluginContainer;
import net.dogcraft.playermessager.api.MessagerHandle;
import net.dogcraft.playermessager.api.PlayerMessager;

@Plugin(id = "myplugin",
        dependencies = @Dependency(id = "dogcraft-playermessager"))
public class MyPlugin {

    private MessagerHandle pm;

    @Subscribe
    public void onProxyInitialize(ProxyInitializeEvent event) {
        PlayerMessager api = (PlayerMessager) proxy.getPluginManager()
                .getPlugin("dogcraft-playermessager")
                .flatMap(PluginContainer::getInstance)
                .orElse(null);
        if (api == null) {
            logger.error("PlayerMessager not found!");
            return;
        }
        pm = api.as("MyPlugin");
    }
}
```

You only need the API jar on your classpath — not the Velocity shadow JAR.

**The proxy send API is opt-in.** By default the Velocity module is delivery-only and `as()` throws `IllegalStateException`. To enable sending, uncomment the `database:` section in `plugins/dogcraft-playermessager/config.yml` on the proxy and point it at the same database the backends use. Use `@Dependency(id = "...", optional = true)` plus a try/catch if you want to degrade gracefully when it isn't configured.

**Routing differences when sending from the proxy:**

- The proxy never delivers to players itself unless you ask for it. A normal `send()` is routed to whichever backend the player is on, so `TITLE`/`SUBTITLE` and everything else behave exactly as they would from a backend.
- Set `deliverViaProxy(true)` (or `viaProxy` on `sendToPermission`) to have the proxy deliver directly. That path still downgrades `TITLE`/`SUBTITLE` to chat.
- Offline queueing, dedup, cancel/update, and delivery receipts all work identically — they go through the shared database.
- The proxy does not run schema migrations. Start a Paper backend at least once before enabling the proxy's database section.

---

## API Reference

### MessagerHandle

The primary interface for sending messages. All methods return `CompletableFuture` for async operation.

#### Direct messaging

| Method | Description |
|--------|-------------|
| `send(MessageRequest request)` | Send a fully configured message request |
| `send(UUID recipient, Component content)` | Send a simple message to a player |
| `send(UUID recipient, Component prefix, Component content)` | Send a message with a prefix to a player |

All `send()` methods return `CompletableFuture<SendResult>`.

**Simple message:**
```java
pm.send(playerUuid, Component.text("Hello from MyPlugin!"));
```

**With a prefix:**
```java
Component prefix = Component.text("[Shop] ", NamedTextColor.GOLD);
Component body = Component.text("You sold 3 stacks of Oak Logs for $400");
pm.send(playerUuid, prefix, body);
```

**Multi-recipient fan-out** — one request ID, one DB batch:
```java
pm.send(MessageRequest.builder()
    .recipients(List.of(player1, player2, player3))
    .prefix(Component.text("[Announcement] "))
    .content(Component.text("Server restart in 5 minutes"))
    .build());
```

#### Ordered groups

```java
CompletableFuture<SendResult> sendGroup(UUID recipient, Component prefix, List<Component> contents)
```

Sends multiple messages guaranteed to be delivered in sequence, even if the player is offline and logs into a different server.

```java
List<Component> pages = List.of(
    Component.text("Page 1 of 3: ..."),
    Component.text("Page 2 of 3: ..."),
    Component.text("Page 3 of 3: ...")
);
pm.sendGroup(playerUuid, Component.text("[Help] "), pages);
```

#### Permission-based broadcast

Send to all online players across the network who have a specific permission node. Online-only — no offline queueing. Each server checks permissions locally. Returns the number of players delivered to on the local server (remote counts are not available synchronously).

| Method | Description |
|--------|-------------|
| `sendToPermission(String permission, Component content)` | Broadcast to players with permission (CHAT type) |
| `sendToPermission(String permission, Component prefix, Component content)` | Broadcast with prefix (CHAT type) |
| `sendToPermission(String permission, Component content, MessageType type)` | Broadcast with specific message type |
| `sendToPermission(String permission, Component prefix, Component content, MessageType type)` | Broadcast with prefix and message type |
| `sendToPermission(String permission, Component prefix, Component content, MessageType type, boolean viaProxy)` | Broadcast with proxy routing control |
| `sendToPermission(String permission, Component prefix, Component content, MessageType type, Set<UUID> excludedPlayers)` | Broadcast excluding specific players |
| `sendToPermission(String permission, Component prefix, Component content, MessageType type, boolean viaProxy, Set<UUID> excludedPlayers)` | Full control: proxy routing + exclusions |

**Basic broadcast:**
```java
pm.sendToPermission("shop.notify", Component.text("Flash sale starting now!"));
```

**With a prefix:**
```java
pm.sendToPermission("staff.alerts",
    Component.text("[Staff] ", NamedTextColor.RED),
    Component.text("Player reported in lobby-2"));
```

**As action bar:**
```java
pm.sendToPermission("vip.alerts",
    Component.text("Double XP weekend is live!"),
    MessageType.ACTIONBAR);
```

**Proxy-routed broadcast:** Route the broadcast through the Velocity proxy instead of having every backend check permissions. Useful when the proxy has permission data (e.g. LuckPerms on Velocity).

```java
pm.sendToPermission("staff.alerts",
    Component.text("[Staff] ", NamedTextColor.RED),
    Component.text("Server restart in 5 minutes"),
    MessageType.CHAT,
    true);  // viaProxy = true
```

**Excluding specific players (opt-out support):** Pass a `Set<UUID>` of players who should not receive the broadcast. The exclusion list is applied on every server in the network.

```java
// Get your opt-out list from your plugin's config/database
Set<UUID> optedOut = myPlugin.getOptedOutPlayers();

pm.sendToPermission("shop.notify",
    Component.text("[Shop] ", NamedTextColor.GOLD),
    Component.text("Flash sale starting now!"),
    MessageType.CHAT,
    optedOut);
```

**Both proxy routing and exclusions:**
```java
pm.sendToPermission("staff.alerts",
    Component.text("[Staff] ", NamedTextColor.RED),
    Component.text("Server restart in 5 minutes"),
    MessageType.CHAT,
    true,       // viaProxy
    optedOut);  // excluded players
```

#### Cancel and update

| Method | Description |
|--------|-------------|
| `cancel(UUID requestId)` | Cancel all pending messages under a request ID. Only your own messages (same sender ID) can be cancelled. Returns the count of rows cancelled (0 = already delivered). |
| `updateContent(UUID requestId, Component newContent)` | Update the content of pending (not yet delivered) messages. |

```java
UUID requestId = UUID.randomUUID();

pm.send(MessageRequest.builder()
    .requestId(requestId)
    .recipient(playerUuid)
    .content(Component.text("This offer expires soon!"))
    .build());

// Later, if the offer is retracted:
pm.cancel(requestId).thenAccept(count ->
    getLogger().info("Cancelled " + count + " pending messages"));

// Or update the content:
pm.updateContent(requestId, Component.text("Updated: new price is $500"))
    .thenAccept(count -> getLogger().info("Updated " + count + " pending messages"));
```

#### Delivery receipts

| Method | Description |
|--------|-------------|
| `addDeliveryListener(DeliveryListener listener)` | Register a push callback fired when a message with `requestReceipt=true` is delivered |
| `removeDeliveryListener(DeliveryListener listener)` | Unregister a delivery listener |
| `getDeliveryHistory(UUID requestId)` | Pull durable delivery records for a request (survives restarts) |

**Push listener:**
```java
pm.addDeliveryListener(receipt -> {
    getLogger().info("Delivered " + receipt.getRequestId()
        + " to " + receipt.getRecipientId()
        + " via " + receipt.getDeliveredBy());
});
```

**Pull history:**
```java
pm.getDeliveryHistory(requestId).thenAccept(records -> {
    for (DeliveryRecord r : records) {
        getLogger().info(r.getRecipientId() + " delivered at " + r.getAt());
    }
});
```

---

### MessageRequest

Full-control message builder. All fields except `content` are optional.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `requestId` | `UUID` | random | Unique ID for the request. Set this if you need to cancel/update later. |
| `recipients` | `List<UUID>` | — | One or more player UUIDs to send to. Use `.recipient(uuid)` for single, `.recipients(list)` for multiple. |
| `prefix` | `Component` | `null` | Prepended to the content on delivery. Useful for plugin branding like `[Shop]`. |
| `content` | `Component` | **required** | The message body. |
| `type` | `MessageType` | `CHAT` | How the message is displayed. See MessageType below. |
| `ttl` | `Duration` | `30d` (config) | Time-to-live. Message expires and is not delivered after this duration. |
| `queueIfOffline` | `boolean` | `true` | If `false`, the message is dropped (REJECTED) when the player is offline instead of being queued. |
| `dedupKey` | `String` | `null` | Deduplication key. If a pending message with the same key exists, the new one is silently accepted without creating a duplicate. |
| `groupId` | `UUID` | `null` | Groups messages for ordered delivery. Set automatically by `sendGroup()`. |
| `sequence` | `int` | `0` | Position within a group (1-based). Set automatically by `sendGroup()`. |
| `groupSize` | `int` | `0` | Total messages in the group. Set automatically by `sendGroup()`. |
| `requestReceipt` | `boolean` | `false` | If `true`, fires `DeliveryListener` callbacks and writes to the durable delivery log on delivery. |
| `deliverViaProxy` | `boolean` | `false` | If `true`, routes delivery through the Velocity proxy instead of backend servers. |

```java
pm.send(MessageRequest.builder()
    .recipient(playerUuid)
    .prefix(Component.text("[Mail] "))
    .content(Component.text("You have new mail!"))
    .type(MessageType.CHAT)
    .ttl(Duration.ofDays(7))
    .queueIfOffline(true)
    .dedupKey("mail:" + playerUuid)
    .requestReceipt(true)
    .build());
```

---

### MessageType

Controls how the message is displayed to the player.

| Value | Description |
|-------|-------------|
| `CHAT` | Standard chat message. Default for all methods. |
| `ACTIONBAR` | Displayed in the action bar above the hotbar. Fades after a few seconds. |
| `TITLE` | Large centered title text. |
| `SUBTITLE` | Smaller text below the title. |

```java
import net.dogcraft.playermessager.api.MessageType;

// Action bar
pm.send(MessageRequest.builder()
    .recipient(playerUuid)
    .content(Component.text("Saving..."))
    .type(MessageType.ACTIONBAR)
    .queueIfOffline(false)
    .build());

// Title
pm.send(MessageRequest.builder()
    .recipient(playerUuid)
    .content(Component.text("Victory!", NamedTextColor.GOLD))
    .type(MessageType.TITLE)
    .build());

// Subtitle (shown below title)
pm.send(MessageRequest.builder()
    .recipient(playerUuid)
    .content(Component.text("You completed the challenge"))
    .type(MessageType.SUBTITLE)
    .build());
```

Note: On Velocity (proxy delivery), `TITLE` and `SUBTITLE` are delivered as `CHAT` since the proxy API does not support title packets. `ACTIONBAR` is supported on both Paper and Velocity.

---

### SendResult

Returned by all `send()` methods.

| Field | Type | Description |
|-------|------|-------------|
| `requestId` | `UUID` | The request ID (matches `MessageRequest.requestId`) |
| `perRecipient` | `Map<UUID, ImmediateStatus>` | Per-recipient delivery status |
| `at` | `Instant` | Timestamp of the result |

---

### ImmediateStatus

Per-recipient status returned in `SendResult`.

| Value | Description |
|-------|-------------|
| `ACCEPTED` | Message was delivered locally, sent to a remote server, or queued in the database. |
| `BUFFERED` | Database was saturated; message was written to the Redis write-buffer. It will be drained to the DB automatically. |
| `REJECTED` | Message was dropped. Causes: player offline with `queueIfOffline=false`, rate limit exceeded, or system error. |

---

### DeliveryReceipt

Passed to `DeliveryListener` callbacks when a message with `requestReceipt=true` is delivered.

| Field | Type | Description |
|-------|------|-------------|
| `requestId` | `UUID` | The original request ID |
| `messageId` | `UUID` | Unique ID for this specific message |
| `recipientId` | `UUID` | The player who received the message |
| `status` | `DeliveryStatus` | Delivery outcome |
| `at` | `Instant` | When delivery occurred |
| `deliveredBy` | `String` | Server UUID that delivered the message |

---

### DeliveryRecord

Returned by `getDeliveryHistory()`. Same fields as `DeliveryReceipt`.

---

### DeliveryStatus

| Value | Description |
|-------|-------------|
| `DELIVERED` | Message was successfully delivered to the player |
| `EXPIRED` | Message TTL elapsed before delivery |
| `CANCELLED` | Message was cancelled via `cancel()` |
| `FAILED` | Delivery failed due to a system error |

---

### MessageFormat

Convenience helpers for creating `Component` objects without importing Adventure directly.

| Method | Description |
|--------|-------------|
| `MessageFormat.miniMessage(String)` | Parse MiniMessage format (e.g. `<gold>[Shop]</gold>`) |
| `MessageFormat.legacy(String)` | Parse legacy `&` color codes (e.g. `&6[Shop] &aHello`) |
| `MessageFormat.plain(String)` | Plain text with no formatting |

```java
import net.dogcraft.playermessager.api.MessageFormat;

pm.send(playerUuid,
    MessageFormat.miniMessage("<gold>[Shop]</gold> "),
    MessageFormat.miniMessage("<green>You sold 3 stacks for $400</green>"));

pm.send(playerUuid, MessageFormat.legacy("&6[Shop] &aYou sold 3 stacks"));

pm.send(playerUuid, MessageFormat.plain("Hello!"));
```

---

### PlayerMessager

Entry point interface. Retrieve via Bukkit's service manager.

| Method | Description |
|--------|-------------|
| `as(String senderId)` | Get a `MessagerHandle` scoped to a sender ID. By convention, pass your plugin name. |

---

## Complete Plugin Example

```java
package net.dogcraft.exampleplugin;

import net.dogcraft.playermessager.api.*;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.plugin.java.JavaPlugin;

import java.util.Set;
import java.util.UUID;

public class ShopNotifier extends JavaPlugin implements Listener {

    private MessagerHandle pm;

    @Override
    public void onEnable() {
        PlayerMessager api = getServer().getServicesManager().load(PlayerMessager.class);
        if (api == null) {
            getLogger().severe("PlayerMessager not found! Disabling.");
            getServer().getPluginManager().disablePlugin(this);
            return;
        }

        pm = api.as(getName());
        getServer().getPluginManager().registerEvents(this, this);

        // Optional: listen for delivery confirmations
        pm.addDeliveryListener(receipt ->
            getLogger().info("Notified " + receipt.getRecipientId()));
    }

    /**
     * Called by the shop system when a player's shop sells an item.
     * The shop owner might be offline or on another server.
     */
    public void notifyShopSale(UUID shopOwner, String itemName,
                                int quantity, double revenue) {
        Component prefix = Component.text("[Shop] ", NamedTextColor.GOLD);
        Component body = Component.text(
            String.format("Sold %dx %s for $%.2f", quantity, itemName, revenue),
            NamedTextColor.GREEN);

        pm.send(shopOwner, prefix, body);
    }

    /**
     * Called when stock is low. Uses dedup so the owner only sees one notice
     * per shop, no matter how many sales drain the stock.
     */
    public void notifyLowStock(UUID shopOwner, String shopId) {
        pm.send(MessageRequest.builder()
            .recipient(shopOwner)
            .prefix(Component.text("[Shop] ", NamedTextColor.GOLD))
            .content(Component.text("Your shop is running low on stock!",
                NamedTextColor.YELLOW))
            .dedupKey("shop:" + shopId + ":lowstock")
            .build());
    }

    /**
     * Broadcast a flash sale to all players with shop.notify permission,
     * but respect opt-out preferences.
     */
    public void announceFlashSale(Set<UUID> optedOutPlayers) {
        pm.sendToPermission("shop.notify",
            Component.text("[Shop] ", NamedTextColor.GOLD),
            Component.text("Flash sale starting now!", NamedTextColor.GREEN),
            MessageType.CHAT,
            optedOutPlayers);
    }
}
```

## Admin Commands

All commands require the `playermessager.admin` permission (default: op).

| Command | Description |
|---------|-------------|
| `/pmstats` | Queue depth, delivery counts, write-buffer depth, error counts |
| `/pmpeek <player>` | List pending messages for a player |
| `/pmpurge <player>` | Delete all pending messages for a player |
| `/pmcancel <requestId>` | Cancel a message by request UUID (bypasses sender ID check) |

## Building

```bash
./gradlew clean build
```

Output JARs are in `target/`:
- `paper-<version>.jar` — deploy to Paper servers
- `velocity-<version>.jar` — deploy to Velocity proxy (optional)

## Publishing

```bash
./gradlew publish
```

Publishes to `repo.dogcraft.net/releases`:
- `net.dogcraft:DogcraftPlayerMessager-API` — API jar for downstream plugins
- `net.dogcraft:DogcraftPlayerMessager` — Paper shadow JAR
- `net.dogcraft:DogcraftPlayerMessager-Velocity` — Velocity shadow JAR

## License

Internal Dogcraft project.
