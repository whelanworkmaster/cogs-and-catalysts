# Current Progress - Cogs & Catalyst

## Overall Plan (High Level)
1) Foundation (Godot 4.x)
   - Core scenes: Main, Player, World, Combat HUD.
   - Movement + elevation handling (real 3D with CSG primitives).
   - Data-driven setup (Resources for stats, abilities, mutations).

2) LUMEN Combat Loop
   - Deterministic hits (no to-hit roll).
   - AP economy + Body Strain as a persistent cost.
   - Drops: Mutagenic Cells fuel abilities.

3) FitD Meta Systems
   - Visual Clocks (Detection, Toxicity, Vault, Reinforcement).
   - Faction tiers + district/shop unlocks.
   - Position & Effect framing for risky interactions.

4) Internal Rig (Biological Architecture)
   - Organ slot loadout at heist start.
   - Mutagens as "classes" granting moves.

5) MVP Slice: "Mercury Vault"
   - Safehouse -> Heist loop.
   - One tactical floor with a hazard interaction.
   - Extraction race vs. clocks.

## Where We Are Now
- **Full 3D migration complete.** The project has been ported from 2D (fake 2.5D elevation) to real 3D using CSG primitives and an orthographic orbit camera.
- Project structure: `scenes/`, `scripts/`, `scripts/world`, `scripts/systems`, `scripts/ai`, `scripts/ui`, `scripts/actors`.
- GameMode singleton with exploration vs. turn-based states.
- CombatManager singleton with turn order and start/end combat.
- Combat auto-starts on scene load.

### Camera
- Orthographic Camera3D with fixed-pitch (45-degree) orbit (BG3/XCOM style).
- Middle mouse drag = yaw rotation, scroll wheel = zoom.
- Camera follows player with smoothing.
- Camera distance scales with zoom to prevent view clipping.

### Player
- CharacterBody3D with CSGBox3D visual (blue, 32x32x32).
- **Click-to-move** (XCOM/BG3 style): left-click a grid cell to pathfind and walk there via A*.
  - Exploration: click-to-move with no AP cost, no path length limit.
  - Combat: each cell costs AP; path is truncated to affordable length.
  - Click on an enemy in combat to attack (if within attack range).
  - Path preview line shown on hover (green line on grid overlay).
  - Movement is animated cell-by-cell via tween.
- AP resets at the start of the player's turn.
- Stances (Neutral/Guard/Aggress/Evade), Disengage toggle, reaction attacks on leaving threat range.
- Attack: F key for nearest target, or click enemy directly.
- Hit feedback (flash + squash/stretch) and floating damage numbers via `camera.unproject_position()`.
- Death animation and Game Over overlay with retry.
- Mutagenic cell pickup.

### Enemy
- CharacterBody3D with CSGBox3D visual (red, 28x28x28).
- AI state scaffold (idle -> seek) with AP-based movement.
- A* grid pathfinding around buildings (AStarGrid2D internally, Vector3 wrappers externally). Enemy movement uses direct grid-cell positioning (no physics collision).
- Ranged attacks use geometric line-of-sight checks against building footprints. Enemies will not fire if a building blocks the shot.
- Ranged shot visual: ImmediateMesh line with fade-out tween.
- Death drops mutagenic cell.
- Threat ring visual (ImmediateMesh circle on ground).

### World / Procgen
- Node3D scene root with AStarGrid2D pathfinding on the XZ plane.
- `snap_to_grid()` and `get_astar_path_3d()` accept both Vector2 and Vector3.
- Randomized building layout (4-6 buildings, CSGBox3D with StaticBody3D blockers).
- Randomized enemy count/placement and player start with spacing checks.
- Randomized steam vent placement (2-3 vents) with spacing vs. buildings/enemies/player.
- Grid overlay: ImmediateMesh line grid on XZ plane, skips building footprints.
- Ground plane: CSGBox3D (4000x1x4000).

### Elevation
- Buildings are real 3D CSGBox3D volumes with StaticBody3D collision.
- Area3D detection zones on top surface trigger elevation changes.
- Actors set `global_position.y = elevation_height` when entering/exiting zones.
- Elevation zones added to `nav_obstacle` group for pathfinding exclusion.

### Hazards
- Steam vent: Area3D with CSGBox3D visual, ticks Toxicity on contact.
- Mutagenic cell: Node3D with emissive CSGBox3D, Area3D + SphereShape3D pickup.

### Combat Visuals
- Stance ring (color-coded by stance) and dashed disengage ring: MeshInstance3D + ImmediateMesh.
- Enemy threat range ring: MeshInstance3D + ImmediateMesh.
- Damage popups: screen-space via `camera.unproject_position()`.

### FitD Clocks
- Detection/Toxicity clocks displayed in HUD.
- Detection ticks on combat start + player moves + player attacks.
- Toxicity ticks when player takes damage and on steam vent contact.

### Lighting
- DirectionalLight3D with shadows.
- WorldEnvironment with dark background and ambient light.

## Current Files / Systems
- `scripts/camera/camera_rig.gd`
- `scripts/systems/game_mode_controller.gd`
- `scripts/systems/combat_manager.gd`
- `scripts/systems/clock.gd`
- `scripts/world/main.gd`
- `scripts/world/elevation_area.gd`
- `scripts/world/steam_vent.gd`
- `scripts/world/mutagenic_cell.gd`
- `scripts/world/grid_overlay.gd`
- `scripts/player.gd`
- `scripts/actors/enemy.gd`
- `scripts/ai/ai_state.gd`
- `scripts/ai/enemy_ai.gd`
- `scripts/ai/states/idle_state.gd`
- `scripts/ai/states/seek_state.gd`
- `scripts/ui/combat_hud.gd`
- `scripts/ui/combat_overlay.gd`
- `scripts/ui/enemy_threat_visual.gd`
- `scripts/ui/damage_popup.gd`
- `scripts/ui/game_over.gd`
- `scenes/main.tscn`, `scenes/player.tscn`, `scenes/enemy.tscn`, `scenes/ui/combat_hud.tscn`, `scenes/ui/game_over.tscn`

## Next Steps (Suggested Order)
1) Level challenge and encounter design (MVP)
   - Tune procgen (building/vent counts, spacing, seeds) for reliable layout variety.
   - Consider a second enemy type (melee or support) to diversify positioning.
   - Place cover or blockers that shape movement and create threat zones.

2) FitD clocks (polish)
   - Replace labels with segmented UI bars (4/6/8).
   - Define clear "full clock" consequences (alarm/reinforcements).

3) Internal Rig loadout
   - Organ slot loadout selection at heist start.
   - One mutagen (Hydraulic Leg or Tendrils) with 1-2 moves.

4) Position & Effect framing
   - Simple pre-interaction UI (Controlled/Risky/Desperate).
   - Hook outcomes to clock ticks or glitches.

5) Factions + tiers
   - Dictionary for faction tiers (-3 to +3).
   - Tie tier to shop inventory or district layout toggle.

6) MVP "Mercury Vault" slice
   - One tactical floor with a steam vent hazard.
   - Vault + Reinforcement clocks driving extraction.

## Notes
- All distance constants are in pixel scale (32, 40, 240, 750). Works but the world is very large. Scale normalization is a future pass.
- Movement is click-to-move (left-click on grid). WASD/arrow keys no longer used for movement.
- The player is in the `player` group for AI targeting.
- Procgen runs after scene load (deferred) to ensure obstacle groups are populated.
