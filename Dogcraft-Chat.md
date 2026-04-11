# Dogcraft-Chat

A multi-module Minecraft plugin suite for **Paper** and **Velocity** that provides cross-server chat forwarding, custom chat formatting, private messaging, group messaging, staff chat, and socialspy.

## Overview

Dogcraft-Chat solves the problem of chat isolation on multi-server Minecraft networks. Players on different backend servers behind a Velocity proxy can see each other's chat messages seamlessly. The plugin preserves chat signing on the same server while using disguised (profileless) chat packets for cross-server forwarding, ensuring messages render identically to normal player chat.

### How It Works

- **Paper plugin** formats chat messages with server name, LuckPerms prefix, and player name using MiniMessage
- **Velocity plugin** intercepts signed player chat packets via Netty pipeline injection and re-broadcasts them as profileless chat packets to players on other backend servers
- Same-server chat remains fully signed; cross-server messages render identically but without a signature (no "Chat validation error")

The Velocity plugin works standalone — all commands, chat forwarding, logging, and socialspy are handled entirely on the proxy. The Paper plugin is only needed for custom chat formatting with LuckPerms prefixes and local chat ignore rendering.

### Supported Versions

- Minecraft 1.21 through 1.21.11
- Paper 1.21+
- Velocity 3.5.0+

## Features

- **Cross-server chat forwarding** — Messages sent on one server appear on all others
- **Custom chat formatting** — `[server_name] <prefix> <username>: <message>` with hex color support
- **LuckPerms integration** — Prefixes rendered via MiniMessage (supports gradients, hex colors)
- **Private messaging** — `/msg`, `/reply` with hover/click events
- **Named group messaging** — Create, manage, and message named groups with member hover display
- **Staff chat** — Dedicated staff communication channel
- **Player ignore** — Ignore players to hide their messages as `[Ignored]` (hover to reveal). Persists across restarts. Synced from Velocity to Paper via plugin messaging.
- **SocialSpy** — Staff can monitor private and group messages (on by default, toggleable)
- **Chat logging** — All messages logged to daily rotating files
- **AI toxicity detection** — Optional Detoxify ONNX model scans all messages, alerts staff in-game and via Discord webhook (disabled by default, per-category thresholds)

## Commands

### Private Messaging

| Command | Aliases | Description |
|---------|---------|-------------|
| `/msg <player> <message>` | `/message`, `/tell`, `/whisper`, `/w` | Send a private message |
| `/reply <message>` | `/r` | Reply to the last private or group message |

### Group Messaging

| Command | Aliases | Description |
|---------|---------|-------------|
| `/gmsg create <name> <player1> [player2] ...` | `/groupmsg` | Create a named group with the listed players |
| `/gmsg add <name> <player>` | `/groupmsg` | Add a player to an existing group |
| `/gmsg leave <name>` | `/groupmsg` | Leave a group (tab-completes your groups) |
| `/gmsg [group_name] <message>` | `/groupmsg` | Send a message to a specific group |
| `/gmsg <message>` | `/groupmsg` | Send a message to your last active group |

Players can be in multiple groups simultaneously. `/reply` sends to whichever group or private conversation was most recently active. Hovering over group messages shows all members. Groups auto-dissolve when only one member remains. Group names cannot be `create`, `add`, or `leave`.

**Chat format:** `[Group] [group_name] player_name: message`

### Staff & Utility

| Command | Aliases | Description |
|---------|---------|-------------|
| `/staffchat <message>` | `/sc` | Send a message to staff chat |
| `/socialspy` | `/spy` | Toggle socialspy on or off |
| `/ignore <player>` | `/block` | Toggle ignoring a player |
| `/ignore list` | `/block list` | Show your ignore list |

## Permissions

| Permission | Description | Default |
|------------|-------------|---------|
| `dogcraft.staffchat` | Access to staff chat (`/sc`) | op |
| `dogcraft.socialspy` | See private and group messages between other players | op |
| `dogcraft.socialspy.exempt` | Exempt from being seen by socialspy | false |
| `dogcraft.ignore.bypass` | Messages always shown even if sender is ignored | op |
| `dogcraft.moderation.alerts` | Receive in-game toxicity alerts | op |

## AI Moderation (Detoxify)

