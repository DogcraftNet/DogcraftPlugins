# Dogcraft-Shops

A container-based shop plugin for Paper 1.21+. Place a **chest or barrel**, hold an item, run a command, and your shop is live. Players right-click to buy with a clickable confirmation prompt. All money movement is handled through DogcraftEconomy.

## Requirements

- **Paper** 1.21 or later
- **Java** 21+
- **DogcraftEconomy** (required)
- **MySQL** or **SQLite** (SQLite by default, MySQL for shared databases)
- **Dogcraft-Sync** (optional — enables cross-server dupe protection on `/shop restock`)
- **Dogcraft-SuffixManager** (optional — enables cosmetic suffix tiers awarded for cumulative shop sales)
- **DogcraftHomes** (optional — when present, `/shop teleport` routes through the same warmup + portal-effect pipeline as `/home` and `/warp`)
- **NetworkSwitch** (optional — when present, this plugin adopts NetworkSwitch's `server_id.conf` UUID so cross-server queries match a single canonical identity across the network)

## Installation

1. Drop `Dogcraft-Shops.jar` into your `plugins/` folder
2. Start the server once to generate `config.yml` and `id.conf`
3. Edit `plugins/Dogcraft-Shops/config.yml` if needed (see [Configuration](#configuration))
4. Restart the server

On first startup the plugin generates a unique server UUID in `plugins/Dogcraft-Shops/id.conf`. This identifies which server owns which shops when sharing a MySQL database across multiple servers. **If NetworkSwitch is installed**, the plugin adopts the UUID from its `server_id.conf` instead — see [NetworkSwitch identity integration](#networkswitch-identity-integration) below for the migration behaviour.

---

## How To: Create a Shop

1. Place a **chest or barrel** where you want your shop. Barrels are a popular choice for dense shop areas — they have no open animation and no 1-block air requirement on top, which keeps neighbouring shops visually clean and reduces client-side rendering load.
2. Fill the container with the items you want to sell
3. **Hold one of the items** in your main hand
4. Look at the container (within 5 blocks) and run:
   ```
   /shop create <price> [quantity]
   ```
   The `[quantity]` argument is optional and defaults to `1`. It sets how many items move per sale. The price is for the **whole bundle**, not per item — so `/shop create 50 16` means "16 items per sale for $50 each sale" (~$3.13/item).
5. A confirmation prompt appears showing the creation fee. Click **[Confirm]** to pay and create the shop
6. A floating item display spawns above the container showing what the shop sells

Your shop is now live. Other players can right-click the container to purchase items. Double chests work as shops too — the full double inventory counts toward stock.

### Bulk pricing (sale quantity)

Every shop has a **sale quantity** — how many items transfer per purchase. Set it at create time with the optional second arg or change it later with:

```
/shop setquantity <items per sale>
```

Examples:
- `/shop create 5` — sells 1 item for $5 each (default behavior)
- `/shop create 50 16` — sells 16 items for $50 per sale (≈ $3.13/item)
- `/shop create 1000 1728` — sells a chest's worth (27 × 64) for $1,000

The buyer pays the full bundle price in one click and the bundle's worth of items moves to their inventory. If they don't have room for the full bundle (across both empty slots and partial stacks of the same item), the purchase is rejected before any money changes hands. Same for the chest side — if stock is below the bundle size, the buy prompt errors instead of charging.

Bulk sales record one row in `shop_sales` with `quantity = <bundle size>` and `price_each = <total price> / <quantity>`, so price-per-item analytics stay consistent across single-item and bulk shops.

### Restocking

**Sneak + right-click** your shop container to open it normally and add more items.

---

## How To: Buy from a Shop

1. Find a shop (look for floating items above chests or barrels)
2. **Right-click** the container
3. You'll see the item, totals, bulk-buy buttons, and a confirmation prompt:
   ```
   Buy 1x Diamond for 50.00 Dogcoins?
     [5x] [10x] [25x] [50x] [100x] [Custom] [Apply Discount]
     [Confirm]    [Cancel]
   ```
   Prices are formatted by DogcraftEconomy and will show whatever currency symbol/name your server uses.
4. Click a bulk-buy button to redraft the order with that many copies of the shop's bundle (see [Bulk buying](#bulk-buying) below), `[Apply Discount]` to redeem a code (see [Applying discount codes](#applying-discount-codes) below), or click **[Confirm]** to complete the purchase as-is. **[Cancel]** backs out.
5. If you don't respond within 15 seconds, the purchase auto-cancels

The item moves from the chest to your inventory and the payment is processed through DogcraftEconomy.

### Bulk buying

The bulk-buy buttons multiply the shop's bundle. Clicking `[5x]` on a `32× Diamond for $50` shop redrafts the prompt for **160 diamonds at $250**. The new totals appear on the same prompt and you click **[Confirm]** to commit (or another multiplier to redraft again).

```
Order adjusted to 3x — shop only has stock for 3x.
Item: Diamond  •  Bundle: 32×  •  Order: 3× bundles (96 items)  •  Total: 150.00 Dogcoins
Buy 3× bundle of 32 Diamond for 150.00 Dogcoins?
```

The order is automatically clamped to the lower of the shop's stock and your inventory space — if you click `[10x]` but the chest only has stock for 3 bundles, the prompt redraws as `3x` and tells you why. Same if your inventory only fits a partial order. If even one bundle won't fit (zero stock, or no inventory room), the prompt errors out instead of leaving a stuck pending purchase.

`[Custom]` lets you type any amount in chat. After clicking it, your next chat message is captured (not broadcast to other players) and parsed as the multiplier — type `cancel` instead to keep the current amount. The capture window is 30 seconds.

### Applying discount codes

If a shop owner has handed out a code (see [Discount codes](#discount-codes) below for the owner side), click `[Apply Discount]` and type the code in chat within 30 seconds (`cancel` to back out). The code is captured silently — other players don't see it.

The prompt redraws with the discount applied:

```
Discount: -25% (WJ7K3MQR)
Item: Diamond  •  Order: 1×  •  Total: 37.50 Dogcoins (was 50.00)
Buy 1x Diamond for 37.50 Dogcoins?
  [5x] [10x] [25x] [50x] [100x] [Custom] [Remove Discount]
  [Confirm]    [Cancel]
```

The discount carries through bulk-buy multiplier changes — clicking `[10x]` on a global 25% code keeps it at 25% off the new total. `[Remove Discount]` clears it.

**Once-per-customer codes (per-player flag).** Some codes are flagged "once per customer." When you apply one, the discount only applies to the **first bundle** in your order; bundles 2..N are charged at full price. The prompt makes the split visible so you know exactly what you're paying:

```
Discount: -25% on 1 of 10 bundles (WJ7K3MQR) — once per customer
Item: Diamond  •  Bundle: 32×  •  Order: 10× bundles (320 items)
Total: 487.50 Dogcoins (was 500.00)
```

If a code expires or runs out between when you apply it and when you click `[Confirm]`, the purchase aborts cleanly with a clear error and no money or items move. Validation is atomic at confirm time — two buyers racing for the last use of a code can't both win.

---

## How To: Manage Your Shops

### Change the price
Look at a shop chest and run:
```
/shop setprice <new price>
```
Owners and Managers can do this.

### Open or close a shop
Temporarily disable purchases without removing the shop:
```
/shop toggle
```
Owners and Managers can do this.

### View shop details
Look at any shop chest and run:
```
/shop info
```
Owners, Managers, and admins see full details (stock count, coordinates, creation date, display entity UUID). Refillers and other players see limited info (owner, item, price, status).

### List all your shops
```
/shop list
```
Shows every shop you **own** with stock levels, prices, and status. Shops you're a Manager or Refiller on don't appear here — they show up in `/shop restock`'s plan instead, since that's where you actually act on them.

### View sales history
Look at a shop chest and run:
```
/shop sales
```
Paginated history showing what sold, when, and for how much. Owners and Managers can view. Navigate pages with:
```
/shop sales <page>
```

### Share a shop with other players

Shops can have members with roles. Useful for co-managed stores, hired restockers, family shops, and so on.

| Role | Can open chest | `/shop restock` | Modify price/toggle | View sales | Break container | Add/remove members | Remove shop |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Owner** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Manager** | ✓ | ✓ | ✓ | ✓ | | | |
| **Refiller** | ✓ | ✓ | | | | | |

All roles (including the owner) pay the per-shop fee when using `/shop restock`. The fee represents the "skip the trip" convenience — members who want to restock for free just walk to the chest and open it normally.

**Refillers can physically open the chest.** Vanilla Minecraft doesn't offer an "add-only" permission on containers, so refillers get trust-based access: the role implies the owner trusts them not to withdraw. If that trust is misplaced, make them a Manager or revoke the role.

**Commands:**
```
/shop addmember <player> <manager|refiller>   # owner only, look at shop chest
/shop removemember <player>                    # owner only
/shop members                                  # anyone, shows roster
/shop notifymember <on|off>                    # a Manager toggles their own sale notifications
```

**Sale notifications** default to the owner only. Managers can opt in per shop with `/shop notifymember on` while looking at that shop's chest; their notifications are prefixed with the owner's name so they can tell which shop a sale came from. Refillers never receive sale notifications.

### Transferring ownership

```
/shop transferowner <player>
```

Hand a shop over to someone else. Safety rail: **the target must already be a Manager on the shop** — so the current owner has pre-vetted them via `/shop addmember`. Running `/shop transferowner Bob` before Bob is a Manager gives you a reminder to add him first.

The flow is confirmation-gated:
```
Transfer the diamond shop at 120,64,-200 to Bob?
  [Confirm Transfer]    [Cancel]
```
Click **[Confirm Transfer]** and ownership flips; Bob's former Manager entry is dropped (he's now the owner, not a Manager of his own shop). The former owner and all other members get no special treatment — they're no longer associated with the shop unless they already had a member role.

**Admin override.** Anyone with `dogcraftshops.admin` can initiate a transfer on any shop, not just their own. The same "target must be a Manager" rule still applies — the admin adds the intended owner as a Manager first, then transfers. Both the previous owner and the new owner get notifications explaining the admin acted on their behalf.

Confirmation times out in 15 seconds (`confirm-timeout-seconds`). The new owner is notified in chat if online, queued via the standard notification pipeline if offline.

### Remote-restock all your shops at once

Run `/shop restock` from anywhere to scan every shop you own, match items in your inventory to each shop's product, and get a per-shop restock offer in chat:

```
Remote restock plan:
  Diamond @ world 120,64,-200  —  restock 32 for $100   [Restock] [Skip]
  Iron ingot @ world 150,72,100 —  restock 16 for $100   [Restock] [Skip]
  Cobblestone @ nether 50,80,50 —  restock 64 for $100   [Restock] [Skip]
Total: 112 items for $300   [Restock All] [Cancel All]
Plan expires in 60 seconds.
```

Each shop has its own **[Restock]** button and its own fee. Click individual shops to restock some and skip others, or **[Restock All]** to commit everything in one go. The fee is deducted per confirmed shop and deposited to the server account (same flow as shop creation fees and teleport fees).

**Matching rules** — the plugin uses full ItemStack comparison, so a shop selling *Sharpness V diamond swords* only accepts matching swords from your inventory. Custom model data, potion effects, display names, and enchants all have to line up. Shops selling filled shulker boxes would need an identically-filled shulker to match.

**Async chunk loading** — shops in unloaded chunks are loaded via Paper's `getChunkAtAsync`, so planning doesn't stall the main thread even with hundreds of dormant shops. The chunks unload naturally once the plan completes.

**Skip conditions**: if an entry doesn't appear in the plan, it's because (a) you don't have any matching items in your main inventory, (b) the chest is already full for that item, or (c) the shop's chunk doesn't exist on disk (ghost shop — those get cleaned up by the integrity system).

**Cross-server shops**: when `restock.cross-server.enabled: true` and the plugin is backed by MySQL, the plan includes shops you own on *other* servers in the network, grouped under a separate "On other servers" section. Clicking `[Restock]` on a remote shop removes the items from your inventory here, queues a request through the shared DB, and the target server delivers the items to the chest asynchronously. The response comes back via chat a few seconds later (or when you next log in, if you disconnect in the meantime). See the [Cross-server restock](#cross-server-restock) section below for the full flow.

Fee defaults to the same as `/shop teleport` (100 by default) but is individually configurable via `restock.fee-per-shop`.

### Discount codes

Owners and Managers can run promotions on a shop without manually editing the price. Look at the shop chest and run:

```
/shop discount create <percent> [duration] [uses] [perplayer]
```

- `<percent>` — required. Capped at `discount.max-percent` (default 90). Whole-number percents only.
- `[duration]` — optional. Accepts `7d`, `12h`, `30m`, `1w`, or `none`/`forever`/`never`. Defaults to no expiry.
- `[uses]` — optional. A positive integer or `unlimited`/`none`. Defaults to unlimited.
- `[perplayer]` — `true` for "once per customer" semantics, `false` for a global counter shared across buyers. Defaults to `false`.

The plugin generates an alphanumeric code (uppercase, length configurable via `discount.code-length`, default 8). Codes use a readable charset that omits `O/0/I/1/L` so they read aloud cleanly. Examples:

```
/shop discount create 25 7d 50 false
  → 25% off, expires in 7 days, 50 uses shared between everyone
/shop discount create 50 none unlimited true
  → 50% off, no expiry, each player can use it once
```

Other commands (look at the shop chest):

```
/shop discount list                # codes on this shop with status, percent, remaining
/shop discount info <code>         # full details on a single code
/shop discount revoke <code>       # immediately invalidate a code
```

A shop can hold up to `discount.max-active-per-shop` codes at a time (default 10). Expired and exhausted codes are pruned hourly by a background sweep so the table stays clean. Removing a shop deletes its codes (and any redemption rows) automatically.

**Cost bearer.** The shop owner absorbs the discount — the buyer pays the discounted total and the owner is credited that same amount. Sales analytics record the post-discount price-per-item so reporting reflects actual money paid.

**Atomic redemption.** Validation runs as one DB transaction at `/shop confirm` time: the redemption row (for per-player codes) and the `uses_remaining` decrement happen together or not at all. Two buyers racing for the last use can't both succeed; the loser sees `That code expired or ran out` and no side effects.

**Bulk-buy + per-player.** A per-player code only discounts the first bundle in a bulk order; bundles 2..N are charged at full price. This honors the "once per customer" intent without letting a single buyer pull a 10-bundle discount from a code meant to be used once. Global codes still discount every bundle in a bulk transaction (one transaction = one use).

### Remove a shop
Look at your shop chest and run:
```
/shop remove
```
A confirmation prompt appears. Click **[Confirm Remove]** to permanently delete the shop and despawn the display entity. Breaking the chest also removes the shop.

---

## How To: Find and Navigate to Shops

Search across every shop on the server with:
```
/shop find [query]
```
A paginated chest GUI opens with the matching shops — up to 45 results per page. Run with no arguments to browse every open shop.

### Loose, multi-facet search

The query is tokenized and matched against every searchable facet of the stored item, so every token has to match *something* but they don't all have to match the same field:

- **Material name** — `/shop find stone` hits Stone, Cobblestone, Stone Bricks, Blackstone, Smooth Stone
- **Custom display name** — renamed items are searchable by their display name
- **Enchantments** — `/shop find protection` finds enchanted books and armor with Protection; `/shop find sharpness v` finds Sharpness V swords specifically
- **Potion effects** — `/shop find strength` finds potions and tipped arrows with Strength
- **Shulker contents** — shops that sell shulker boxes are matched against the boxes' *contents*, so `/shop find diamond` finds a shulker box full of diamonds even if the shulker itself is renamed

### Filters and sorting

The bottom row of the GUI has six toggles:

| Button | Cycles through |
|--------|----------------|
| **Mode** | All modes / Selling / Buying |
| **Category** | All / Tools / Weapons / Armor / Food / Building / Redstone / Transport / Brewing |
| **World** | All worlds / Current world only |
| **Stock** | Show out-of-stock / Hide out-of-stock |
| **Sort by** | Price / Stock |
| **Direction** | Ascending / Descending |

Categories use Minecraft's own [`Tag`](https://minecraft.wiki/w/Tag) system plus creative category fallback, so new items from future Minecraft versions are picked up automatically.

Stock counts are **chunk-safe** and **cached in the database**, so shops in unloaded chunks show a known (possibly slightly stale) number rather than forcing a chunk load. The cache is refreshed on every sale, on chunk-load verification, on owner restocks (`InventoryCloseEvent`), and on the periodic integrity sweep. `?` appears only for shops that have never been verified yet — after a few sales or one sweep cycle, the cache is accurate for every shop. When sorting by stock, any remaining unknowns are pushed to the end of the list regardless of direction.

### Result lore

Each result is displayed as the **owner's head** with lore showing:

- Owner name, price, mode (Selling/Buying)
- **Stock** — exact count, `? (chunk unloaded)`, or `OUT OF STOCK` in red
- **Enchantments** with Roman numerals — hidden if the item has the `HIDE_ENCHANTS` ItemFlag
- **Potion effects** — base potion type + custom effects with amplifier and duration
- **Custom model data** — shown if the item has a CMD set
- **Shulker contents preview** — `3 types, 63 items` summary plus the top N unique types
- World + coordinates, distance (same-world only)

**Click a result** to start tracking that shop:

- A **boss bar** appears at the top of your screen with a compass tape, a `◆` marker pointing at the target, and the distance remaining. Progress is anchored to the trip's starting distance — the bar starts empty when you begin tracking and fills as you close in. Walking past where you started empties the bar back to zero (a clear "wrong way" cue).
- The **action bar** above your hotbar shows an arrow and distance to the shop.
- A **clickable teleport prompt** appears in chat: `Want to get to the shop quick? Teleport now for <fee> [Teleport]`.

Tracking stops automatically when you:

- Walk within the arrival radius (default 5 blocks) — the shop briefly **glows** just for you
- Run `/shop find` again
- Change worlds
- Log out
- The tracked shop is removed

Only one shop is tracked at a time per player.

### Teleporting to a Tracked Shop

While tracking, you can pay to teleport directly:
```
/shop teleport
```
or click the `[Teleport]` button in the tracking prompt. The plugin searches within a few blocks of the chest for a safe standing spot (1 wide × 2 tall of open space with a solid floor, no liquids) and sends you there facing the chest. The teleport fee is withdrawn from your account and deposited to the server account — same flow as shop creation fees.

If no safe spot is found, the teleport is cancelled and you aren't charged.

**DogcraftHomes integration.** When [DogcraftHomes](https://github.com/DogcraftNet/DogcraftPlugins/blob/master/Dogcraft-Homes-API.md) is installed, `/shop teleport` hands the player off to its teleport pipeline — same warmup, portal effects, and `/back` tracking as `/home` and `/warp`. The portal theme defaults to `WARP` (green) and is configurable via `navigation.teleport-theme` (`HOME`, `TELEPORT`, `BACK`, `RTP`, `WARP`). The arrival glow we'd otherwise spawn is skipped in this branch — the portal animation already provides an arrival cue. If a player is already mid-teleport (e.g. another `/home` in progress), the fee check is bypassed and they're told to wait. Without DogcraftHomes installed, behavior is unchanged: a direct teleport with the per-player arrival glow.

---

## Commands

### Player Commands

| Command | Description |
|---------|-------------|
| `/shop create <price> [quantity]` | Create a SELL shop for the item in your hand. Optional bundle quantity (default 1). |
| `/shop remove` | Remove a shop (with confirmation) |
| `/shop setprice <price>` | Update the price of a shop |
| `/shop setquantity <n>` | Update items per sale (bundle size). Owner or Manager. |
| `/shop toggle` | Open or close a shop |
| `/shop info` | View shop details |
| `/shop list` | List all your shops |
| `/shop sales [page]` | View paginated sales history |
| `/shop find [query]` | Search open shops by loose item match and open the navigation GUI |
| `/shop teleport` | Teleport to the shop you're currently tracking (paid) |
| `/shop restock` | Scan all your shops and offer per-shop restock from your inventory (paid per shop) |
| `/shop addmember <player> <manager|refiller>` | Grant a role on this shop (owner only, look at shop chest) |
| `/shop removemember <player>` | Revoke someone's membership on this shop (owner only) |
| `/shop members` | List the members of the shop you're looking at |
| `/shop notifymember <on|off>` | Toggle sale notifications for this shop (Managers only, each member sets their own) |
| `/shop transferowner <player>` | Hand this shop over to an existing Manager (owner only; admins can transfer any shop) |
| `/shop discount create <percent> [duration] [uses] [perplayer]` | Create a discount code on the shop you're looking at. Owner or Manager. |
| `/shop discount list` | List all discount codes on this shop. |
| `/shop discount info <code>` | Show details for one discount code. |
| `/shop discount revoke <code>` | Immediately invalidate a discount code. |
| `/shop buy <amount\|custom>` | Redraft the active buy prompt with a bulk multiplier. `custom` opens a chat-input capture for an arbitrary amount. Usually invoked via the prompt's clickable buttons. |
| `/shop confirm` | Confirm a pending purchase |
| `/shop cancel` | Cancel a pending purchase |

All `/shop` commands can also be used as `/s` (alias).

### Admin Commands

| Command | Description |
|---------|-------------|
| `/shopadmin reload` | Reload config and respawn all display entities |
| `/shopadmin remove <player>` | Force-remove all shops owned by a player |
| `/shopadmin inspect` | View detailed shop record (look at a chest or barrel) |
| `/shopadmin reindex [--force]` | Sweep loaded-chunk shops for ghosts. `--force` also loads every unloaded chunk holding a shop, verifies, and releases it back. |
| `/shopadmin create <price> [quantity]` | Create a server-owned shop on the chest you're looking at. No creation fee. See [Server-owned shops](#server-owned-shops) below. |
| `/shopadmin transferserver` | Convert the player-owned shop you're looking at into a server-owned one. Refunds the configured creation fee to the previous owner. |
| `/shopadmin setunlimited [on\|off]` | Toggle unlimited-stock mode on the shop you're looking at. Sales materialize from a chest sample without depleting the chest, and the stale-shop sweep skips unlimited shops. |

### Server-owned shops

Admin/spawn shops that aren't tied to any single player. Useful for currency sinks ("buy a name tag from the server"), starter goods, or seasonal promotions.

**Identity.** Server-owned shops use a sentinel `owner_uuid` of `00000000-0000-0000-0000-000000000000` and an `is_server_owned = 1` flag on the row. The flag is the source of truth; the sentinel UUID is what player-keyed lookups (notifications, head cache, suffix progression) see, so they all naturally no-op for server shops without per-call guards.

**Money.** When a server-owned shop is sold from, the buyer is debited normally but no deposit happens — the money is burned out of circulation. This makes server shops a clean currency sink. Discount codes still apply (the sale records the discounted price as usual; less money is burned).

**Notifications.** No owner notifications fire (there's no real player to ping), but Managers added with `/shop addmember` who opt in via `/shop notifymember on` still receive sale notifications, prefixed with `[Server's shop]`. Refillers never see them, same as on player shops.

**Progression.** The sentinel UUID is excluded from `shop_sales`-based suffix unlocks — no Stall Owner / Shopkeeper / etc. accrual on the server identity.

**Stale-shop cleanup.** Player shops get auto-removed after `retention.stale-cleanup-days` empty days. Server shops follow the same rule unless they're flagged unlimited (see below) — there's no "server shops never expire" carve-out beyond unlimited mode.

**Display.** Server shops show `Server` as the owner name in `/shop find`, `/shop info`, and the recent-sales feed. The owner head renders as the default Steve skin since there's no player to fetch a skin from.

**Members + discounts.** Both work normally. An admin (or any Manager added with `/shop addmember`) can run `/shop discount create` etc. on a server shop just like on a player shop.

### Unlimited-stock shops

Toggled via `/shopadmin setunlimited`. Independent of server ownership — any shop can be marked unlimited if the admin permission is held.

When unlimited:

- The stock check on sale is skipped.
- Items aren't removed from the chest. Each sale clones the first matching stack in the chest and gives the buyer that stack with the order's quantity (preserves enchants, custom model data, shulker contents, etc.). If the chest is empty the buyer receives a plain `new ItemStack(material)` as a fallback.
- The stale-shop sweep skips the shop entirely, so it never accumulates empty-time and never gets auto-removed.
- The cached-stock and low-stock alert paths are skipped.

**Restocking.** Admins still pre-fill unlimited shops the normal way (sneak + right-click for chest access). Re-fill once with the item template you want buyers to receive — the shop won't decrement after that.

---

## Permissions

| Permission | Description | Default |
|-----------|-------------|---------|
| `dogcraftshops.create` | Create shops | All players |
| `dogcraftshops.use` | Purchase from shops | All players |
| `dogcraftshops.admin` | Admin commands (`/shopadmin`), plus overrides on any shop: remove, setprice, toggle, sales, inspect, and `/shop transferowner` | OP only |
| `dogcraftshops.admin.create` | `/shopadmin create` — create server-owned shops | OP only |
| `dogcraftshops.admin.transferserver` | `/shopadmin transferserver` — convert player shops into server-owned shops | OP only |
| `dogcraftshops.admin.unlimited` | `/shopadmin setunlimited` — toggle unlimited-stock mode | OP only |

---

## Notifications

- **Sale notifications**: When someone buys from your shop, you receive a chat message. If you're offline, notifications queue up and are delivered when you next log in.
- **Manager sale notifications**: Managers on a shop can opt in per shop with `/shop notifymember on`. Their messages are prefixed with the owner's name so they know which shop the sale came from. Off by default.
- **Low stock alerts**: On login, you're warned if any of your shops have stock below the configured threshold (default: 5 items).
- **Stale-shop warnings**: If a shop has been empty long enough to approach the stale-cleanup cutoff, you get warning notifications at configurable day thresholds (default 7, 3, 1 days remaining).
- **Auto-cleanup notifications**: When a shop is removed by the ghost or stale system, the owner is told which shop and why — same chat/queue pipeline as above.

---

## Protections

- **Container breaking**: Only the shop owner (or an admin) can break a shop chest or barrel. Breaking it removes the shop.
- **Explosions**: Shop containers are immune to entity and block explosions (TNT, creepers, beds, etc.).
- **Pistons**: Pistons cannot push or pull shop containers. The entire extend/retract is cancelled if a shop block is in the way.
- **Hoppers**: Items cannot be pulled from or pushed into shop containers by hoppers.
- **Structure growth**: Trees and other vanilla structures growing into a shop will not overwrite its container.
- **Display entities**: Floating item displays are tagged and cannot be killed by players.

## Ghost-shop auto-cleanup

If a shop's chest or barrel is removed by something other than a player — a plot plugin reset, WorldEdit `//set air`, world regen, or any plugin that bulk-edits blocks without firing events — the shop would otherwise stick around as a "ghost" (DB row + floating display, but no container to interact with). The integrity service prevents that:

- **Physics destruction** is caught via Paper's `BlockDestroyEvent` and cleans up immediately.
- **Chunk load verification** — every time a chunk loads, the plugin checks whether every shop in that chunk still has its container. Catches plot resets where the chunk unloads and reloads.
- **Periodic sweep** — every `integrity.periodic-sweep-minutes` the plugin walks every currently-loaded shop and prunes any whose container is gone. Catches in-place edits that never unloaded the chunk.
- **Admins can force a sweep** with `/shopadmin reindex`. Shops in unloaded chunks are verified the next time those chunks load.
  - Add `--force` (or `-f`) to verify every shop — including those in unloaded chunks. Chunk I/O uses Paper's `getChunkAtAsync`, so the disk loads happen off the main thread. A concurrency cap (default 32 in‑flight) keeps memory and the chunk loader bounded for large scans. Chunks that don't exist on disk are treated as definite ghosts and pruned. Use this after a mass plot reset when you want a guaranteed clean database without waiting for players to visit each area.

When a ghost shop is removed, the owner is notified — online, they get a chat message; offline, it's queued alongside sale notifications for their next login.

## Stale-shop auto-cleanup

Shops that stay empty for a configurable number of days are automatically removed so the server doesn't accumulate abandoned listings. This is separate from the ghost-shop system above — with stale cleanup, the chest/barrel and any items still inside it are **left in place**; only the shop record and floating display are removed. Owners don't lose anything they forgot to restock.

- **Timer starts** when the plugin first notices a shop's stock hit zero (on sale, on chunk load, or on the periodic sweep).
- **Timer resets** the moment the shop gets restocked — the elapsed days drop back to zero and any warnings already sent are wiped.
- **Warnings** fire at each configured day threshold before the cutoff (default: 7, 3, 1 days remaining). Each threshold fires once per empty period and is delivered as a chat message (online) or queued alongside sale notifications (offline).
- **Only loaded-chunk shops tick** — stock can't be verified when the chunk is unloaded, so shops in dormant chunks don't accumulate empty-time against the timer. They're checked and resume ticking when the chunk next loads.

Set `retention.stale-cleanup-days` to `0` to disable the whole system. All knobs live under `retention:` in the [Configuration](#configuration) table below.

---

## Configuration

`plugins/Dogcraft-Shops/config.yml`

### Auto-update

The plugin keeps your `config.yml` in sync with the bundled default on every startup:

- **New options** introduced by plugin updates are appended with their default value and the default comment block above them — you don't have to regenerate the file after upgrading.
- **Unknown options** (from older versions or manual edits) get a `[DEPRECATED]` comment added above them so you know they can be safely removed. The option itself isn't deleted — cleanup is left to you.
- **Your values and your comments are preserved**. Only new keys get the bundled comment block; anything you already have is left alone.

To re-run the update without restarting the server, use `/shopadmin reload`. The log line tells you how many options were added or tagged each time.

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
| `navigation.arrive-radius` | `5.0` | Distance in blocks at which tracking stops and the arrival highlight fires |
| `navigation.highlight-duration-seconds` | `3` | How long the per-player glowing arrival highlight stays visible |
| `navigation.highlight-scale` | `1.2` | Scale of the glowing arrival highlight ItemDisplay |
| `navigation.teleport-fee` | `100.0` | Fee charged by `/shop teleport`. Deposited to the server account. `0` = free. |
| `navigation.teleport-search-radius` | `2` | How many blocks around the chest to scan for a safe landing spot |
| `navigation.teleport-theme` | `WARP` | Portal theme used when DogcraftHomes is installed. Valid: `HOME` (blue), `TELEPORT` (purple), `BACK` (red/orange), `RTP` (gray), `WARP` (green). No effect when DogcraftHomes is absent. |
| `restock.fee-per-shop` | `100.0` | Fee charged per shop when confirming a `/shop restock` entry. `0` = free. |
| `restock.confirm-timeout-seconds` | `60` | How long the remote-restock plan stays valid after `/shop restock`. |
| `restock.cross-server.enabled` | `true` | Master switch for cross-server restock. Set `false` to scope `/shop restock` to this server only. |
| `restock.cross-server.processor-poll-seconds` | `2` | How often the target server checks for incoming requests. Lower = faster but more queries. |
| `restock.cross-server.responder-poll-seconds` | `2` | How often the requester server checks for responses to deliver. |
| `restock.cross-server.process-batch-size` | `8` | Max requests a single poll cycle will claim or deliver. |
| `restock.cross-server.processing-timeout-seconds` | `60` | Stuck-PROCESSING rows older than this are reset to PENDING (target crash recovery). |
| `restock.cross-server.request-ttl-hours` | `48` | PENDING rows older than this are marked FAILED and the requester refunded. |
| `restock.cross-server.cleanup-interval-minutes` | `15` | How often the cleanup task runs (timeout reset + TTL expire + prune). |
| `restock.cross-server.acknowledged-retention-days` | `7` | Audit window before acknowledged rows are permanently deleted. |
| `navigation.search.hide-out-of-stock-by-default` | `false` | Initial state of the `/shop find` out-of-stock toggle. Players can still cycle it per session. |
| `navigation.search.shulker-contents-preview-count` | `3` | Unique item types to list in a shulker shop's lore before truncating to "…N more types". |
| `integrity.chunk-load-verify` | `true` | Scan each chunk's shops on load and auto-remove any whose container is missing. |
| `integrity.periodic-sweep-minutes` | `5` | Interval between full sweeps of all loaded-chunk shops. `0` disables the periodic sweep (chunk-load verify still runs). |
| `integrity.force-reindex-batch-size` | `32` | Max concurrent async chunk-load requests during `/shopadmin reindex --force`. Paper loads chunks off main; this cap just keeps memory + the chunk loader bounded. |
| `retention.stale-cleanup-days` | `30` | Days a shop can be empty before the plugin removes the record and display (container and items preserved). `0` disables stale cleanup entirely. |
| `retention.warning-days` | `[7, 3, 1]` | Remaining-day thresholds that trigger a warning notification to the owner. Each fires once per empty period; resets on restock. |
| `retention.check-interval-minutes` | `60` | How often the stale-shop sweep runs. `0` disables the sweep. Hourly is enough for day-level thresholds. |
| `discount.max-percent` | `90` | Maximum percent an owner can set on a single discount code (1-99). |
| `discount.max-active-per-shop` | `10` | How many active discount codes a single shop can hold at once. |
| `discount.code-length` | `8` | Length of generated alphanumeric codes. Drop to 6 for shorter codes. |
| `discount.apply-timeout-seconds` | `30` | Chat-input window after a buyer clicks `[Apply Discount]`. |
| `discount.cleanup-interval-minutes` | `60` | How often expired/exhausted discount codes are pruned. `0` disables the sweep. |

### Database

```yaml
database:
  type: sqlite               # sqlite or mysql
  host: localhost            # MySQL only
  port: 3306                 # MySQL only
  database: dogcraft_shops   # MySQL only
  username: root             # MySQL only
  password: ""               # MySQL only
  pool:                      # HikariCP connection pool (MySQL only)
    maximum-pool-size: 10
    minimum-idle: 2
    max-lifetime-ms: 1800000      # 30 min — must stay below MySQL's wait_timeout
    idle-timeout-ms: 600000       # 10 min
    connection-timeout-ms: 10000  # 10 sec
    keepalive-ms: 300000          # 5 min
```

SQLite stores data in `plugins/Dogcraft-Shops/shops.db` and always uses a single serialized connection (SQLite's writer model).

MySQL allows multiple servers to share one database — each server is identified by the UUID in `id.conf` and queries are scoped per server. Connections are pooled via [HikariCP](https://github.com/brettwooldridge/HikariCP); idle connections are validated and recycled before MySQL's `wait_timeout` can drop them, so the pool self‑heals after network hiccups or database restarts without plugin intervention.

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `shops` | All shop records with location, item, price, owner, and server UUID |
| `shop_sales` | Sales ledger (item, quantity, price, timestamp). No buyer identity stored. |
| `shop_funds` | BUY-mode fund account UUIDs (future feature) |
| `shop_alerts` | Low stock alert tracking |
| `shop_notifications` | Queued offline sale notifications delivered on next login |
| `shop_restock_requests` | Cross-server restock queue — rows travel between servers via polling, lifecycle PENDING → PROCESSING → COMPLETED/FAILED → acknowledged |
| `shop_members` | Player roles on shops (Manager / Refiller) with per-member `notify_on_sale` opt-in. Cross-server — members apply regardless of which server the shop lives on. |
| `shop_discount_codes` | Per-shop promo codes — code, percent, expiry, remaining uses, per-player flag |
| `shop_discount_redemptions` | Per-player redemption ledger for once-per-customer codes (PRIMARY KEY on `code, player_uuid`) |

---

## Threading model

The plugin is built to stay off the main thread wherever Bukkit doesn't force it there. The short version:

- **Main thread is required for**: block state reads (stock checks, integrity verify), entity operations (display spawn/despawn), inventory transfers (sale item move), and sending chat messages to online players.
- **Async worker threads handle**: every SQL write (via HikariCP, which is thread‑safe), decision‑making in the periodic sweeps, offline notification queuing, and the forced reindex chunk walk.

Sweeps work in three phases: a quick main‑thread pass to snapshot what's needed (e.g. stock counts from chest blocks), then an async pass for math + SQL, then a final main‑thread bounce only for the Bukkit‑side mutations (display despawn, online owner messages). For the stale‑shop tick this keeps main‑thread work bounded to a single stock‑read pass per hour regardless of server size.

**Per‑shop state is thread‑safe**. All mutable fields on the `Shop` model are `volatile` so reads from any thread see the latest write. `ShopManager` uses `ConcurrentHashMap` for its indexes with a lock ensuring the two indexes (by‑ID and by‑location) stay in lock‑step. The v2 ItemStack cache uses standard double‑check locking.

**Overlap protection**. The periodic timers (integrity sweep, stale sweep) skip a firing if the previous tick is still running. You won't get two sweeps stacking up on a slow database.

**Hot paths that stayed sync** on purpose: shop creation/removal/price‑change command flows. These are rare, triggered by player action, and benefit from synchronous feedback (if the SQL fails, the player sees the error immediately rather than being told "success" and finding the change missing after a restart). Transactions (buy/sell) run the core economy + item transfer sync for atomicity, but the post‑transaction sales ledger insert and offline notification queuing are async.

## Cross-server restock

On networks that share the `shops` MySQL database, `/shop restock` works across servers. The player on `survival-1` can restock their shops on `creative-2` and `mining-3` without leaving the lobby, via a queue in the shared database.

### Design

- **Message bus**: MySQL table `shop_restock_requests`, no Redis required. Durable — requests survive server restarts.
- **Latency**: 200ms – 4s end-to-end (two poll cycles in the worst case). Default poll interval is 2 seconds; tune via `restock.cross-server.processor-poll-seconds` / `responder-poll-seconds`.
- **Dupe safety**: same contract as single-server restock. Items are removed from player, `forceSave` commits the post-removal state to Dogcraft-Sync's DB, *then* the queue row is inserted. A crash between the save and the insert loses the queue entry (items are gone, no chest credit); a crash between insert and processing leaves the row `PENDING` and the target picks it up on next poll.

### Flow

```
Requester (Server A)                  Target (Server B)
─────────────────────                 ──────────────────
1. Remove items from player
2. forceSave(uuid)
3. INSERT status=PENDING
                                      (poll every 2s)
                                      4. Claim batch → PROCESSING
                                      5. getChunkAtAsync (Paper)
                                      6. Add to chest on main
                                      7. UPDATE → COMPLETED
                                         (with placed, leftover counts)
(poll every 2s)
8. Read COMPLETED rows for me
9. Give leftovers back to player
10. UPDATE → acknowledged_at
```

### Failure modes

| Situation | Outcome |
|---|---|
| Target server offline | Row stays `PENDING`, processes when target comes back |
| Target crashes mid-process | `PROCESSING` row sits with a stale `processed_at`; cleanup task resets to `PENDING` after `processing-timeout-seconds` |
| Target refuses (shop gone, container broken) | Row marked `FAILED`, requester refunds fee + returns items |
| Target chest fills up mid-transfer | Row marked `COMPLETED` with `leftover_count` set; requester returns leftovers to player inventory (or drops at feet if inventory full) |
| Requester crashes after insert | Row stays valid; response delivery picks up on next poll once the requester is back |
| Player offline when response arrives | Row stays `acknowledged_at = NULL`; `PlayerJoinListener` delivers on next login to the requester server |
| Request sits PENDING past `request-ttl-hours` | Cleanup marks `FAILED`, requester refunds fee + returns items on next poll / next login |
| Acknowledged rows older than `acknowledged-retention-days` | Pruned permanently by cleanup task |

### Plan display

Shops are grouped by location:

```
Remote restock plan:
On this server:
  Diamond @ world 120,64,-200    — restock 32 for $100   [Restock] [Skip]
On other servers:
  Copper @ creative-1 80,60,-100 — up to 64 for $100     [Restock] [Skip]
  Iron @ mining-2 -400,50,300    — up to 16 for $100     [Restock] [Skip]
Total: up to 112 items for $300   [Restock All] [Cancel All]
Plan expires in 60 seconds.
```

Remote lines say "up to N" because we don't know the target chest's free space from here. The target server fits what it can and returns any leftover count in the response.

### Single-server installs

If you're running SQLite or a single MySQL server, set `restock.cross-server.enabled: false` (or leave it on — the poll tasks are cheap on an empty queue). Nothing changes from the existing behavior.

## NetworkSwitch identity integration

If [NetworkSwitch](https://github.com/DogcraftNet/DogcraftPlugins) is installed and has written `server_id.conf` to the server root, Dogcraft-Shops adopts that file's UUID as its own server identity. This means every plugin in the network that knows about NetworkSwitch's identity (chat, sync, network-aware tools, your website) shares the same canonical UUID for this server.

### What it does on startup

1. Reads `plugins/Dogcraft-Shops/id.conf` (the plugin's own UUID file, may not exist on a fresh install).
2. Reads `server_id.conf` in the server root — that's NetworkSwitch's file with both `uuid=` and `name=` lines.
3. If NetworkSwitch's UUID differs from the plugin's local UUID, the plugin migrates every per-server row to the new UUID:
   - `shops.server_uuid`
   - `shop_restock_requests.target_server_uuid` and `requester_server_uuid`
4. After the migration commits, `id.conf` is updated to the new UUID so subsequent restarts are no-ops.
5. The friendly name from `server_id.conf` is exposed via `DogcraftShops.getServerName()` — handy for any future "show shop on lobby/survival/creative" UI.

### Crash safety

The migration runs in a single transaction. The local `id.conf` is only rewritten **after** the DB migration commits. So:

- If the migration fails → local UUID stays old → next startup retries it.
- If the migration succeeds but `id.conf` write fails → next startup re-runs the migration. Idempotent: zero rows now match the old UUID, so the UPDATEs no-op and `id.conf` gets written successfully.

### When the name isn't ready yet

`server_id.conf` may have a blank `name=` field on first ever startup before any player joins (NetworkSwitch resolves the name via Velocity on first connection). In that case the UUID is still adopted, just without the friendly name. `getServerName()` returns null until NetworkSwitch fills it in; subsequent restarts pick up the resolved name automatically.

### What if NetworkSwitch isn't installed

The plugin works exactly as before — generates its own UUID in `id.conf` on first run, persists it, and uses it for cross-server queries. No NetworkSwitch dependency for the plugin to function.

## Sales progression (Dogcraft-SuffixManager integration)

If [Dogcraft-SuffixManager](https://github.com/DogcraftNet/DogcraftPlugins/blob/master/Dogcraft-SuffixManager.md) is installed, Dogcraft-Shops registers a suffix provider in the `dogcraftshops` namespace and awards cosmetic suffix tiers to shop owners as their cumulative sales count crosses thresholds. The plugin loads cleanly without SuffixManager — the integration just stays inactive.

### Default tiers

| Tier | Threshold | Display | Frame |
|---|---:|---|---|
| Stall Owner | 100 | `<gray>[Stall Owner]</gray>` | task |
| Shopkeeper | 1,000 | `<green>[Shopkeeper]</green>` | task |
| Merchant | 10,000 | `<aqua>[Merchant]</aqua>` | goal |
| Magnate | 100,000 | `<light_purple>[Magnate]</light_purple>` | goal |
| Tycoon | 1,000,000 | `<gradient:#FFD700:#FF4500>[Tycoon]</gradient>` | challenge |

Fully customizable in `config.yml` under `progression.shop-sales-tiers` — id, threshold, MiniMessage display text, description, icon Material, and frame type (task / goal / challenge). Add or remove tiers as needed.

### How sales count

Sales come from the `shop_sales` table joined to `shops` by `owner_uuid`. There's no `server_uuid` filter on either side, so the count reflects the player's **cumulative trading history across the entire network** — sales on one server count toward unlocks anywhere.

### When unlocks fire

After each successful sale, the post-transaction async pass:

1. Records the sale row in `shop_sales` (existing behavior)
2. Counts the owner's total sales via `countSalesByOwner(uuid)` (1 indexed COUNT)
3. Pushes `updateProgress(uuid, "dogcraftshops:<tier>", current, target)` to SuffixManager for every configured tier

SuffixManager fires its `SuffixUnlockEvent` when a tier crosses its threshold and the player can equip it via `/suffix`. Unlocks are persisted in SuffixManager's database, so a player who hits 1,000 sales on `survival-1` can equip Shopkeeper from `lobby` or `creative-2` without anything extra.

### Disabling

Set `progression.enabled: false` in `config.yml` to skip provider registration entirely. Existing unlocks in SuffixManager's DB are unaffected — players keep what they earned, just no new ones get awarded.

## Dogcraft-Sync integration

If [Dogcraft-Sync](https://github.com/DogcraftNet/DogcraftPlugins/blob/master/Dogcraft-Sync.MD) is installed, Dogcraft-Shops detects it via reflection (soft-depend, no compile-time coupling) and uses its `SyncAPI.forceSave()` to protect against the classic cross-server dupe vector. Without the sync plugin installed, the plugin logs that sync protection is disabled and falls back to normal single-server behavior.

### The dupe vector

On a multi-server network sharing player inventories via sync, any plugin that removes items from a player's inventory can create a dupe window:

1. Plugin removes items from the player's in-memory inventory.
2. Plugin writes to its own store (in our case, the shop chest).
3. The world saves the chest (items persisted to disk).
4. Server crashes **before** the sync plugin's next periodic save fires.
5. On restart, the chest has the new items; on rejoin, the player loads their *pre-removal* inventory from the sync DB.
6. Player has the items + chest has the items = dupe.

### How we prevent it

The `/shop restock` flow orders its operations per the sync plugin's documented contract:

```
1. remove items from player inventory
2. syncHook.forceSave(uuid)  ← wait for DB commit
3. add items to chest + charge fee + update cache
```

A crash in step 1–2 restores the items on rejoin (sync DB still has pre-removal inventory) with the chest untouched — safe. A crash in step 3 loses the items but no dupe is possible. When Dogcraft-Sync isn't installed the steps collapse to a single main-thread pass with no forceSave — fine for single-server deployments.

### What we don't protect against

The buy flow (`right-click shop chest` → item transferred to buyer) has a structurally different dupe vector where `forceSave` doesn't help: the dupe requires the chest to revert on crash *while* the sync DB has the post-add state, which is made worse by eagerly saving the buyer's new inventory. This is a fundamental limitation of any chest-based shop plugin on a sync'd network; the mitigation lives in Minecraft's world-save cadence, not in the plugin. We fire a best-effort `forceSave` after successful buys purely to speed up cross-server propagation — not as a dupe mitigation.

If you run on a single server with no cross-server sync, none of this matters.

## Building

```bash
mvn clean package
```

The shaded JAR is output to `target/Dogcraft-Shops-1.0-SNAPSHOT.jar`.
