# Dogcraft-Chat

A multi-module Minecraft plugin suite for **Paper** and **Velocity** that provides cross-server chat forwarding, custom chat formatting, private messaging, group messaging, staff chat, and socialspy.

## Overview

Dogcraft-Chat solves the problem of chat isolation on multi-server Minecraft networks. Players on different backend servers behind a Velocity proxy can see each other's chat messages seamlessly. The plugin preserves chat signing on the same server while using disguised (profileless) chat packets for cross-server forwarding, ensuring messages render identically to normal player chat.

### How It Works

- **Paper plugin** formats chat messages with server name, LuckPerms prefix, and player name using MiniMessage
- **Velocity plugin** intercepts signed player chat packets via Netty pipeline injection and re-broadcasts them as profileless chat packets to players on other backend servers
- Same-server chat remains fully signed; cross-server messages render identically but without a signature (no "Chat validation error")

### Supported Versions

- Minecraft 1.21 through 1.21.11
- Paper 1.21+
- Velocity 3.5.0+

## Features

- **Cross-server chat forwarding** — Messages sent on one server appear on all others
- **Custom chat formatting** — `[server_name] <prefix> <username>: <message>` with hex color support
- **LuckPerms integration** — Prefixes rendered via MiniMessage (supports gradients, hex colors)
- **Private messaging** — `/msg`, `/reply` with hover/click events
- **Group messaging** — Create ad-hoc groups, hover to see all members
- **Staff chat** — Dedicated staff communication channel
- **SocialSpy** — Staff can monitor private and group messages (on by default, toggleable)
- **Chat logging** — All messages logged to daily rotating files

## Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `/msg <player> <message>` | `/message`, `/tell`, `/whisper`, `/w` | Send a private message |
| `/reply <message>` | `/r` | Reply to the last private message |
| `/gmsg <player1> <player2> ...` | `/groupmsg` | Create a group with the listed players |
| `/gmsg <message>` | `/groupmsg` | Send a message to your current group |
| `/gmsg leave` | `/groupmsg leave` | Leave your current group |
| `/staffchat <message>` | `/sc` | Send a message to staff chat |
| `/socialspy` | `/spy` | Toggle socialspy on or off |

## Permissions

| Permission | Description | Default |
|------------|-------------|---------|
| `dogcraft.staffchat` | Access to staff chat (`/sc`) | op |
| `dogcraft.socialspy` | See private and group messages between other players | op |
| `dogcraft.socialspy.exempt` | Exempt from being seen by socialspy | false |

## Installation

### Requirements

- Velocity 3.5.0+ proxy
- Paper 1.21+ backend servers
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
[2026-03-20 14:32:10] [GROUP] Steve (members: Steve, Alex, Notch): Let's meet at spawn
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
│           ├── SocialSpyManager.java        # SocialSpy toggle state
│           ├── commands/
│           │   ├── MessageCommand.java      # /msg with socialspy
│           │   ├── ReplyCommand.java        # /reply
│           │   ├── GroupMessageCommand.java # /gmsg with hover + socialspy
│           │   ├── StaffChatCommand.java    # /sc
│           │   └── SocialSpyCommand.java    # /socialspy toggle
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