Dogcraft-Chat includes optional AI-powered toxicity detection using the [Detoxify](https://github.com/unitaryai/detoxify) ONNX model. When enabled, all messages (public chat, private messages, group messages, staff chat) are scanned asynchronously. Toxic messages are **not blocked** — they trigger alerts to online staff and optionally send a Discord webhook.

### Setup

1. Set `enabled=true` in `plugins/dogcraft-chat/moderation.properties`
2. On first enable, the model files (~100MB) are auto-downloaded from HuggingFace
3. Optionally set `discord-webhook-url` for Discord alerts

### Configuration (`moderation.properties`)

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `false` | Enable/disable toxicity detection |
| `alert-threshold` | `0.7` | Score threshold (0.0-1.0) to trigger alerts |
| `model-path` | `models/toxic-bert-quantized.onnx` | Path to ONNX model relative to plugin data dir |
| `tokenizer-path` | `models/tokenizer.json` | Path to tokenizer relative to plugin data dir |
| `discord-webhook-url` | (empty) | Discord webhook URL for alerts |

### Alert Format

**In-game** (staff with `dogcraft.moderation.alerts`):
```
[Moderation] [Public] PlayerName — toxic=0.92, insult=0.85
[Moderation] [DM] PlayerName — toxic=0.88, obscene=0.76
[Moderation] [Group:staff] PlayerName — threat=0.91
```
Hover over the player name to see all category scores.

**Discord webhook**: Embed with player name, server, channel, message content, and all toxicity scores.

### Categories

The model scores messages across 6 categories: `toxic`, `severe_toxic`, `obscene`, `threat`, `insult`, `identity_hate`.

## Installation

### Requirements

- Velocity 3.5.0+ proxy
- Paper 1.21+ backend servers (optional — required for custom chat formatting and same-server ignore rendering)
- LuckPerms installed on both Paper and Velocity
- Java 21+

### Setup

1. Build the project with Maven:
   ```
   mvn clean package
   ```

2. Copy `paper/target/Dogcraft-Chat-Paper-1.0-SNAPSHOT.jar` to each Paper server's `plugins/` folder

3. Copy `velocity/target/Dogcraft-Chat-Velocity-1.0-SNAPSHOT.jar` to the Velocity proxy's `plugins/` folder

4. Ensure LuckPerms is installed on both Velocity and all Paper backends, connected to the same storage backend so permissions sync across the network

5. Restart all servers

### Chat Format

Messages are formatted as:

```
[server_name] <luckperms_prefix> <username>: <message>
```

- Server name is displayed in `#147598` (teal)
- LuckPerms prefixes are deserialized via MiniMessage, supporting gradients and hex colors
- Server name is resolved automatically via the BungeeCord plugin messaging channel

## Chat Logging

All messages are logged to `plugins/dogcraft-chat/logs/chat-YYYY-MM-DD.log` on the Velocity proxy with the following format:

```
[2026-03-20 14:32:01] [CHAT] [survival] Steve: Hello everyone!
[2026-03-20 14:32:05] [MSG] Steve -> Alex: Hey, want to trade?
[2026-03-20 14:32:10] [GROUP] [staff] Steve (members: Steve, Alex, Notch): Let's meet at spawn
[2026-03-20 14:32:15] [SC] [survival] Steve: Griefer spotted at coords 100, 64, -200
```

## Project Structure

```
Dogcraft-Chat/
├── pom.xml                          # Parent POM
├── common/                          # Shared module
│   └── src/main/java/.../DogcraftChatCommon.java
├── paper/                           # Paper backend plugin
│   └── src/main/java/
│       └── .../paper/
│           ├── DogcraftChatPaper.java       # Main plugin, server name resolution
│           └── listeners/
│               └── ChatListener.java        # Chat formatting with LuckPerms
├── velocity/                        # Velocity proxy plugin
│   └── src/main/java/
│       └── .../velocity/
│           ├── DogcraftChatVelocity.java    # Main plugin, event handling
│           ├── ChatLogger.java              # File-based chat logging
│           ├── IgnoreManager.java           # Player ignore with persistence
│           ├── SocialSpyManager.java        # SocialSpy toggle state
│           ├── commands/
│           │   ├── MessageCommand.java      # /msg with socialspy
│           │   ├── ReplyCommand.java        # /reply (private + group)
│           │   ├── GroupMessageCommand.java # /gmsg with named groups
│           │   ├── StaffChatCommand.java    # /sc
│           │   ├── SocialSpyCommand.java    # /socialspy toggle
│           │   └── IgnoreCommand.java      # /ignore toggle + list
│           ├── moderation/
│           │   ├── ModerationConfig.java    # Config loader
│           │   ├── ModerationHandler.java   # Alert coordinator
│           │   ├── ToxicityDetector.java    # ONNX model inference
│           │   ├── ToxicityResult.java      # Score container
│           │   └── DiscordWebhook.java      # Webhook sender
│           └── handler/
│               └── ChatForwardingHandler.java  # Netty packet interception
```

## Technical Details

### Cross-Server Chat Forwarding

The Velocity plugin injects a Netty `ChannelDuplexHandler` into each player's client connection pipeline. This handler:

1. Intercepts outbound **Player Chat Message** packets (signed) by matching version-specific packet IDs
2. Parses the packet to extract the decorated message component, chat type, and sender name
3. Constructs a **Disguised Chat Message** (profileless) packet with the same visual content
4. Sends the profileless packet to all players on other backend servers

This approach preserves chat signing for same-server players while allowing cross-server messages to render identically without triggering signature validation errors.

### Version-Specific Packet IDs

The handler maintains mappings for both `player_chat` and `profileless_chat` packet IDs across all supported protocol versions, and accounts for format differences (e.g., the sequential message counter added in 1.21.5+).

### Player Ignore

Ignore data is managed on Velocity (`ignores.json`) and synced to Paper backends via the `dogcraft:ignore` plugin messaging channel. This allows:

- **Local chat** (same server): Paper's `ChatRenderer` checks the ignore list per viewer and renders `[Ignored]` with a hover event showing the full message. The signed chat packet is still delivered to all players, preserving the signing chain — only the decoration changes for the ignoring viewer.
- **Cross-server chat**: The Velocity `ChatForwardingHandler` skips sending the profileless packet entirely to players who have ignored the sender.
- **Private messages**: Velocity shows `[Ignored]` with hover showing the full message to the ignoring player.
- **Group messages**: Shows `[Group] [name] [Ignored]` — hover on `[Ignored]` reveals `username: message`, hover on `[Group]`/`[name]` still shows the member list.
- **Staff chat**: Not affected by ignore (staff with `dogcraft.staffchat` typically also have `dogcraft.ignore.bypass`).

Players with the `dogcraft.ignore.bypass` permission are never affected by ignore — their messages always display normally.
