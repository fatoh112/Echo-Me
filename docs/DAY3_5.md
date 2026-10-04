# Day 3.5 — player locomotion and animation system

## Animation audit

All 15 supplied FBXs were inspected with Godot 4.7.2. Every rig has the same 75 bone names and hierarchy as the authoritative Kachujin skeleton. Imported root/skeleton transforms have unit scale and identity orientation; the mesh remains normalized to 1.82 m with +Z corrected to controller -Z. Animation-only exports differ by at most 0.01046 m / 1.001° in rest transforms; the offline bake corrects those differences. Native FBX TimeMode is 6 (30 FPS) for every source, and import baking uses 30 FPS. Optimized tracks retain fewer keys for slow motion; their key density is not the source frame rate.

| Source | Original length | Library state | Use |
| --- | ---: | --- | --- |
| Idle.fbx | 8.333 s | IDLE | looping idle |
| walking.fbx | 0.967 s | WALK | looping forward/backward travel |
| running.fbx | 0.700 s | RUN | looping Shift run |
| Jogging.fbx | 2.567 s | JOG | developer preview / reusable gait |
| jump.fbx | 1.667 s | JUMP | trimmed 0.43–1.40 s; nonlooping airborne pose |
| left strafe walk.fbx | 0.933 s | STRAFE_LEFT | normal lateral travel |
| right strafe walk.fbx | 0.933 s | STRAFE_RIGHT | normal lateral travel |
| left strafe.fbx | 0.667 s | STRAFE_LEFT_RUN | fast lateral blend |
| right strafe.fbx | 0.667 s | STRAFE_RIGHT_RUN | fast lateral blend |
| Talking.fbx | 5.167 s | TALK | timed conversation, movement cancels |
| Sitting.fbx | 9.567 s | SIT | looping seated preview; no seating gameplay |
| left turn.fbx | 1.167 s | TURN_LEFT | nonlooping preview only |
| right turn.fbx | 1.167 s | TURN_RIGHT | nonlooping preview only |
| Female Start Walking.fbx | 1.867 s | START_WALK | nonlooping preview only |
| Kachujin G Rosales.fbx (animation folder) | 0.033 s | excluded | duplicate model with a single bind pose |

The supplied lateral clips face along their baked ±X travel, with approximately ±90° hip yaw. The bake normalizes that facing to +Z and removes XZ root movement. Body rotates toward actual movement, including A/D and backward input; this is a free-facing exploration controller rather than fixed-facing sidestepping. Fast/slow lateral clips blend by resolved speed. Turn clips end 90° away from their starting orientation, so gameplay uses smooth procedural facing. The slow start-walk clip would visibly lag immediate movement, so it remains a preview capability. Jog is available without forcing it into the walk/run transitions.

Original clip names, bone names, transforms, root ranges, seam angles, optimized key rates, and native frame rates are recorded in `data/animations/source_inspection.json`. The usable mapping, loop flags, durations, and measured stride speeds are in `data/animations/player_clips.json`.

## Implementation

- One authoritative skeleton and mesh; runtime loads the compressed 499 KB `player_locomotion.res` AnimationLibrary. No animation FBX scenes are instantiated by gameplay. All tracks bind only existing bones, and there are no mesh/material/texture dependencies in the baked library.
- CharacterBody3D owns movement, collision, gravity, and jump height. Root XZ is fixed for every clip; JUMP root Y is fixed to prevent a second animated jump arc.
- Configurable defaults: walk 3.4 m/s, run ×1.7 = 5.78 m/s, jump velocity 4.8 m/s, facing response 12. The previous 5 m/s static-model speed was reduced to a brisk animated walk. Cadence follows actual horizontal velocity divided by measured source stride speed.
- AnimationTree state machine with 0.18 s crossfades and per-state TimeScale nodes. Lateral gaits use BlendSpace1D. JUMP overrides locomotion while airborne; TALK lasts 2.5 s by default, expires automatically, and cancels on movement. SIT and optional gaits use the debug preview interface.
- Animation evaluates manually once per physics tick after controller movement. References, state playback, clip data, and resources are cached. Camera remains under the player SpringArm, independent of bones.
- F3 displays animation, speed, grounded state, and mouse-operated preview/stop buttons. Previews expire after four seconds; WASD or hiding F3 cancels them. No extra editor function keys are bound.
- NPCVisual can replace placeholder geometry with a PackedScene and cache optional AnimationPlayer/AnimationTree hooks. Background/logical models stop animation processing. NPC relationship, memory, schedule, and controller logic remain independent of bones.
- Targeted town fix: quarter/watch signs raised and moved clear of lanterns; sign text fits board width. Town geometry and NPC placement remain otherwise as Day 3.
- Animation FBX import sidecars discard embedded images. Sixteen unused image/sidecar files from the previous Idle/start-walk imports were removed. The unused local archive and duplicate bind-pose model are ignored and preserved locally.

## Files

New permanent resources: `assets/animations/player/player_locomotion.res`, the 12 newly used animation source FBXs and their import sidecars, `data/animations/player_clips.json`, `data/animations/source_inspection.json`.

New authoring utilities: `tools/inspect_animations.gd`, `tools/bake_player_animations.gd` (and Godot UID sidecars). New validation: `tests/animation_checks.gd`, `tests/render_animations.gd` (and UID sidecars). This report is `docs/DAY3_5.md`.

Updated: AGENTS.md, .gitignore, PlayerController, PlayerVisual, MixamoAnimationLoader, NPCVisual, NPCController, main.gd, DebugUI, InteractionUI, neighborhood.gd, tests/run_tests.gd, tests/visual_checks.gd, existing Idle/start-walk imports, replaced Idle FBX, and authoritative player texture import settings (the user's 1K VRAM compression changes retained). No new scenes; existing player/main/NPC scenes are reused. project.godot is preserved.

## Validation

Portable Godot 4.7.2 import, main scene load, player scene load, and automated suite: **512 checks, zero failures**. All prior 322 checks remain, with the old reserved-state-count assertion updated to preserve its named states and the old movement assertion updated to expect WALK without Shift. Added 190 checks cover library bindings/loops/root motion, one skeleton/body, cached tree references, live WASD/run/strafe/backward/jump, grounded/no-double-jump behavior, timed Talk, previews, original source frame rates, and optional NPC hooks.

Compatibility render captures on the GTX 1050 Ti inspect Idle, Walk, Run, both lateral gaits, backward movement, Jump, Talk, Sit, the regular exploration camera, and F3. Paired locomotion frames confirm poses change. Materials/scale remain intact; no duplicate body or rig explosion. Grounded idle/talk/walk stance toe heights are approximately 0.005–0.013 model meters; sprint swing feet lift as expected. Cadence uses source stride speed to reduce sliding; no foot IK is added. Regular running camera capture: 83 draw calls; F3: 96. Sparse town lights remain shadow-free. Captures and logs are in user data / the Windows temp directory, outside Git.

All runtime validation uses `--echo-validation`, with isolated fresh worlds and no production save writes. Tests continue to cover prior save migration, relationships, memories, reputation, offline Echo events, UI, NPC LOD, collision, and camera wall retraction.

Rebake after changing source clips using the Godot console `--headless --path "F:\echo me" --script res://tools/inspect_animations.gd`, then `--script res://tools/bake_player_animations.gd`. The optional rejected duplicate pose is absent on a fresh clone; the inspector then reports the 14 usable sources.
