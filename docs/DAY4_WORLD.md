# Day 4 — medieval town environment

## Baseline and scope

Started from Day 3.5 commit `5ef4370` (512 checks). Godot 4.7.2 Standard,
GDScript, Compatibility renderer. `project.godot`, the Kachujin controller,
animation library, NPC identities, schedules, action/Echo systems, relationships,
memories, save schema and migration rules are preserved.

The old visible box buildings, primitive fountain, toy trees, market tables,
barrels, benches and thousands of tiny paving boxes have been replaced. The
replacement layout passed the original route, collision, camera, interaction,
animation, save and simulation checks before the old geometry was retired.
Small signs and emissive lantern fittings still use shared primitive meshes.

## Supplied asset pack

**Slavic Medieval Town Kit Lite**, supplied locally under
`res://assets/environment/slavic_town/`. No additional asset downloads.

The recursive catalogue is `data/environment/slavic_town_sources.json`:
225 GLBs, 225 meshes, 358,010 source vertices, five PNGs and a source PSD.
No FBX files or explicitly named LOD tiers were present in this supplied copy.
The 14 unnamed `Cube` exports have been recorded, rather than assumed to be LODs.

| Category | Available examples / use |
| --- | --- |
| Complete building | `Town_Building_Administrative _01a`; inspected, unused |
| Modular walls | Log fronts, painted side walls and plaster/timber fronts; assembled into houses |
| Roofs | Thatch roof and cut gable variants; log merchant roof and plaster cottage/inn roof |
| Doors / windows | `House_Door_01b`, `House_Shutter_01e`; closed exterior facades |
| Stairs | Porches, step platforms and tower stair; only the tower stair used |
| Fences / authority | Cobble fence, roofed log wall, `Village_Tover_01a` watch tower |
| Roads / ground | Two cobble road meshes and `Pobbles_Sand_Dirt.png` |
| Merchant / market | Open wood-roof shelter, table, baskets, vegetables, apples and sacks |
| Tavern | Two-story house assembly, benches, tables, mugs and barrel groups |
| Square landmark | `Prop_Village_Whell_01d` is a covered well, verified by rendering |
| Household clutter | Crates, barrels, firewood and `Stand_Sheet_01a` drying rack |
| Vegetation | Two small town-tree variants, low-vertex distant tree, shrub and edge grass |
| Carts / lanterns | No identifiable standalone cart or lantern model in this copy; small bespoke emissive lanterns retained |
| Signs | Chapel sign and drying rack exports exist; readable town/shop signs use small fitted boards and Label3D |

The exact 33 GLBs used, instance counts and geometry budget are in
`data/environment/town_asset_selection.json`. All 225 source models remain
available for later authoring; they are not all loaded by gameplay.

## World layout

All seven logical IDs, bounds and anchor positions remain unchanged. Only
presentation offsets in the square and residential lane were adjusted to separate
NPCs and their labels. Nearby labels are visible within 10 m.

| Zone | New exterior |
| --- | --- |
| `PLAYER_QUARTERS` | Plaster/timber cottage, closed door, home sign, firewood, lantern; spawn `(0, 0, 11)` faces town |
| `TOWN_SQUARE` | Covered well, weathered cobbles, benches, sparse trees, shop and inn sightlines |
| `MERCHANT_SHOP` | Log-front shop, clear signed door, sheltered counters, baskets, produce, sacks and cargo |
| `TAVERN` | Warm two-story Amber Hearth, door lanterns, outdoor tables, mugs, benches and barrels |
| `RESIDENTIAL_ROW` | Staggered cottage, taller inn-style house, log house, drying rack, garden fences and firewood |
| `BACK_ALLEY` | Rough roofed log walls, darker house tint, stacked crates, sack and barrels; clear camera-sized route |
| `WATCH_POST` | Timber watch tower, signed entrance, simple fence, cargo, usable stair ramp and upper landing |

