# Echo Me — Day 2 implementation report

## Playable slice

Six reusable NPCs (Alex, Sarah, Mike, Emma, David, Noah) inhabit seven labeled greybox areas. WASD and mouse look remain available. E opens the nearby NPC's ten-action menu; serious unresolved negative memories instead open Deny / Apologize / Threaten / Dismiss. Actions close the menu and update behavior evidence, that NPC's relationship and memory, mood, collision state, and global reputation.

Controls: WASD move; mouse look; E interact; arrow keys/Tab and Enter or mouse select; Esc closes a modal or toggles cursor capture; F3 toggles the scrollable debug panel; F10 saves and quits. Window close also saves. To use the debug NPC picker, release the cursor with Esc.

The existing project.godot configuration and player scene are preserved. The old Alex scene path remains valid through a thin controller compatibility wrapper.

## Architecture

- Main is orchestration only: load, build, wire signals, tick schedules/proximity, run offline simulation, and save on quit.
- JSON files centralize action effects, NPC identities/personality/schedules, geography/opportunity, and reaction templates.
- WorldAction v2 records event identity, perceived PLAYER identity, internal PLAYER/ECHO source, target/location, behavior/relationship/memory effects, severity, and metadata.
- ActionSystem applies one shared consequence pipeline for player actions, Echo events, and accusation responses. Echo actions affect NPCs and reputation but do not train the actual player's profile.
- PlayerBehaviorProfile learns seven normalized traits through small exponential influences. EchoBehaviorProfile uses the inverse with deterministic saved-seed distortion bounded to 0.035 per trait.
- NPCData owns independent personality, relationship, needs, location/activity/mood, and memories. NPCController supplies one capsule representation for all six NPCs.
- RelationshipSystem scales centralized consequences by personality; Noah weighs theft, hostility, repetition, and local danger more heavily.
- MemorySystem preserves positive and negative history, weighs importance and recency, calculates NONE/MILD/STRONG collision, and derives mood. NPC reasoning uses perceived identity and never reads actual_source.
- DialogueResolver chooses small data-driven templates. Responses become WorldActions; truthful denial of an Echo event and false denial of a player event provide different honesty evidence internally.
- UtilityAI scores all ten actions for all six targets using inverse traits, relationships, target personality, location/opportunity, needs, memory context, repetition, risk, reputation, and tiny seeded variation. Debug traces retain scores and factors.
- WorldState owns logical time, NPCs, reputation, player/Echo locations, event history, saved seed/turn count, offline events, and decision traces.
- NPCManager uses ACTIVE within 12 m, BACKGROUND within 28 m, and LOGICAL farther away. Active representations update on the one-second logical tick, background representations every fifth tick, and logical representations hide geometry/collision. NPCs have no frame-by-frame movement or decision processing.
- The neighborhood uses primitive meshes, shared simple materials, static collision, and lighting without shadows or GI.
- OfflineEchoSimulator executes bounded discrete turns and checkpoints consumed results immediately on launch. The player summary describes consequences; its development toggle and F3 reveal exact internal events.

## Offline buckets

| Real time away | Echo turns |
| --- | ---: |
| Less than 60 seconds | 0 |
| 60 seconds to less than 5 minutes | 1 |
| 5 to less than 15 minutes | 2 |
| 15 minutes to less than 1 hour | 3 |
| 1 to less than 2 hours | 4 |
| 2 to less than 3 hours | 5 |
| 3 to less than 4 hours | 6 |
| 4 hours or more | 8 |

Each turn advances logical time by 30 minutes and checks schedules. Canonical event times and seeded variations make results deterministic for the same saved state, logout timestamp, and elapsed bucket.

## Local persistence

The production path remains user://echo_me_save.json (normally %APPDATA%/Godot/app_userdata/Echo Me/echo_me_save.json on Windows).

Save version 2 includes logout timestamp, player traits, Echo profile/seed, all NPC state/relationships/memories/moods/locations/needs, reputation, world state, bounded event history, offline events, and utility traces.

Day 1 migration preserves player traits, Alex's relationship, memory descriptions/identities/sources, and supplies new defaults. The original text is preserved as echo_me_save.json.v1.backup.json before replacement. Invalid JSON is backed up as .corrupt.backup.json. An unreadable or unsupported future save blocks writes. Atomic temporary-file replacement preserves the previous save as .previous.json.

Automated checks and render previews use --echo-validation, isolated scratch saves, and a fresh world. They never load or overwrite the production save.

## Validation performed

Portable executable:
F:/mehmed fethelier sultani/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe

Engine: 4.7.2.stable.official.ed1daf0bf.

