# Implementation Backlog - Cogs & Catalyst

Last updated: 2026-02-06
Source alignment:
- `docs/designbible.md`
- `docs/currentprogress.md`

## Planning Constraints
- Keep tactical combat as the primary loop.
- Do not import tabletop rulesets or terminology.
- Build toward squad-based roguelike runs, not single-character CRPG flow.

## Milestones
1. M1 - Mission Run Skeleton
2. M2 - Squad Control + Multi-Unit Combat UX
3. M3 - Encounter Depth (Enemy Roles + Hazard Combos)
4. M4 - Run Progression + Unlocks
5. M5 - Mercury Vault Vertical Slice

## P0 Backlog (Build First)
### B001 - Run State Controller
- Priority: P0
- Milestone: M1
- Outcome: Mission flow supports `deploy -> encounter -> extraction -> results`.
- Implementation:
- Add `scripts/systems/run_controller.gd`.
- Integrate with `scripts/systems/game_mode_controller.gd`.
- Add state entry/exit hooks for pressure systems, spawn waves, and results payload.
- Target files:
- `scripts/systems/game_mode_controller.gd`
- `scripts/systems/combat_manager.gd`
- `scripts/world/main.gd`
- `scenes/main.tscn`
- Acceptance criteria:
- New run starts in deploy state.
- Encounter completion transitions to extraction state.
- Extraction or squad wipe transitions to results state.

### B002 - Pressure System Consequence Wiring
- Priority: P0
- Milestone: M1
- Outcome: Pressure tracks/timers have concrete gameplay effects at thresholds.
- Implementation:
- Extend pressure system callbacks for threshold events and timer expiry.
- Alert Level triggers reinforcement wave(s).
- Toxicity Load applies escalating penalties.
- Add Objective Breach Timer and Enemy Response Timer for run pacing.
- Target files:
- `scripts/systems/pressure_system.gd`
- `scripts/ui/combat_hud.gd`
- `scripts/world/main.gd`
- Acceptance criteria:
- At least two pressure systems trigger visible battlefield/state changes.
- HUD shows pressure values/timers and pending threshold effects.

### B003 - Squad Entity Foundation (2-4 Vessels)
- Priority: P0
- Milestone: M2
- Outcome: Player controls multiple units in one mission.
- Implementation:
- Create squad manager with active unit selection.
- Convert single `player` assumptions to squad-aware targeting.
- Maintain per-unit AP and turn state.
- Target files:
- `scripts/player.gd`
- `scripts/systems/combat_manager.gd`
- `scripts/actors/enemy.gd`
- `scripts/ai/enemy_ai.gd`
- New file: `scripts/systems/squad_manager.gd`
- Acceptance criteria:
- Player can field at least 2 Vessels.
- Turn order includes all friendly units and enemies.
- Enemy AI can select valid squad targets.

### B004 - Multi-Unit Combat UI
- Priority: P0
- Milestone: M2
- Outcome: UI clearly supports active unit context.
- Implementation:
- Add squad panel for unit selection and AP snapshot.
- Show active unit marker and AP/action context in HUD.
- Preserve existing threat and damage indicators.
- Target files:
- `scripts/ui/combat_hud.gd`
- `scripts/ui/combat_overlay.gd`
- `scenes/ui/combat_hud.tscn`
- Acceptance criteria:
- Player can switch active units via UI.
- AP and action feedback update correctly per selected unit.

## P1 Backlog (Depth and Differentiation)
### B005 - Enemy Role Expansion
- Priority: P1
- Milestone: M3
- Outcome: Combat decisions vary by enemy battlefield function.
- Implementation:
- Add at least two roles beyond current baseline (example: anchor, disruptor).
- Give each role one unique tactical behavior.
- Expand AI state transitions for role priorities.
- Target files:
- `scripts/actors/enemy.gd`
- `scripts/ai/enemy_ai.gd`
- `scripts/ai/states/idle_state.gd`
- `scripts/ai/states/seek_state.gd`
- Acceptance criteria:
- Role behavior is visibly distinct in combat.
- Mixed-role encounters create different positioning pressure.

### B006 - Hazard Combo System
- Priority: P1
- Milestone: M3
- Outcome: Hazards are tactical tools, not only passive damage zones.
- Implementation:
- Add one combinable hazard interaction chain (example: steam + conductive zone).
- Telegraph hazard trigger ranges and outcomes in UI.
- Ensure AI pathing and targeting account for hazard risk.
- Target files:
- `scripts/world/steam_vent.gd`
- `scripts/world/main.gd`
- `scripts/world/grid_overlay.gd`
- `scripts/ui/combat_overlay.gd`
- Acceptance criteria:
- At least one reliable hazard combo is player-executable.
- Hazard combo changes expected best move in live encounters.

### B007 - Encounter Template System
- Priority: P1
- Milestone: M3
- Outcome: Encounters are authored templates plus variation, not pure random scatter.
- Implementation:
- Add encounter template data definitions (enemy composition, hazard set, objective hook).
- Keep procedural variation within template constraints.
- Add weighted selection by run stage.
- Target files:
- `scripts/world/main.gd`
- New folder: `scripts/data/`
- New data assets under `res://data/encounters/`
- Acceptance criteria:
- Encounter generation produces consistent tactical intent per stage.
- Run pacing feels distinct across early/mid/late nodes.

## P2 Backlog (Progression and Slice Completion)
### B008 - Post-Run Unlock Flow
- Priority: P2
- Milestone: M4
- Outcome: Runs feed persistent progression choices.
- Implementation:
- Add results screen with unlock picks.
- Save unlocked modules/squad options between runs.
- Gate future run options based on unlock set.
- Target files:
- New file: `scripts/systems/progression_manager.gd`
- `scripts/ui/game_over.gd`
- New scene: `scenes/ui/run_results.tscn`
- Acceptance criteria:
- End of run offers at least one meaningful unlock choice.
- Unlocks persist after restart.

### B009 - Mercury Vault Vertical Slice Integration
- Priority: P2
- Milestone: M5
- Outcome: One complete, replayable run demonstrates target direction.
- Implementation:
- Configure 2-3 encounter chain with objective pivot.
- Wire reinforcement pressure and extraction race.
- Validate loop from deploy through post-run results.
- Target files:
- `scripts/world/main.gd`
- `scripts/systems/run_controller.gd`
- `scripts/ui/combat_hud.gd`
- Acceptance criteria:
- Full run can be played start-to-finish without manual debug steps.
- Tactical decisions are driven by AP, pressure systems, hazards, and squad positioning.

## Suggested Execution Order (First 3 Work Blocks)
1. Build B001 + B002 together to establish mission flow and consequence pressure.
2. Build B003 + B004 together to unlock squad-first gameplay.
3. Build B005 + B006 to create encounter depth before progression work.

## Definition of Done (Project Direction Check)
- Mission loop is run-based and extraction-focused.
- Combat is squad tactical, deterministic, and readable.
- System language and mechanics remain bespoke (non-tabletop).
- Mercury Vault slice validates the direction with repeatable runs.
