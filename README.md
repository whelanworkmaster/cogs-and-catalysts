# Cogs & Catalyst

Tactical roguelike prototype built in Godot 4.x.

## Current State
- 3D grid-based, turn-based tactical combat.
- Squad play baseline (2+ Vessels).
- AP-based movement and attacks.
- Pressure tracks (Alert and Toxicity) with gameplay consequences.
- Cover and LOS foundation (partial cover, blocked shots, cover hit feedback).
- Procedural encounter generation with validation/retry for playable layouts.

## Requirements
- Godot 4.6 (or compatible 4.x build used by this project).

## Run
1. Open the project in Godot.
2. Run `scenes/main.tscn`.

Headless validation helper:
- `powershell -ExecutionPolicy Bypass -File tools\debug_headless.ps1`

## Controls
- `LMB`: Move / attack target under cursor (contextual).
- `F`: Melee attack.
- `R`: Ranged attack.
- `Q`: Cycle stance.
- `E`: Disengage.
- `Space`: End turn confirm (press twice).
- `Tab` (fallback `C`): Switch active Vessel.
- `W/A/S/D`: Camera pan.
- `MMB drag`: Camera orbit.
- `Mouse wheel`: Camera zoom.

## Key Project Paths
- `docs/designbible.md`: Product direction and design constraints.
- `docs/currentprogress.md`: Latest implementation status.
- `docs/implementation_backlog.md`: Ordered backlog and milestones.
- `scripts/world/main.gd`: Procgen, navigation, LOS, shot resolution.
- `scripts/ai/states/seek_state.gd`: Enemy tactical behavior.
- `scripts/ui/combat_hud.gd`: Combat HUD and squad UI behavior.

## Notes
- This is an active prototype; systems and balance are still evolving.
