# DogcraftExtras

A lightweight Paper plugin that ports select [Purpur](https://purpurmc.org/) convenience features to Paper for the [Dogcraft](https://dogcraft.net/) server. Each feature can be individually toggled and configured via `config.yml`.

## Features

### Anvil MiniMessage

Allows players to rename items in an anvil using [MiniMessage](https://docs.advntr.dev/minimessage/format.html) syntax. For example, typing `<rainbow>Cool Sword</rainbow>` will produce a rainbow-colored item name. Italic styling is automatically removed from renamed items for a cleaner look.

- Gated behind the `dogcraftextras.anvil.minimessage` permission (default: op only)
- The permission node can be changed or removed entirely in `config.yml`
- Invalid MiniMessage syntax falls back to vanilla rename behavior

### Random Shulker Colors

Naturally spawning shulkers are assigned a random dye color instead of the default purple. This applies to all spawn reasons except spawn eggs, commands, and plugin-spawned shulkers, so manually placed shulkers keep their intended color.

### Phantom Torch Repel

Holding a torch (regular, soul, or copper) in your main hand or off hand prevents phantoms from spawning on you. Uses `PhantomPreSpawnEvent` to cancel the spawn before it happens.

### Stonecutter Damage

Players standing on a stonecutter continuously take damage, because a spinning blade should probably hurt. A repeating task checks all online players at a configurable interval. Skipped for Creative and Spectator mode.

- Configurable damage amount (default: `1.0` half-hearts per tick)
- Configurable tick interval (default: every `10` ticks / 0.5 seconds)

### Shears Sprint Damage

Sprinting while holding shears in either hand periodically damages the player - running with scissors is dangerous. A repeating task checks all online players at a configurable interval.

- Configurable damage amount (default: `0.5` half-hearts per tick)
- Configurable tick interval (default: every `10` ticks / 0.5 seconds)
- Skipped for Creative and Spectator mode

## Configuration

All settings live in `config.yml`, generated on first run. A restart or reload is required after changes.

```yaml
features:
  anvil-minimessage: true
  shulker-random-color: true
  phantom-torch-repel: true
  stonecutter-damage: true
  shears-sprint-damage: true

anvil-minimessage:
  permission: "dogcraftextras.anvil.minimessage"

stonecutter-damage:
  amount: 1.0
  period-ticks: 10

shears-sprint-damage:
  amount: 0.5
  period-ticks: 10
```

## Permissions

| Permission | Description | Default |
|---|---|---|
| `dogcraftextras.anvil.minimessage` | Use MiniMessage formatting in anvil renames | op |

## Building

Requires **JDK 25** and **Maven**.

```
mvn package
```

The compiled jar will be at `target/dogcraft-extras-1.0.0.jar`. Drop it into your server's `plugins/` folder.

## Compatibility

Built against **Paper 26.1.2**. The API surface used is stable and should work with nearby versions - just update the `paper-api` version in `pom.xml` and the `api-version` in `plugin.yml` if needed.

## Notes

- The anvil listener uses `PrepareAnvilEvent`, which fires as the player types. The parsed result is only applied when the item is taken out.
- `isSprinting()` is client-reported, so a determined client could spoof it. Not a concern for normal gameplay.
- Stonecutter damage uses a repeating task that checks all online players, similar to the shears sprint task.
