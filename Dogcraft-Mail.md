# DogcraftMail

A Velocity proxy plugin that provides an in-game private messaging (mail) system for Minecraft servers. Players can send, receive, read, and manage mail — with support for blocking, moderation spy mode, pagination, and Discord webhook notifications.

Built for the [Dogcraft Server](https://dogcraft.net/).

## Features

- Send and receive private mail between players
- Inbox, outbox, and unread views with pagination
- Block/unblock players from sending you mail
- Moderation spy mode to monitor all mail activity
- Login notifications for unread messages
- Discord webhook integration for logging mail to a channel
- Fully configurable messages with MineDown formatting
- MySQL-backed persistence with HikariCP connection pooling
- Async database operations to avoid blocking the proxy

## Requirements

- **Velocity** 3.2.0+ proxy server
- **MySQL** database
- **Java** 17+

## Installation

1. Build the plugin with Gradle: `./gradlew build`
2. Copy the output JAR from `build/libs/` to your Velocity `plugins/` directory.
3. Start the proxy to generate the default `config.yml`.
4. Edit `plugins/dogcraftmail/config.yml` with your MySQL credentials.
5. Restart the proxy.

## Commands

All commands are subcommands of `/mail`.

### `/mail` or `/mail unread [page]`

View your unread messages. This is the default when running `/mail` with no arguments. Results are paginated — provide a page number to navigate.

**Example:** `/mail unread 2` — View page 2 of your unread mail.

---

### `/mail list [page]`

View all messages you have received (both read and unread). Paginated.

**Example:** `/mail list` — View your full inbox.

---

### `/mail outbox [page]`

View all messages you have sent. Paginated.

**Example:** `/mail outbox` — View your sent mail.

---

### `/mail send <player> <message>`

Send a mail message to another player. The player does not need to be online. Messages have a maximum length of 255 characters.

**Example:** `/mail send Steve Hey, want to build together later?`

---

### `/mail read <id>`

Read a specific message by its ID number and mark it as read.

**Example:** `/mail read 42` — Read message #42.

---

### `/mail clear`

Mark all messages in your inbox as read.

**Example:** `/mail clear`

---

### `/mail block` or `/mail block list [page]`

View a list of players you have blocked. Paginated.

**Example:** `/mail block list`

---

### `/mail block add <player>`

Block a player from sending you mail. Their existing and future messages will be hidden from your inbox. Moderators with spy permissions can still see blocked messages.

**Example:** `/mail block add Griefer123`

---

### `/mail block remove <player>`

Unblock a player. You will once again see messages they have sent you.

**Example:** `/mail block remove Griefer123`

---

### `/mail about`

Display plugin information (version, authors, links).

## Permissions

| Permission | Description |
|---|---|
| `dogcraftmail.command.mail.spy` | Allows the user to read any player's mail and receive a notification whenever mail is sent on the server. |

## Configuration

The plugin generates a `config.yml` on first run. Key sections:

### Database

```yaml
database:
  credentials:
    host: localhost
    port: 3306
    database: DogcraftMail
    username: root
    password: pa55w0rd
    parameters: "?autoReconnect=true&useSSL=false&useUnicode=true&characterEncoding=UTF-8"
  connection_pool:
    size: 12
    idle: 12
    lifetime: 1800000
    keepalive: 30000
    timeout: 20000
  tables:
    mail: dogcraftmail_users
    mailbox: dogcraftmail_messages
```

### Discord Webhook

Sends an embed to a Discord channel whenever mail is sent.

```yaml
webhook:
  enabled: false
  url: "https://discordapp.com/api/webhooks/..."
  username: "Dogcraft Mail"
  avatar_url: "https://dogcraft.net/wiki/images/9/9f/Dogcraft_Logo_White_on_Red.png"
```

Set `enabled` to `true` and provide your webhook URL. The embed will include the sender, recipient, message text, delivery status (e.g. whether the recipient blocked the sender), and a timestamp.

### Locales

All player-facing messages are customizable under the `locales` section using [MineDown](https://github.com/Phoenix616/MineDown) formatting. This includes messages for sending, receiving, errors, notifications, and list items.

### Other

```yaml
enable_command: true  # Set to false to disable the /mail command entirely
```

## Building

```bash
./gradlew build
```

The shaded JAR will be output to `build/libs/`.

## License

Apache License 2.0 

## Authors

- [William278](https://william278.net/)
- [Ironboundred](https://dogcraft.net/)
