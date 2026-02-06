# Current Progress - Cogs & Catalyst

## Alignment Update (2026-02-06)
This document has been updated to match the new direction in `docs/designbible.md`.

Strategic change:
- Removed CRPG-first framing.
- Removed dependency on tabletop-derived rule sets.
- Prioritized a unique tactical roguelike structure centered on combat encounters.

## Current Build Status
### Core Tactical Foundation (Working)
- Full 3D tactical map migration is complete.
- Orthographic orbit camera is in place (XCOM-style readability).
- Turn-based combat loop exists with AP spending and turn order.
- Click-to-move grid pathing via A* is working.
- Enemy turn behavior and basic ranged logic are functional.
- Threat, damage feedback, and combat overlays are implemented.

### Encounter Systems (Working / Partial)
- Procedural combat space with buildings and blockers.
- Hazard actors (steam vents) and resource pickups (mutagenic cells).
- Pressure HUD scaffolding exists (Alert Level/Toxicity Load).
- Reinforcement and mission-failure consequences are not fully defined yet.

### Architecture
- State split between exploration/combat already exists, but this should evolve into mission-run flow states.
- Data-driven system approach is partially present and should be expanded for squad, abilities, and encounter templates.

## What This Means for Scope
The existing codebase is a strong tactical prototype. The main gap is product structure:
- Current implementation still behaves like a single-character tactical RPG sandbox.
- Target implementation is a squad-based tactical roguelike run loop.

No major rewrite is required for fundamentals; the next phase is system layering and content architecture.

## Updated Goals
### Goal 1 - Lock Identity
- Keep deterministic tactical combat as the primary gameplay loop.
- Avoid importing external tabletop mechanics/rule language.
- Use only bespoke, digital-first combat and progression systems.

### Goal 2 - Shift to Run Structure
- Replace open-ended exploration framing with operation-based flow.
- Build run sequence: deploy -> encounter chain -> extraction -> post-run unlocks.
- Ensure mission pressure tracks/timers create escalating pressure and decisive end states.

### Goal 3 - Shift to Squad Tactics
- Expand from one controllable unit to 2-4 Vessels.
- Add role differentiation through modules/loadouts, not fixed classes.
- Tune UI for multi-unit AP, threat, and action previews.

### Goal 4 - Encounter Depth
- Add enemy role diversity (anchor, disruptor, pressure, support).
- Expand hazard interactions into reliable tactical tools.
- Formalize reinforcement and alarm breakpoints tied to pressure thresholds.

## Recommended Development Order (Revised)
1) Mission Loop Skeleton
- Add run state controller (deploy, encounter, extraction, results).
- Wire pressure tracks/timers to concrete mission consequences.

2) Squad Control Layer
- Implement unit selection/switching and per-unit AP display.
- Support shared mission objectives across all deployed Vessels.

3) Encounter Role Expansion
- Add at least one new enemy battlefield role.
- Add one hazard combo mechanic that changes positioning choices.

4) Progression Pass
- Introduce post-run unlock selection (modules, squad options, map modifiers).
- Track unlock persistence across runs.

5) Mercury Vault Vertical Slice (Reframed)
- Deliver one complete run with 2-3 tactical encounters and extraction pressure.

## Existing Systems and Files (Still Relevant)
- `scripts/camera/camera_rig.gd`
- `scripts/systems/game_mode_controller.gd`
- `scripts/systems/combat_manager.gd`
- `scripts/systems/pressure_system.gd`
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
- `scenes/main.tscn`
- `scenes/player.tscn`
- `scenes/enemy.tscn`
- `scenes/ui/combat_hud.tscn`
- `scenes/ui/game_over.tscn`

## Notes
- World scale constants are still oversized and should be normalized in a dedicated tuning pass.
- Current prototype favors single-unit control; squad support is now a priority, not an optional extension.
