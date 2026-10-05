# Premium world rebuild

## Environment pack inventory

The active world uses the supplied **Mountain Surrounded Village Environment** from [Fab](https://www.fab.com/listings/62667742-324a-4564-a288-316fe92c0059). The listing describes four furnished houses, wells, twisted trees, mossy paths, rugged rocks, stone walls and paths, bridges, benches, and surrounding cliffs. It lists GLB, FBX, and OBJ formats, but publishes no installation, lighting, or authoring manual. The downloaded local archive contains the GLB model without a village-specific readme. The 271 MB source GLB remains in the local workspace and is not committed because GitHub rejects individual files over its normal 100 MB limit. Runtime uses the optimized mesh resources and separate PBR textures committed here. To regenerate the optimized scene, download the free source pack from the linked Fab listing and place its GLB at the path expected by `tools/build_day5_village_scene.gd`. The editor setup follows the actual GLB, its included PBR textures, and the listing screenshots.

The complete source inventory is [day5_asset_inventory.json](../data/environment/day5_asset_inventory.json). It records 706 placed mesh instances, 43 unique mesh resources, 32 surface materials, 20 imported point lights, approximately 3.55 million source triangles, and an 82.9 × 116.4 m footprint with 24.2 m of vertical relief. The authored runtime scene consolidates static visuals into 59 spatial PBR batches, grouped into 6 collision bodies with 425 box shapes. It keeps the source albedo, normal, and roughness textures and generates UV2 for static lightmapping. The source scene is not duplicated into the live scene.

### Hero houses and interiors

All four complete source houses remain physically enterable, with the door leaves omitted where the source doors were closed. The retained location IDs and physical role mapping are:

| Gameplay role | Logical location | Approximate house center | Interior dressing |
| --- | --- | ---: | --- |
| Player home | `PLAYER_QUARTERS` | `(13.2, -81.0)` | Source pack's bedroom, fireplace, table, chair, and interior props |
| Alex's merchant shop | `MERCHANT_SHOP` | `(37.0, -79.5)` | Source pack's furnished shop interior |
| Emma's tavern | `TAVERN` | `(41.5, -57.0)` | Source pack's furnished inn interior and fireplace |
| Residential home for Sarah/Mike | `RESIDENTIAL_ROW` | `(24.0, -92.0)` | Source pack's furnished residential interior |

The player uses a colliding `SpringArm3D` with a sphere shape and short margin so the third-person camera retracts against interior walls. Main door clearances, floor support, NPC schedule spawns, and all four logical locations have regression checks. Warm source point lights remain shadowless and are clamped to a maximum 8 m range and 1.4 energy. The old Slavic Town scene remains only as a non-instanced fallback; it is absent from the live scene tree.

## NPC model selection and rig status

The NPC inventory includes 14 unique models in two FBX export variants. The selected six are distinct and remain visual children of the authoritative `NPCController`:

| NPC | Model | Source triangles | Rig | Source texture |
| --- | --- | ---: | ---: | ---: |
| Alex | `rich_citizens_2` | 2,362 | 41 bones | 64×64 atlas |
| Sarah | `peasant_2` | 2,280 | 41 bones | 64×64 atlas |
| Mike | `city_dwellers_1` | 3,005 | 41 bones | 64×64 atlas |
| Emma | `peasant_5` | 2,516 | 41 bones | 64×64 atlas |
| David | `rich_citizens_3` | 2,381 | 41 bones | 64×64 atlas |
| Noah | `king` | 2,716 | 41 bones | 64×64 atlas |

The source pack provides no animation players. Its models share the compatible 41-bone rig, so `tools/bake_npc_locomotion.gd` retargets the player's supplied animation library offline. The resulting shared library contains 16 clips, including Idle, Walk, Run, Jog, Sit, Jump, Strafe, Talk, Crouch, and Crouch Walk. Animation stays visual-only; NPC collision and motion live on their CharacterBody3D roots. NPC animation evaluates only at ACTIVE distance.

**Source-asset limit:** the supplied character product is named “Free Medieval 3D People Low Poly Pack”; the models are roughly 2–3k triangles and use 64×64 textures. They satisfy the six-character, distinct-model, and shared-animation requirements, but they are not realistic or high-detail human models. The village pack provides no replacement character assets. A later photoreal character pass needs higher-detail character source assets.

## Renderer, textures, and lighting

- Desktop renderer: Forward+ on Godot 4.7.2 Standard / Windows. The project retains the mobile Compatibility rendering method.
- The 32 source materials use predominantly 1K maps (121 map references), six 2K map references, three 4K map references, and small 1×1 fallback maps. No 8K material maps are present. The source 4K maps are retained for the visible hero assets.
- Static village meshes use `GI_MODE_STATIC` with generated UV2. Player and NPC meshes use `GI_MODE_DYNAMIC` and stay outside the bake. One scene-level LightmapGI is configured at `scenes/world/premium_village.lmbake`.
- The runtime look uses a blue daylight procedural sky, ACES tonemapping, warm low-angle sun at energy 1.82, a single real-time directional shadow, contact occlusion, and distance fog. The sun direction lights the central approach shown in the Fab images. Screen-space reflections stay off. MEDIUM keeps SSAO/glow and the sun shadow; HIGH additionally enables SSIL and volumetric fog. `--echo-low-graphics` disables SSAO, glow, and sun shadows.
- The source GLB contains 20 point lights; they stay shadowless, with range capped at 8 m and energy capped at 1.4. No local light creates an additional real-time shadow map.

### Remaining editor bake

The current `LightmapGIData` target is configured, but it has no newly baked village atlas yet. Godot 4.7 exposes lightmap baking as an editor operation, not a runtime game action ([LightmapGI documentation](https://docs.godotengine.org/en/4.7/classes/class_lightmapgi.html)). Open `scenes/world/premium_village.tscn`, select `LightmapGI`, press **Bake Lightmaps** in the 3D editor toolbar, and save. Then inspect interiors, paths, and cliff shadows for leaks or seams. The runtime lighting and real-time sun are already configured while the bake is pending.

## Navigation and performance

Nearby ACTIVE NPCs use a bounded local graph built from the imported collision. `data/npc_walkways.json` sets a 1.25 m cell spacing, six-cell patch radius, and random pauses. The router accepts a node only if it finds supporting floor and the standing capsule fits; links require clear midpoint space. NPCs choose randomly at junctions and rebuild at a patch edge. The graph is navigation data only: it does not generate or change the world. BACKGROUND and LOGICAL NPCs do not move.

On the GTX 1050 Ti, the medium-profile presentation benchmark reported 17.24 ms average, 17.23 ms median, and 17.54 ms p95, with 65 average draw calls and 171 average render objects in its final lighting stage. The observed 58 FPS remains paced near 60 Hz with VSync disabled, so it is not an uncapped GPU ceiling. Godot's D3D12 startup logs `CreateResource failed (0x80070057)` plus invalid texture RID/leak warnings during the graphical capture and benchmark, although both runs completed and generated output. Headless tests do not produce these renderer warnings.

## Verification

The full headless suite passes **867 checks, 0 failures** in both MEDIUM and `--echo-low-graphics` profiles. It verifies all six NPC schedule positions can build a connected route, random junction choices, active NPC movement, the four doorway clearances, floor support, six distinct NPC rigs, the 59-batch environment, static PBR collision roles, source materials, and existing gameplay/save systems.

The full visual capture harness is `tests/day5_capture.gd`; its images are written to `user://echo_me_previews/`, outside Git. The scene collection covers spawn, village overview, square, all four exteriors/interiors, alley, watch area, six-NPC lineup, player beside Alex, indoor player camera, night-like fireplace, mountain background, ground, and roof.

## Assets not used at runtime

- The full 706-node source scene is kept locally as reference and as input to the scene builder; it is excluded from Git because its GLB exceeds GitHub's single-file limit. The live game uses the committed 59-batch optimized scene.
- Eight closed door leaves are omitted so the important doorways stay open.
- The old Slavic Town visual scene is retained for fallback/save compatibility but is not instanced in the playable world.
- The other eight unique medieval NPC models and duplicate FBX export variants are inventoried but not instantiated.
- Imported local shadows, SSR, and triangle-mesh collision are disabled or omitted for the 1050 Ti performance target.
