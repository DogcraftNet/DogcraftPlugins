# ArmorstandArms

A lightweight Paper/Folia plugin for customizing armor stands with simple item interactions.

## Features

| Item | Action |
|---|---|
| Stick | Add arms to an armor stand (consumed) |
| Shears | Remove arms, drops a stick and any held item (1 durability) |
| Smooth Stone Slab | Add a base plate (consumed) |
| Flint | Remove the base plate, drops a smooth stone slab (consumed) |
| Iron Nugget | Toggle lock/unlock on an armor stand (not consumed) |

### Locking

Right-click an armor stand with an iron nugget to lock it. A locked armor stand cannot be modified or broken by other players. Only the player who locked it (or an operator with bypass permission) can unlock or interact with it. Lock data persists through server restarts.

## Permissions

| Permission | Description | Default |
|---|---|---|
| `armorstandarms.use` | Allows modifying armor stands | All players |
| `armorstandarms.bypass` | Allows modifying and breaking locked armor stands owned by others | OP only |

## Compatibility

- Paper 1.19+
- Folia supported

![demo](https://user-images.githubusercontent.com/44921987/213902537-5cddb4e7-27ae-4530-a600-b125a22d5370.gif)
