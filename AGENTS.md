# Echo Me architecture rules

- Use Godot 4.7.x with GDScript and the Compatibility renderer. Do not add C#.
- Keep gameplay decisions deterministic and engine-owned. Use structured data and utility-style scores; do not add machine learning or a local LLM.
- Keep the Day 1 prototype local and offline. Do not add a backend, external SDKs, multiplayer, combat, inventory, or quests.
- Keep behavior traits as floats clamped to the inclusive range 0.0–1.0. Initialize player traits to 0.5 and derive Echo traits as `1.0 - player_trait`.
- Represent actions, behavior profiles, relationships, memories, saves, and offline simulation as modular systems under `scripts/`.
- Persist only local game data under Godot's `user://` path. Never commit runtime saves.
- Keep the prototype lightweight for older and weaker Windows hardware: simple meshes, minimal lights, no real-time shadows, and no unnecessary per-frame allocations.
