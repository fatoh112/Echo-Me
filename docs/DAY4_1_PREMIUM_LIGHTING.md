# Day 4.1: premium lighting and world polish (historical)

> Historical snapshot: this document describes the superseded Slavic Town / Compatibility-renderer pass. The active imported Mountain Village scene, current lighting values, route behavior, and editor bake notes are documented in [DAY5_MOUNTAIN_VILLAGE.md](DAY5_MOUNTAIN_VILLAGE.md). Numbers and scene paths below are preserved as historical Day 4.1 results.

## Scope

This pass keeps the Godot 4.7.2 Standard project on GDScript and the Compatibility renderer. It serializes the fixed Day 4 Slavic town as a static, low-overhead scene and prepares baked indirect lighting without adding runtime asset scans, scripts per prop, external SDKs, or new gameplay systems. Player controls, interaction, NPC schedules, physics, and saves remain authoritative and unchanged.

The playable scene is [neighborhood.tscn](../scenes/world/neighborhood.tscn), with authored town geometry in `SlavicTown`, collision in `AssetCollision` / `TownCollision`, small decorative MultiMeshes in `Props`, and a `LightmapGI` scope containing the lighting environment. Runtime now loads the authored scene instead of combining imported GLB assets again.

## Lighting and materials

- ACES tone mapping with a warm procedural sunset sky, warm directional sunlight, cooler ambient fill, one real-time directional shadow map, and two local Omni fill lights with shadows off.
- Medium-quality `LightmapGI` configuration, generated probes for moving characters, and a local `LightmapGIData` resource at [town_lighting.lmbake](../scenes/world/town_lighting.lmbake). Static town mesh batches and UV2 ground are marked `GI_MODE_STATIC`. The player/NPCs are `GI_MODE_DYNAMIC`, remain outside the baked town, and receive generated probe light.
- Compatibility SSAO and depth fog, subtle glow, and reflection probes localized to the square and merchant/tavern area. `--echo-low-graphics` disables SSAO, glow, sun shadows, and reflection-probe rendering while leaving gameplay unchanged.
- Shared original Slavic colorsheet and dirt textures with plaster, wood, stone, and roof roughness variants. The variants use no additional texture maps, low metallic values, and retain the source UVs and vertex colors.
- Irregular stone-apron tiles, sparse grass and shrub groups, a tree ring, and small fixed distant roof silhouettes break up the ground and horizon. No added collision uses blanket triangle meshes.
- Small signs, lantern geometry, and other primitive props remain in a handful of shadow-free, GI-disabled MultiMeshes. Imported town meshes are merged offline by 20 m spatial cell and material into ArrayMeshes; only landmark chunks cast the sun shadow.

## One editor bake action

Godot 4.7 does not expose the editor's LightmapGI bake operation as a GDScript `LightmapGI.bake()` method. The automation attempt confirmed that the method is not available. The scene and resources are prepared, but `town_lighting.lmbake` is still an empty target until the editor bake is run. Godot's built-in LightmapperRD can bake while the project uses Compatibility, using a temporary RenderingDevice ([Godot 4.7 LightmapperRD docs](https://docs.godotengine.org/en/4.7/classes/class_lightmapperrd.html)). The sun uses `BAKE_DISABLED`, so its direct lighting and shadow map remain real-time; LightmapGI will bake the scene's ambient environment fill and generated probes.

To complete the bake once in Godot, open `scenes/world/neighborhood.tscn`, select its `LightmapGI` node, and press **Bake Lightmaps** in the 3D editor toolbar. The data resource path is already configured as `scenes/world/town_lighting.lmbake`; save the scene if the editor marks it modified after the bake.

The bake itself and the saved result have not been verified in this automated run. Captures and measurements below are for Compatibility before indirect bake data is populated. Recheck them after the editor action because bounce light will change the final balance.

## Static mesh audit

The offline authoring command is `tools/build_baked_town_scene.gd`. Its [town_asset_selection.json](../data/environment/town_asset_selection.json) report records:

| Measure | Result |
| --- | ---: |
| Imported GLB mesh instances consolidated | 856 |
| Source vertices submitted | 546,140 |
| Generated UV2 bake meshes, including ground | 80 |
| UV2 vertex entries | 553,372 |
| Landmark shadow chunks | 39 |
| Source GLB files used | 33 |
| Town visual batches including ground | 83 |

Each static mesh has a unique UV2 chart covering every merged vertex. Source meshes retain UVs, normals, tint/vertex-color data, and the shared source atlas. Ground is a PlaneMesh with generated UV2. Tiny procedural geometry uses separate disabled-GI MultiMeshes and does not enter the lightmap atlas.

## Validation and captures

- Godot command-line regression suite: **1,375 checks, 0 failures** in both normal and `--echo-low-graphics` profiles. Run `tests/run_tests.gd -- --echo-validation` and add `--echo-low-graphics` for the second profile. It covers gameplay, movement, UI, NPC routes, collision, UV2/GI/material/shadow roles, and dynamic lighting for player/NPC models. Validation flags keep the production user save isolated.
- Compatibility renderer on an NVIDIA GeForce GTX 1050 Ti at 1280x720. Use `tests/render_preview.gd` for captures and `tests/benchmark_presentation.gd` for timing and draw-count profiles.
- Pre-pass captures are in `%APPDATA%/Godot/app_userdata/Echo Me/echo_me_premium_baseline`; current unbaked captures are in `%APPDATA%/Godot/app_userdata/Echo Me/echo_me_previews`. These machine-local screenshots are outside Git.
- The benchmark has four stages: effects/shadows off, SSAO+glow, directional shadows, then reflection probes enabled. It disables VSync and averages 180 frames after a 90-frame warmup. Driver/desktop compositor overrides can still affect timing.

| Build/profile | Average / median / p95 | Average FPS | Draw calls / objects |
| --- | ---: | ---: | ---: |
| Day 4 baseline commit `864a46b`, Compatibility, 1280x720 | 17.24 / 17.23 / 17.49 ms | 58 | 88 / 184 |
| Day 4.1 final, same mode and view, probes visible | 17.23 / 17.24 / 17.61 ms | 58 | 126 / 222 |

The 58 FPS results stayed on the system's approximately 60 Hz frame cadence despite VSync being disabled; they are a paced frame-time comparison, not an uncapped GPU ceiling. The final profile adds 38 draws in the benchmark view, mostly static spatial chunks and the sun shadow map, with a 0.12 ms higher p95 than the baseline under this cap. The benchmark's final profile on the current tree reported 17.23 ms, 126 average draw calls, and 222 average render objects.

## Manual checks after the bake

1. Launch with F5 in Compatibility and compare the street, square, merchant/tavern, residential row, alley, watch post, quarters, and player/NPC views with the local captures.
2. Confirm baked indirect fill softens shadow regions without visible seams, light leaks, or shadow terminators; inspect plaster, shared colorsheet details, wood, roof, cobbles, and dirt.
3. Walk beneath the merchant/tavern and residential roofs, circle the watch post, use the stair ramp, and verify roof meshes do not snag or offer unintended access.
4. Check the moving player/NPC in lit and shadowed areas; make sure generated probes carry ambient bounce and dynamic silhouettes remain legible.
5. Compare normal quality against `--echo-low-graphics` at the same window size. Directional sun shadows should remain the only real-time shadow map in normal quality; local lamps stay shadow-free.
