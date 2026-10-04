# Echo Me architecture rules

- Official visual direction: stylized semi-realistic low-fantasy old town at sunset; merchant, tavern, houses, square, alley, town watch. No modern urban props.
- Player physics/controller remain authoritative and unchanged. Imported character models belong under Body/VisualRoot. Animation and camera presentation never own movement or collision.
- Preserve NPC IDs, relationships, and memories when retheming. Canonical town locations must accept legacy save aliases. World geometry is fixed authored procedural blockout, batched where practical.
- Centralize environment/NPC materials in WorldVisualConfig; no extra shadows/GI or expensive effects. Keep missing animation states inactive until real clips exist.

- Godot 4.7.2 Standard, GDScript only, Compatibility renderer, Windows first.
- "AI should provide the illusion of intelligence. The game engine should do the actual thinking."
- Decisions use discrete Utility AI, structured memory, relationships, personality, needs, schedules, world state, and event history. NPCs perceive PLAYER actions; actual PLAYER/ECHO source is internal debug data.
- Player traits are floats in 0.0–1.0, initially 0.5, learned with small exponential influences. Echo is the inverse plus at most 0.035 deterministic distortion from a saved seed.
- Use one reusable NPCData/NPCController implementation. Keep action and dialogue definitions centralized under data/.
- main.gd orchestrates. Keep decision, relationship, memory, reputation, persistence, neighborhood, and UI responsibilities in their own small systems.
- Persist versioned JSON in user://; tolerate Day 1 fields, preserve a backup before migration, and use atomic writes. Never commit runtime saves.
- Target i7-2600 / GTX 1050 Ti / 16 GB and weaker hardware. Primitive geometry, shared simple materials, no real-time shadows or GI. Slow logical ticks; no continuous NPC movement/AI. Nearby ACTIVE, distant BACKGROUND, irrelevant LOGICAL.
- Do not add C#, a local/cloud LLM, ML runtime, PyTorch, TensorFlow, Ollama, CUDA dependency, backend, Render, ElevenLabs, voice, heavy SDK, multiplayer, combat, inventory, quests, procedural generation, advanced art/animation, Steam, settings, save slots, or achievements.
- Validate using the portable Godot console executable under F:/mehmed fethelier sultani/. Keep automated tests isolated from the player's production save.
- Before major gameplay refactors preserve the working commit. Commit and push only after parser, headless startup, and meaningful simulation tests pass.
