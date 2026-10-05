# Day 5: Mountain Village, NPC routes, and daylight

For the full environment inventory, hero-house mapping, NPC rig/model report, renderer and texture budget, see [PREMIUM_WORLD_REBUILD.md](PREMIUM_WORLD_REBUILD.md).

## Asset research

The main scene now uses the imported Mountain Surrounded Village Environment listed on [Fab](https://www.fab.com/listings/62667742-324a-4564-a288-316fe92c0059). Its public page describes four detailed houses with interiors, wells, twisted trees, mossy paths, rugged rocks, stone paths and walls, bridges, benches, and mountain cliffs. It lists GLB, FBX, and OBJ formats. The public listing does not provide an installation, lighting, or authoring manual, and the local GLB archive contains the model without a village-specific readme. Scene setup here is based on the provided asset, its included PBR textures, and the listing's visible reference images; no undocumented vendor settings are assumed.

## Runtime scene and rendering

- `scenes/world/premium_village.tscn` is the active town scene. The original GLB source remains under `assets/environment/mountain_village/`; the runtime scene uses the offline-authored `scenes/world/mountain_village_optimized.tscn` rather than instantiating the full source scene.
- The optimized static scene contains 59 spatial PBR mesh batches. Its structural collision is grouped into 6 bodies with 425 box shapes; it has no triangle-mesh collision. Source albedo, normal, and roughness maps remain active.
- Imported static meshes use `GI_MODE_STATIC` and generated UV2. Player/NPC models are dynamic and stay out of the town lightmap. The main scene has a scene-level `LightmapGI` target at `scenes/world/premium_village.lmbake`.
- The runtime environment uses a blue daytime procedural sky, warm low-angle directional sun, ACES tone mapping, screen-space occlusion, and distance fog. Only the directional sun casts real-time shadows. Local warm lights stay shadowless and short-range. `--echo-low-graphics` disables costly screen-space effects and the sun shadow map.
- The latest 1152x648 capture set is generated outside Git by `tests/day5_capture.gd` at `user://echo_me_previews/`. It logged 89 visible render batches in the overview and 82 in the town-square view.

### Lightmap bake

The LightmapGI node and external target are configured, but a saved editor bake still needs to be produced. Open `scenes/world/premium_village.tscn` in Godot, select its `LightmapGI` node, press **Bake Lightmaps** in the 3D editor toolbar, and save the scene. This uses Godot's editor lightmapper; the game does not attempt a bake at runtime. Check shadowed paths and house interiors after baking for leaks and seams.

## NPC movement and animation

- `data/npc_walkways.json` controls the collision-derived local route grid: 1.25 m spacing, a six-cell patch radius, and short random pauses. It stores settings, not hand-guessed path coordinates.
- `scripts/systems/npc_path_router.gd` samples the imported collision for supporting floor and standing capsule clearance, then connects safe cardinal neighbors. An ACTIVE NPC picks among open junctions and rebuilds its graph at the patch edge. NPCs retain CharacterBody3D collision and cannot path through the broad imported wall/rail collision boxes. Route generation only runs for nearby ACTIVE NPCs; BACKGROUND and LOGICAL NPCs do not move.
- NPCs use the shared offline-retargeted animation library generated from the player's supplied locomotion clips. The route controller selects WALK while moving and preserves the same walk/run/sit/jog/jump clip hooks for NPC preview and later behaviors.
- The player crouches while holding **C** or **Ctrl**; crouch lowers the capsule and camera, reduces movement speed, and selects the crouch pose. The player remains standing if an overhead collision prevents it.

## Verification and manual checks

The headless Godot self-test commands are:

```powershell
& 'F:\mehmed fethelier sultani\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'F:\echo me' --script res://tests/run_tests.gd -- --echo-validation
& 'F:\mehmed fethelier sultani\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'F:\echo me' --script res://tests/run_tests.gd -- --echo-validation --echo-low-graphics
```

Both profiles pass **867 checks, 0 failures**. Route checks verify all six scheduled NPC positions have connected walkable patches, junctions return varied choices, and an active NPC travels along a collision-checked route. Environment checks also verify the 59-batch town, grouped box collision, source PBR maps, six NPC rigs, and daylight settings.

On the GTX 1050 Ti, the medium-profile presentation benchmark reported 17.24 ms average, 17.23 ms median, and 17.54 ms p95, with 65 average draw calls and 171 average render objects in the final lighting stage. The observed 58 FPS is still paced near 60 Hz with VSync disabled, so it is not an uncapped GPU ceiling. The render preview and benchmark complete, but Godot 4.7.2's D3D12 startup logs `CreateResource failed (0x80070057)` and an invalid texture RID/leak at shutdown; the headless tests have no such renderer warnings.

In Godot, manually check:

1. Walk from the square across the main stone lanes, around the well, bridge, walls, and house thresholds. Watch nearby NPCs walk and pause; confirm they stay on open ground and do not clip through walls or railings.
2. Use **C** and **Ctrl** to crouch and release both in open ground and beneath a low ceiling. Confirm the character stands only when the full capsule clears.
3. Compare the square, back alley, interiors, and cliff rim with the Fab reference. Check bright sun patches, diagonal tree shadows, PBR surface detail, and legibility in shadow.
4. Bake LightmapGI once in the editor, then inspect the same locations for light leaks, seams, or overly dark interiors.
5. Use F3 to inspect an NPC's current/next route IDs and the animation preview states.