- Editor import / global class registration: exit 0, no blocking parser, type, scene, or resource errors.
- Headless main-scene startup for 120 frames: exit 0, clean output.
- Automated suite: 208 checks, 0 failures, exit 0.
- A: repeated Help raises empathy and Sarah trust; other NPC history stays independent.
- B: high-empathy player yields low-empathy Echo and a hostile/selfish top utility choice in the tested context.
- C: Echo betrayal is remembered as PLAYER with actual ECHO retained internally; actual player traits stay unchanged.
- D: all eight positive Sarah memories survive betrayal; collision becomes STRONG and mood CONFUSED.
- E: full JSON round trip, timestamp, atomic replacement, previous-save backup, exact Day 1 backup/migration, and missing-field defaults pass.
- F: offline thresholds/hard cap, exact same-bucket determinism, multi-target/action variety, repetition protection, reputation updates, full utility traces, and offline save round trip pass.
- Additional checks: all ten actions change behavior/relationship/memory; trait bounds; source-blind NPC reasoning; evening schedules; LOD; live six-NPC scene; CharacterBody movement/ground collision; building collision; nearby targeting; E and Enter input; four-response accusation/apology flow; modal movement lock/restore; mysterious summary; internal event debug; F3; logical geometry/collision removal.
- Final capped sample: eight events, four NPC targets, four action types, 18.88 ms. This measures one simulation sample, not sustained gameplay FPS.
- Actual Compatibility rendering: NVIDIA GeForce GTX 1050 Ti, OpenGL 3.3, exit 0 and empty stderr. Neighborhood, interaction, collision/debug, and offline-summary captures were inspected.

Repeat validation in PowerShell:

~~~powershell
$echoGodot = 'F:\mehmed fethelier sultani\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $echoGodot --headless --editor --path 'F:\echo me' --import
& $echoGodot --headless --path 'F:\echo me' --quit-after 120 -- --echo-validation
& $echoGodot --headless --path 'F:\echo me' --script res://tests/run_tests.gd -- --echo-validation
~~~

The optional tests/render_preview.gd runs with the Compatibility renderer and --echo-validation; its screenshots are written to user://echo_me_previews/.

## One manual test sequence (about five minutes)

1. F5; walk around the seven labeled areas and approach all six names using WASD/mouse. Open E on different NPCs and try actions. F3 shows independent relationships, memories, profile, and reputation.
2. Help Sarah eight times, then Betray once. In F3 select Sarah: positive memories should remain, collision should be STRONG, mood CONFUSED. Open E again and Apologize; a new response memory and profile evidence should appear.
3. F10 to save and quit; wait 65 seconds; F5 again. Check the consequence summary, then its exact-event toggle and F3 for actual ECHO / perceived PLAYER. Visit an affected NPC, answer any accusation, and confirm previous traits/history persisted. A short absence produces one event; the automated suite covers larger batches.

## Exact file inventory

Paths are relative to the repository root.

### Created: 43 files

Data:

- data/actions/actions.json
- data/dialogue/reactions.json
- data/neighborhood.json
- data/npcs/neighbors.json

Scenes:

- scenes/npc/npc.tscn
- scenes/ui/debug_ui.tscn
- scenes/ui/interaction_ui.tscn
- scenes/world/neighborhood.tscn

Scripts, tests, and report:

- scripts/actors/npc_controller.gd
- scripts/ai/utility_ai.gd
- scripts/data/action_catalog.gd
- scripts/data/data_utils.gd
- scripts/data/npc_data.gd
- scripts/data/world_state.gd
- scripts/systems/action_system.gd
- scripts/systems/dialogue_resolver.gd
- scripts/systems/memory_system.gd
- scripts/systems/npc_manager.gd
- scripts/systems/relationship_system.gd
- scripts/systems/reputation_system.gd
- scripts/ui/debug_ui.gd
- scripts/ui/interaction_ui.gd
- scripts/world/neighborhood.gd
- tests/render_preview.gd
- tests/run_tests.gd
- docs/DAY2.md

Godot-generated tracked UID sidecars:

- scripts/actors/npc_controller.gd.uid
- scripts/ai/utility_ai.gd.uid
- scripts/data/action_catalog.gd.uid
- scripts/data/data_utils.gd.uid
- scripts/data/npc_data.gd.uid
- scripts/data/world_state.gd.uid
- scripts/systems/action_system.gd.uid
- scripts/systems/dialogue_resolver.gd.uid
- scripts/systems/memory_system.gd.uid
- scripts/systems/npc_manager.gd.uid
- scripts/systems/relationship_system.gd.uid
- scripts/systems/reputation_system.gd.uid
- scripts/ui/debug_ui.gd.uid
- scripts/ui/interaction_ui.gd.uid
- scripts/world/neighborhood.gd.uid
- tests/render_preview.gd.uid
- tests/run_tests.gd.uid

### Changed: 12 files

- AGENTS.md — expanded architecture and performance rules.
- scenes/main.tscn — reusable world/NPC/UI composition.
- scripts/actors/alex_controller.gd — compatibility wrapper for shared NPCController.
- scripts/actors/player_controller.gd — modal control lock.
- scripts/data/echo_behavior_profile.gd — seeded bounded inverse distortion.
- scripts/data/npc_memory.gd — structured memory v2 and legacy handling.
- scripts/data/npc_relationship.gd — normalized consequences and applied deltas.
- scripts/data/player_behavior_profile.gd — sociability and gradual learning.
- scripts/data/world_action.gd — generalized structured events.
- scripts/main.gd — small orchestration layer.
- scripts/systems/offline_echo_simulator.gd — deterministic capped multi-NPC simulation.
- scripts/systems/save_manager.gd — version 2 persistence/migration/backups.

Phase 0 separately updated .gitignore and preserved the original playable Day 1 files in commit 6370326 (Day 1: working Echo core loop), pushed to origin/main before refactoring.
