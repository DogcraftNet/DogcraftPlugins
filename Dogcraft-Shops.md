# Dogcraft-Shops

A chest-based shop plugin for Paper 1.21+. Place a chest, hold an item, run a command, and your shop is live. Players right-click to buy with a clickable confirmation prompt. All money movement is handled through DogcraftEconomy.

## Requirements

- **Paper** 1.21 or later
- **Java** 21+
- **DogcraftEconomy** (required)
- **MySQL** or **SQLite** (SQLite by default, MySQL for shared databases)

## Installation

1. Drop `Dogcraft-Shops.jar` into your `plugins/` folder
2. Start the server once to generate `config.yml` and `id.conf`
3. Edit `plugins/Dogcraft-Shops/config.yml` if needed (see [Configuration](#configuration))
4. Restart the server

On first startup the plugin generates a unique server UUID in `plugins/Dogcraft-Shops/id.conf`. This identifies which server owns which shops when sharing a MySQL database across multiple servers.

---

## How To: Create a Shop

1. Place a **chest** where you want your shop
2. Fill the chest with the items you want to sell
3. **Hold one of the items** in your main hand
4. Look at the chest (within 5 blocks) and run:
   ```
   /shop create <price>
   ```
5. A confirmation prompt appears showing the creation fee. Click **[Confirm]** to pay and create the shop
6. A floating item display spawns above the chest showing what the shop sells

Your shop is now live. Other players can right-click the chest to purchase items.

### Restocking

**Sneak + right-click** your shop chest to open it normally and add more items.

---

## How To: Buy from a Shop

1. Find a shop (look for floating items above chests)
2. **Right-click** the chest
3. You'll see the item, price, and a confirmation prompt:
   ```
   Buy 1x Diamond for $50.00?
     [Confirm]    [Cancel]
   ```
4. Click **[Confirm]** to complete the purchase, or **[Cancel]** to back out
5. If you don't respond within 15 seconds, the purchase auto-cancels

The item moves from the chest to your inventory and the payment is processed through DogcraftEconomy.

---

## How To: Manage Your Shops

### Change the price
Look at your shop chest and run:
```
/shop setprice <new price>
```

### Open or close a shop
Temporarily disable purchases without removing the shop:
```
/shop toggle
```

### View shop details
Look at any shop chest and run:
```
/shop info
```
Owners see full details (stock count, coordinates, creation date). Other players see limited info.

### List all your shops
```
/shop list
```
Shows every shop you own with stock levels, prices, and status.

### View sales history
Look at your shop chest and run:
```
/shop sales
```
Paginated history showing what sold, when, and for how much. Navigate pages with:
```
/shop sales <page>
```

### Remove a shop
Look at your shop chest and run:
```
/shop remove
```
A confirmation prompt appears. Click **[Confirm Remove]** to permanently delete the shop and despawn the display entity. Breaking the chest also removes the shop.

---

## Commands

### Player Commands

| Command | Description |
|---------|-------------|
| `/shop create <price>` | Create a SELL shop for the item in your hand |
| `/shop remove` | Remove a shop (with confirmation) |
| `/shop setprice <price>` | Update the price of a shop |
| `/shop toggle` | Open or close a shop |
| `/shop info` | View shop details |
| `/shop list` | List all your shops |
| `/shop sales [page]` | View paginated sales history |
| `/shop confirm` | Confirm a pending purchase |
| `/shop cancel` | Cancel a pending purchase |

All `/shop` commands can also be used as `/s` (alias).

### Admin Commands

| Command | Description |
|---------|-------------|
| `/shopadmin reload` | Reload config and respawn all display entities |
| `/shopadmin remove <player>` | Force-remove all shops owned by a player |
| `/shopadmin inspect` | View detailed shop record (look at a chest) |

---

## Permissions

| Permission | Description | Default |
|-----------|-------------|---------|
| `dogcraftshops.create` | Create shops | All players |
| `dogcraftshops.use` | Purchase from shops | All players |
| `dogcraftshops.admin` | Admin commands (`/shopadmin`) | OP only |

---

## Notifications

- **Sale notifications**: When someone buys from your shop, you receive a chat message. If you're offline, notifications queue up and are delivered when you next log in.
- **Low stock alerts**: On login, you're warned if any of your shops have stock below the configured threshold (default: 5 items).

---

## Protections

- **Chest breaking**: Only the shop owner (or an admin) can break a shop chest. Breaking it removes the shop.
- **Explosions**: Shop chests are immune to entity and block explosions (TNT, creepers, beds, etc.).
- **Hoppers**: Items cannot be pulled from or pushed into shop chests by hoppers.
- **Display entities**: Floating item displays are tagged and cannot be killed by players.

---

## Configuration

`plugins/Dogcraft-Shops/config.yml`

| Setting | Default | Description |
|---------|---------|-------------|
| `shop-creation-fee` | `100.00` | Fee charged when creating a shop. Deposited to the server account. Set to `0` to disable. |
| `min-price` | `0.01` | Minimum allowed price per item |
| `low-stock-threshold` | `5` | Warn shop owners when stock drops to this level |
| `display-entity-height` | `1.2` | How far above the chest the floating item spawns (in blocks) |
| `display-entity-scale` | `0.6` | Scale of the floating ItemDisplay entity |
| `confirm-timeout-seconds` | `15` | Seconds before a purchase/creation confirmation auto-cancels |
| `allow-personal-shops` | `true` | Set to `false` to require all shops be business-linked (future feature) |
| `shop-tax-rate` | `0.0` | Percentage taken from each sale and sent to the server account. `0` to disable. |
| `business-name-tag` | `true` | Show business name above the floating item (future feature) |

### Database

```yaml
database:
  type: sqlite          # sqlite or mysql
  host: localhost        # MySQL only
  port: 3306             # MySQL only
  database: dogcraft_shops  # MySQL only
  username: root         # MySQL only
  password: ""           # MySQL only
```

SQLite stores data in `plugins/Dogcraft-Shops/shops.db`. MySQL allows multiple servers to share one database — each server is identified by the UUID in `id.conf`.

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `shops` | All shop records with location, item, price, owner, and server UUID |
| `shop_sales` | Sales ledger (item, quantity, price, timestamp). No buyer identity stored. |
| `shop_funds` | BUY-mode fund account UUIDs (future feature) |
| `shop_alerts` | Low stock alert tracking |
| `shop_notifications` | Queued offline sale notifications delivered on next login |

---

## Building

```bash
mvn clean package
```

The shaded JAR is output to `target/Dogcraft-Shops-1.0-SNAPSHOT.jar`.