The well splits the main street: walk around it, using the eastern paved route.
The former half-meter-sampled protected routes are still clear. A new capsule
grid checks continuous connections from spawn to all zones and all six NPCs at
seven schedule times. There is no NavigationRegion3D to rebake; existing NPCs
retain their discrete schedule/Utility simulation.

At 17:00, Alex works at the shop, Emma at the tavern, Sarah visits the square,
Mike is home, David uses the alley and Noah patrols the square. Noah's watch-post
shift is 06:00–14:00. The world continues using its existing logical clock.

## Reusable scenes and scale

New scene wrappers under `scenes/environment/`:

- `house_cottage.tscn`
- `house_merchant.tscn`
- `house_inn.tscn`
- `market_stall.tscn`
- `barrel_group.tscn`
- `bench.tscn`
- `fence_segment.tscn`
- `well.tscn`
- `watch_tower.tscn`

These are ordinary scene/resource assemblies with no decorative frame scripts.
`scripts/world/neighborhood.gd` authors their fixed placement.
`scripts/world/asset_town_builder.gd` collects their shared imported meshes into
MultiMesh batches and copies only authored simple collision shapes.

Native wall story heights are approximately 2.98–3.13 m and stay at vertical
scale 1.0. Native 20.02 m side-wall modules are fitted horizontally to 8.8/10 m
house depths. The same door transform is used in every assembled house:
2.5307 m × 0.9 = **2.278 m**. Kachujin remains **1.82 m**. Roof dimensions/eave
offsets are explicit wrapper transforms, rather than a different arbitrary scale
for each placed house. The well uses uniform 0.75 scale; tower lowest pivot is
raised 0.5033 m to align its source ground with world ground.

Buildings and fences use box collision, well posts use cylinders, and small
goods have no collision. The watch's 44-degree stair ramp and 3.49 m landing
match the source steps and work with the existing CharacterBody3D. Road relief
is flattened to about one centimeter over a single stable level ground collider.
The well has simple base, post and roof collision, including camera obstruction.

## Materials and performance

- All GLBs contain the same embedded palette PNG. Its SHA-256 matches the
  supplied `EA03_FREE_Slavica.png`:
  `139F70A56E475755347B4FCAF4C8640F209B7B49133047D00C3B1F11DE277F5C`.
- `tools/environment_post_import.gd` assigns one shared `slavic_atlas.tres`
  material and discards extracted embedded images. Original UVs, vertex colors,
  normals and double-sided rendering remain. Metallic is corrected to 0 and
  roughness to 0.88, avoiding the source's shiny default metal appearance.
- One ground texture/material is reused. Foliage is opaque geometry; unused
  flower/grass texture variants are not loaded by the town.
- 534 imported mesh instances + 68 small sign/lantern pieces, **37 town render
  batches including ground**, **395,832 submitted asset vertices** before LOD.
- Godot import-generated LODs remain enabled; asset batches use LOD bias 0.8.
  Shadow mesh generation is disabled because the world casts no real-time shadows.
- One sunset directional light and two small local lamps, all shadow-free.
  Decorative lanterns are emissive. No GI, volumetric effects, triangle collision,
  runtime directory scans or per-prop processing.
- NPC ACTIVE/BACKGROUND/LOGICAL handling remains unchanged. Repeated meshes,
  materials and source textures are shared; source assets are not duplicated.

Rendered validation runs on the installed GTX 1050 Ti at 1280×720, OpenGL 3.3
Compatibility: **30–106 draw calls** across the captured world views.
Draw-call readings are recorded in the capture utility's output;
they include NPCs and UI, so are higher than the 37 environment batches. This
is a render/collision validation, not a benchmark of the i7-2600 or weaker GPUs.

## Intentionally unused assets

