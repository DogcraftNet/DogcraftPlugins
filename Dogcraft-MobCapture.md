# Dogcraft-MobCapture

Tier-based capture eggs for Paper. Craft an egg, activate it (optionally with an economy cost), right-click a mob to capture it, and right-click later to release it. Higher tiers preserve full NBT — your tamed wolf comes back with its name, color, age, sit state, and ownership intact.

- **Compile target:** Paper API `1.21.11-R0.1-SNAPSHOT`
- **Runtime target:** Paper `1.21.11` or any `26.1.x` build
- **Java:** 21+

---

## Highlights

- Six craftable tiers, each accepting a specific category of mob.
- **Full NBT preservation** on diamond, emerald, and netherite eggs (via Paper's `UnsafeValues.serializeEntity` / `deserializeEntity` round-trip).
- **Native Brigadier commands** registered through `LifecycleEvents.COMMANDS` — proper tab completion, no legacy `PluginCommand` shim.
- **Modern data components** (`custom_name`, `lore`, `custom_model_data`, `enchantment_glint_override`) for everything vanilla-visible; **PersistentDataContainer** for plugin-private state.
- **Confirmation UI:** Paper Dialog window by default, with a MiniMessage chat-click fallback (configurable).
- **Soft integrations:** DogcraftEconomy (direct API, with proper ledger entries) and DogcraftClaims (reflection hook). Plugin loads cleanly with neither installed.
- **Defense-in-depth pet protection:** captures of tameable mobs require the capturing player to be the current owner — non-bypassable, even by staff.
- **Insufficient-funds hint:** if you can't afford to activate the whole stack, the message tells you how many you *could* afford so you can split and retry.

---

## Tier reference

Each tier matches one or more mob categories. The category is determined at capture time:

```
VILLAGER  → org.bukkit.entity.AbstractVillager (Villager, Wandering Trader)
TAMEABLE  → org.bukkit.entity.Tameable        (Wolf, Cat, Parrot, all Horses/Donkeys/Mules/Llamas)
HOSTILE   → org.bukkit.entity.Monster         (most hostile mobs)
PASSIVE   → org.bukkit.entity.Animals         (most farm animals — but only if not also Tameable)
OTHER     → anything that's a living entity but doesn't fit the above
```

The blocklist (`ENDER_DRAGON`, `WITHER`, `WARDEN`, `ELDER_GUARDIAN`, `BREEZE`, plus anything in `blocked-entities`) applies to **every** tier including netherite.

### Copper Capture Egg

- **Recipe center:** Copper Ingot
- **Captures:** Passive, non-tameable mobs.
- **NBT preserved:** None — released mobs come back fresh.
- **Examples of what works:**
  - Farm animals: Cow, Pig, Sheep, Chicken, Goat, Mooshroom, Rabbit, Polar Bear
  - Aquatic: Salmon, Cod, Pufferfish, Tropical Fish, Squid, Glow Squid, Turtle, Axolotl
  - Other passive: Bee, Frog, Sniffer, Strider, Camel, Armadillo, Tadpole

> Wolves, cats, parrots, and horses are **not** copper-eligible — they're tameable, and tameable mobs always need a gold or diamond egg even when they're wild and untamed.

### Iron Capture Egg

- **Recipe center:** Iron Ingot
- **Captures:** Hostile monsters.
- **NBT preserved:** None — released mobs come back fresh, full health.
- **Examples of what works:**
  - Undead: Zombie, Skeleton, Husk, Drowned, Stray, Wither Skeleton, Zombie Villager, Phantom
  - Spiders: Spider, Cave Spider
  - Nether: Blaze, Ghast, Magma Cube, Hoglin, Zoglin, Piglin, Piglin Brute, Wither Skeleton
  - End: Enderman, Endermite, Shulker
  - Other: Creeper, Witch, Pillager, Vindicator, Evoker, Vex, Ravager, Silverfish, Slime, Guardian
  - Iron Golem and Snow Golem are **not** iron-eligible — they aren't `Monster` instances. Use netherite.

### Gold Capture Egg

- **Recipe center:** Gold Ingot
- **Captures:** Tameable mobs **owned by you** (or untamed tameables — anyone can catch a wild wolf).
- **NBT preserved:** **None.** A captured pet released with a gold egg comes back as a wild, un-named, untamed copy of its species.
- **When to use:** you want the species but don't care about the individual. Cheaper than diamond.
- **Examples of what works:**
  - Wolf, Cat, Parrot
  - Horse, Donkey, Mule, Skeleton Horse, Zombie Horse
  - Llama, Trader Llama

> Trying to capture another player's pet always fails with `That's not your pet.` This is hardcoded — even `captureeggs.bypass.tier` does not override it.

### Diamond Capture Egg

- **Recipe center:** Diamond
- **Captures:** Same as gold (tameable mobs you own, or untamed tameables).
- **NBT preserved:** **Full.** Custom name, owner UUID, sit state, color (wolf/cat variant), age (baby vs adult), health, saddle/armor (horses), trust state, etc.
- **When to use:** you want your specific pet back exactly as you left it. The expensive option for the player who cares.

The captured wolf you release from a diamond egg is the same wolf you put in — same name, same coat, same tilted head when it sits. If they were a baby when captured, they're still a baby when released.

### Emerald Capture Egg

- **Recipe center:** Emerald
- **Captures:** Villagers and Wandering Traders (`AbstractVillager` instances).
- **NBT preserved:** **Full.** Profession, level, biome variant, all trade recipes (with current stock and uses), discount tags, gossips.
- **When to use:** moving a maxed-out librarian or armorer to a new location without losing their trades. Wandering Traders too, if you've found one you like.

### Netherite Capture Egg

- **Recipe center:** Netherite Ingot
- **Captures:** **Anything not on the blocklist.** This is the only tier that handles `OTHER`-category mobs.
- **NBT preserved:** **Full.**
- **What works that no other tier covers:**
  - Allay, Vex (Vex is Monster, so iron also works), Iron Golem, Snow Golem
  - Modded mobs that don't implement Animals / Monster / Tameable / AbstractVillager
  - Anything else that falls into `OTHER`

> Even with a netherite egg, the **owner check still applies** to tameable mobs and the blocklist still applies to everything. Netherite is universal in *category*, not in *bypass*.

---

## Crafting

Identical shape for every tier — only the center ingredient changes. The corner/frame material is configurable (`recipe.frame-material`, default `*_BARS` — accepts any bar variant).

```
B I B
B E B
B B B
```

- `B` — frame material. Default `*_BARS` matches every bar variant: iron, copper, exposed copper, weathered copper, oxidized copper, plus the four waxed copper bars — nine materials in total. You can pin it to a single material like `IRON_BARS` or use a different glob like `COPPER_*` or `*_INGOT`.
- `I` — tier ingredient (Copper Ingot, Iron Ingot, Gold Ingot, Diamond, Emerald, Netherite Ingot). Same wildcard syntax works here per-tier (e.g. `*_INGOT` for any ingot).
- `E` — vanilla Egg

Output: 1 inactive capture egg of that tier.

If `recipe.permissions-required-to-craft: true`, only players with `captureeggs.craft` see the recipe in their book *and* can pull the result from the crafting grid (memorizing the pattern doesn't bypass the gate).

---

## Usage flow

1. **Craft** a capture egg of the appropriate tier.
2. **Activate** it: hold the stack and run `/captureegg activate` (or `/ce activate`).
   - A confirmation dialog (or chat prompt, depending on `activation.confirmation-mode`) shows the cost.
   - Click **Confirm** or **Cancel** within 5 minutes (configurable via `activation.confirmation-ttl-seconds`).
   - The withdrawal is **all-or-nothing**: if you can't afford the entire stack, nothing is charged. The message tells you how many you *could* afford if you'd like to split the stack and retry.
3. **Capture** by right-clicking a mob with an active, empty egg.
   - The mob is removed; the egg becomes "filled" and shows what's inside in its lore.
4. **Release** by right-clicking a block or air with a filled egg.
   - The mob respawns at the click target (or 1 block in front of you if you click air).
   - Whether the egg is consumed or returned as an empty active egg depends on `release.consume-egg`.

---

## Commands

| Command | Description |
|---|---|
| `/captureegg activate` | Begin activation flow for the held stack. |
| `/captureegg confirm <token>` | Internal — invoked by Confirm button. |
| `/captureegg cancel <token>` | Internal — invoked by Cancel button. |
| `/captureegg info` | Inspect the held egg's stored data. |
| `/captureegg give <player> <tier> [amount]` | Admin: spawn an inactive egg into a player's inventory. |
| `/captureegg reload` | Admin: hot-reload `config.yml` and `messages.yml` (re-registers recipes too). |

Aliases: `/ce`.

All commands tab-complete via Brigadier — including `<player>` (Vanilla selector, supports `@p`/`@s`) and `<tier>` (suggests `copper`, `iron`, `gold`, `diamond`, `emerald`, `netherite`).

---

## Permissions

| Node | Default | Purpose |
|---|---|---|
| `captureeggs.craft` | true | Required to craft eggs when `recipe.permissions-required-to-craft` is on. |
| `captureeggs.activate` | true | Allow `/captureegg activate`. |
| `captureeggs.capture` | true | Allow capturing mobs by right-clicking. |
| `captureeggs.release` | true | Allow releasing mobs by right-clicking. |
| `captureeggs.bypass.cost` | op | Skip the economy withdrawal during activation. |
| `captureeggs.bypass.tier` | op | Capture any mob with any active egg, regardless of tier match. **Does not bypass the blocklist or the tameable-owner check.** |
| `captureeggs.admin` | op | Use `/captureegg give` and `/captureegg reload`. |

---

## Configuration

### `config.yml`

```yaml
economy:
  enabled: true
  costs:
    copper: 100
    iron: 250
    gold: 500
    diamond: 1500
    emerald: 2500
    netherite: 5000

# Disabling a tier removes its recipe and rejects activation/capture/release
# of any existing eggs of that tier with a graceful message.
tiers:
  copper:
    enabled: true
    recipe-ingredient: COPPER_INGOT
    custom-model-data: 1001
  iron:
    enabled: true
    recipe-ingredient: IRON_INGOT
    custom-model-data: 1002
  gold:
    enabled: true
    recipe-ingredient: GOLD_INGOT
    custom-model-data: 1003
  diamond:
    enabled: true
    recipe-ingredient: DIAMOND
    custom-model-data: 1004
  emerald:
    enabled: true
    recipe-ingredient: EMERALD
    custom-model-data: 1005
  netherite:
    enabled: true
    recipe-ingredient: NETHERITE_INGOT
    custom-model-data: 1006

recipe:
  # Single material or glob (`*_BARS`, `COPPER_*`, `*_INGOT`, …).
  frame-material: "*_BARS"
  permissions-required-to-craft: false

# Always-blocked entities. Applies to all tiers including netherite.
blocked-entities:
  - ENDER_DRAGON
  - WITHER
  - WARDEN
  - ELDER_GUARDIAN
  - BREEZE

capture:
  cooldown-seconds: 0          # 0 = no cooldown
  allow-with-passenger: false  # block capturing entities being ridden
  allow-leashed: true          # allow capturing leashed mobs (drops the lead)
  disabled-worlds: []
  effects: true                # particles + sound on capture

release:
  consume-egg: true            # false = leave an empty active egg in the stack
  disabled-worlds: []
  effects: true

activation:
  # How the confirmation prompt is presented:
  #   dialog - native Paper Dialog window (recommended; 1.21.7+)
  #   chat   - MiniMessage chat with [Confirm]/[Cancel] click buttons
  # Both routes run the same /captureegg confirm <token> internally.
  confirmation-mode: dialog
  confirmation-ttl-seconds: 300
```

### `messages.yml`

All messages use [MiniMessage](https://docs.advntr.dev/minimessage/) syntax. Tags like `<gold>`, `<click:run_command:...>`, and `<gradient:#ffaa00:#ffd966>` work out of the box. Defaults are baked into the jar; missing keys fall back to a clearly-labeled `missing key:` placeholder so you'll notice immediately.

The economy ledger template is plain text (it's written to the database, not chat):

```yaml
economy-ledger-template: "Capture Egg activation: <amount>x <tier> Tier"
```

---

## Integrations

### DogcraftEconomy (soft, direct dep)

When `DogcraftEconomy` is on the server, activations charge the configured per-tier cost via `api.withdraw(player, amount, message)` — atomic, with a properly-formatted ledger entry. When it's missing, activation is **free** and the dialog/chat prompt says so.

Repo (already in `pom.xml`): `https://repo.dogcraft.net/releases`. Version pinned to `1.0.3-624d2a8` at `provided` scope so the integration class compiles but the jar isn't shaded into the plugin.

### DogcraftClaims (soft, reflection)

When `DogcraftClaims` is on the server, capture and release inside a claim require **BUILD trust** (claim owner or Manage trustees count). When it's missing, all claim checks no-op.

The hook also reads the optional `MOB_SPAWNING` flag — if a claim has it explicitly disabled, releases inside that claim are blocked with `release.mob-spawning-disabled`. The hook auto-disables on the first reflection failure to avoid log spam.

### Defense-in-depth note

DogcraftClaims already protects tamed mobs network-wide — non-owners can't damage or interact with someone else's pet. Our **owner check is redundant** from a security standpoint but gives a specific error message (`That's not your pet.`) instead of the generic claim-side denial, and it works on standalone test servers without DogcraftClaims installed.

---

## Building from source

```bash
mvn clean package
```

Produces `target/Dogcraft-MobCapture-1.0-SNAPSHOT.jar`. Drop into `plugins/` on a Paper 1.21.11+ server.

Requirements:

- Maven 3.6+
- JDK 21
- Network access to `repo.papermc.io` and `repo.dogcraft.net` on first build.

---

## Troubleshooting

**The dialog never opens / I see chat clicks instead.**
The Dialog API is `@Experimental` on 1.21.x. If a server build has shifted the signatures, the plugin logs a warning and falls back to chat. Either upgrade to a newer Paper build, or set `activation.confirmation-mode: chat` in `config.yml` to silence the warning.

**Recipes don't show up in the recipe book.**
If `recipe.permissions-required-to-craft: true`, only players with `captureeggs.craft` get auto-discovery on join. If false, recipes are auto-discovered for everyone — but existing players who joined while it was true need to re-join (or you can run `/captureegg reload`, which re-applies discovery for online players).

**"That's not your pet."**
Hard rule. The mob is tamed and you aren't the owner. If you're staff trying to resolve an ownership issue, transfer ownership first via your normal pet-transfer tooling — capture eggs deliberately don't have a bypass for this.

**A captured villager respawned with no trades.**
This means the NBT round-trip failed and the listener fell back to a fresh spawn. Check the server log for a warning from `EntitySerializer`. The most common cause is a Paper version mismatch — `serializeEntity` formats are version-tied, so an egg captured on 1.21.11 should be released on 1.21.11+ (forward-compatible across the 1.21 → 26.1 jump, but not backward).

**Capture rejected with "That entity cannot be captured" on a normal mob.**
The entity is dead, mid-knockback (`isValid()` returned false), or has `0` health. Wait a tick or pick a different target. This guard prevents capturing corpses.

---

## Project layout

```
src/main/java/net/dogcraft/dogcraftMobCapture/
├── DogcraftMobCapture.java        # main plugin class, lifecycle wiring
├── activation/
│   ├── ActivateCommand bits live in CaptureEggCommand.java
│   ├── ActivationDialog.java      # Paper Dialog construction
│   ├── ActivationManager.java     # token store + TTL sweeper
│   ├── CaptureEggCommand.java     # native Brigadier root
│   └── PendingActivation.java     # record
├── capture/
│   ├── BlockedEntities.java
│   ├── CaptureListener.java
│   └── EntitySerializer.java      # full-NBT round trip
├── config/
│   ├── Messages.java
│   └── PluginConfig.java
├── integration/
│   ├── ClaimsHook.java            # reflection
│   └── EconomyHook.java           # direct compile-time
├── item/
│   ├── CaptureEgg.java            # data components + PDC
│   ├── EggKeys.java
│   ├── RecipePermissionListener.java
│   └── RecipeRegistrar.java
├── release/
│   └── ReleaseListener.java
├── tier/
│   ├── MobCategory.java
│   ├── Tier.java                  # enum (the source of truth)
│   └── TierResolver.java          # entity → category
└── util/
    ├── ItemUtil.java
    └── MM.java                    # MiniMessage helpers

src/main/resources/
├── paper-plugin.yml
├── config.yml
└── messages.yml
```
