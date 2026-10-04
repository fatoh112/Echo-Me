# Echo Me architecture rules

- Official visual direction: stylized semi-realistic low-fantasy old town at sunset; merchant, tavern, houses, square, alley, town watch. No modern urban props.
- Player CharacterBody3D remains authoritative. Configurable walk/run, grounded jump, and smooth camera-relative facing live in PlayerController. Imported character models belong under Body/VisualRoot. Animation and camera presentation never own movement or collision.
- Use one player skeleton/mesh and the offline-baked player_locomotion.res AnimationLibrary. FBX inspection/baking lives in tools/, never gameplay. Remove locomotion root translation; jump height comes from physics. Cache animation references, use short transitions, and evaluate the player once per physics tick. Preview-only turns/start-walk must not delay input. TALK is timed, SIT is a preview capability until seating is implemented.
- NPCVisual exposes optional humanoid/animation hooks; NPCController remains independent of bones and models. Only ACTIVE future NPC models may evaluate animation. Animation FBXs discard embedded textures.
- Preserve NPC IDs, relationships, and memories when retheming. Canonical town locations must accept legacy save aliases. Town layout is fixed authored placement of supplied Slavic Town GLBs and reusable scene wrappers, batched by shared imported mesh. No runtime file discovery or procedural generation.
- Preserve source UVs/vertex colors. Share the pack's original colorsheet material and ground texture; use WorldVisualConfig for NPCs, small signs and emissive lanterns. No extra shadows/GI or expensive effects. Keep missing animation states inactive until real clips exist.

- Godot 4.7.2 Standard, GDScript only, Compatibility renderer, Windows first.
- "AI should provide the illusion of intelligence. The game engine should do the actual thinking."
- Decisions use discrete Utility AI, structured memory, relationships, personality, needs, schedules, world state, and event history. NPCs perceive PLAYER actions; actual PLAYER/ECHO source is internal debug data.
- Player traits are floats in 0.0–1.0, initially 0.5, learned with small exponential influences. Echo is the inverse plus at most 0.035 deterministic distortion from a saved seed.
- Use one reusable NPCData/NPCController implementation. Keep action and dialogue definitions centralized under data/.
- main.gd orchestrates. Keep decision, relationship, memory, reputation, persistence, neighborhood, and UI responsibilities in their own small systems.
- Persist versioned JSON in user://; tolerate Day 1 fields, preserve a backup before migration, and use atomic writes. Never commit runtime saves.
- Target i7-2600 / GTX 1050 Ti / 16 GB and weaker hardware. Shared imported meshes/materials, normal Godot import LODs, simple box/cylinder collision, no real-time shadows or GI. No blanket triangle collision or individually processed decorative scripts. Slow logical ticks; no continuous NPC movement/AI. Nearby ACTIVE, distant BACKGROUND, irrelevant LOGICAL.
- Do not add C#, a local/cloud LLM, ML runtime, PyTorch, TensorFlow, Ollama, CUDA dependency, backend, Render, ElevenLabs, voice, heavy SDK, multiplayer, combat, inventory, quests, procedural generation, parkour, stamina, Steam, settings, save slots, or achievements.
- Validate using the portable Godot console executable under F:/mehmed fethelier sultani/. Keep automated tests isolated from the player's production save.
- Before major gameplay refactors preserve the working commit. Commit and push only after parser, headless startup, and meaningful simulation tests pass.