The large administrative building, large foundations, raised porches, incomplete
sheds, river/terrain pieces, chapel cross, animal trophies/skins, interior beds,
cooking props, ladders, high-vertex trees, duplicate roof variant and unnamed
exports are not placed. They either need a larger footprint, do not fit this
exterior slice, would introduce uneven traversable terrain, or have more geometry
than this layout needs. The complete source catalogue documents their bounds.

## Validation

Portable console executable:
`F:/mehmed fethelier sultani/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.

Run from the repository root in PowerShell:

```powershell
$echoGodot = 'F:\mehmed fethelier sultani\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $echoGodot --headless --editor --path . --import
& $echoGodot --headless --path . --quit-after 120 -- --echo-validation
& $echoGodot --headless --path . --script res://tests/run_tests.gd -- --echo-validation
& $echoGodot --headless --path . --script res://tools/validate_environment_resources.gd -- --echo-validation
& $echoGodot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/render_preview.gd -- --echo-validation
& $echoGodot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/render_animations.gd -- --echo-validation
```

Results: **888 automated checks, zero failures**; import, headless main and
225-source resource audit are clean. A temporary copy containing only repository
files, without `.godot` caches, also imports cleanly and passes all 888 checks
and the full source audit. The original 512 checks remain, with new environment
checks for resources, sharing,
simple collision, connected zones, scheduled NPC clearance/reachability/grounding
and normal walking onto the watch landing. The obsolete blockout-specific count
of 1,000 tiny boxes is replaced by a stronger imported-detail requirement
(over 100,000 vertices and 200 real mesh instances), retaining the 40-batch limit.
No gameplay or animation assertion was removed or weakened.

World captures: spawn, main street, square, merchant, tavern, residential row,
alley, watch post, home exterior, player near Sarah, interaction, overview,
player front, debug collision and offline summary. Inspected every required view;
fixed lifted roof seams, oversized paving, the obstructed shop doorway, repetitive
background tree placement, label clutter and the stair/landing collision.
Animation captures cover Idle, Walk, Run, Jump, lateral movement, backward travel,
Talk, Sit and the normal running camera. Captures and logs stay outside Git under
`user://echo_me_previews`, `user://echo_me_animation_previews` and Windows TEMP.
All engine validation uses `--echo-validation`, preserving production saves.

Rebuild the authoring catalogue with `tools/catalogue_environment.ps1`. Rebuild
the used-source manifest by adding `--write-selection` to the resource audit.

## Manual F5 acceptance pass

1. Launch the main scene with F5. Check home/spawn, then walk around the well
   toward the square, merchant, tavern, houses, alley and watch tower.
2. Use WASD, mouse look, Shift, Space and lateral movement. Check feet on ground,
   camera retraction at house walls, alley clearance and the watch stairs/landing.
3. Find Alex, Sarah, Mike, Emma, David and Noah in their scheduled locations.
   Approach within interaction distance and press E. Check labels and clear access.
4. Use Help/Give/Insult/Steal or the other existing actions. Press F3 to confirm
   behavior, inverse Echo traits, relationships and memory consequences still update.
5. Save/quit with F10, wait at least 60 seconds and relaunch. Check the existing
   While You Were Gone flow and PLAYER-attributed memories, then resume walking.

### Other created/modified files

Created: the nine wrapper scenes above, `asset_town_builder.gd`,
`tests/environment_checks.gd`, `tools/catalogue_environment.ps1`,
`tools/environment_post_import.gd`, `tools/preview_environment_assets.gd`,
`tools/validate_environment_resources.gd`, both environment JSON reports, this
document, two shared material resources, source pack files and their import
sidecars. Godot script UID sidecars are tracked.

Modified: `AGENTS.md`, `data/neighborhood.json`, `scenes/npc/npc.tscn`,
`scripts/world/neighborhood.gd`, `tests/visual_checks.gd`, `tests/run_tests.gd`,
`tests/render_preview.gd` and the diagnostic camera angle in
`tests/render_animations.gd`. The existing main/world/player scenes and
`project.godot` are preserved.
