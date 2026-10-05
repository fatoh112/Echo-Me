# Scene cleanup and consolidation

## Runtime scene ownership

`scenes/main.tscn` remains the only main scene and owns one player, one `PremiumVillage`, one NPC manager, one save manager, and the interaction and debug UI. `scenes/world/premium_village.tscn` instances the optimized Mountain Village and now contains the authored `PlayerStart` marker.

The baked Slavic `scenes/world/neighborhood.tscn` remains available as a non-instanced fallback for its existing authoring and validation tools. The runtime does not instance it alongside the Mountain Village. The smaller environment scene wrappers and lighting resources also remain because fallback and resource-validation code still references them.

## Removed legacy actor prefab

Removed `scenes/npc/alex.tscn` and `scripts/actors/alex_controller.gd`. The scene was a standalone capsule placeholder and was not used by the active NPC manager. Alex continues to use the shared `NPCData`/`NPCController` implementation and keeps the existing `alex` ID, relationships, and memories.

## Player house entrance and start

`PlayerStart` is outside the player house at `(17.0, 1.303, -80.95)`, on the imported cobbled ground near its entrance, facing the village square. The same position is stored as `PLAYER_QUARTERS.spawn_position`; the existing `PLAYER_QUARTERS.position` remains the house's logical location.

The optimized house facade had one collision box spanning the full doorway. Its authored collision is now split into two wall sections and a lintel, leaving a 1.4 m opening. The imported `Wall_400x244` upper panel remains visible, while its oversized box is omitted because it falsely blocked the doorway at player height. The one-time village scene builder contains both collision corrections so rebuilding the optimized scene preserves the route.

On load, valid saved village positions remain in place. A position still near the old player-house anchor is treated as the retired doorway start and moved to `PlayerStart`; positions outside the village, blocked by collision, or lacking ground also recover there. Recovery preserves the player's profile and history. Falling below the world uses the same safe spawn. Test runs use `--echo-validation` and do not write the production save.

## Verification

- Godot MCP scene/script lint: 0 errors. Its 7 warnings are existing animation setup, fallback collision, and editor-first warnings.
- Portable Godot 4.7.2 simulation suite: 923 checks, 0 failures.
- Headless main-scene startup: completed with 59 render batches, 6 collision sections, and 426 box shapes.
- Live play: confirmed the player starts outside, can walk around the house, enter through the doorway, and exit again. The original production save was restored and its SHA-256 matched the pre-play backup.
- The MCP desktop play session logged 17 uninitialized-RID startup messages, matching the renderer/RID error category already present before this pass. Script lint and headless startup were clean.
