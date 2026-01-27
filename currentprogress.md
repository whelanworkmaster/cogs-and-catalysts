# Current Progress - Cogs & Catalyst

## Overall Plan (High Level)
1) Foundation
   - Core scenes: Main, Player, World.
   - Movement + elevation handling (isometric + fake Z).
   - Data-driven setup (Resources for stats, abilities, mutations).

2) Combat Loop
   - Exploration to combat transition (engagement trigger).
   - Turn-based combat manager (turn order, AP spend).
   - Simple AI roles and environment interactions.

3) Progression
   - Organ slots + mutation inventory.
   - Toxicity / strain management and debuffs.

4) MVP Slice: "Mercury Vault"
   - One vertical city block.
   - Combat transition + one boss encounter.
   - Basic mutation slot and UI.

## Where We Are Now
- Project structure refactored (`scenes/`, `scripts/`, `scripts/world`, `scripts/systems`, `scripts/ai`, `scripts/ui`, `scripts/actors`).
- GameMode singleton with exploration vs. turn-based states.
- CombatManager singleton with turn order and start/end combat.
- Engagement trigger that starts combat and includes enemy actors.
- Player movement:
  - Exploration: free movement, no AP cost.
  - Combat: AP-spending step movement with cooldown.
  - AP resets at the start of the player's turn.
- Enemy actor:
  - Basic AI state scaffold (idle -> seek).
  - Simple seek step toward player, then end turn.
- Debug Combat HUD showing mode, current turn actor, and AP.

## Current Files / Systems
- `scripts/systems/game_mode_controller.gd`
- `scripts/systems/combat_manager.gd`
- `scripts/world/engagement_trigger.gd`
- `scripts/actors/enemy.gd`
- `scripts/ai/ai_state.gd`
- `scripts/ai/enemy_ai.gd`
- `scripts/ai/states/idle_state.gd`
- `scripts/ai/states/seek_state.gd`
- `scripts/ui/combat_hud.gd`
- `scenes/main.tscn`, `scenes/player.tscn`, `scenes/enemy.tscn`, `scenes/engagement_trigger.tscn`, `scenes/ui/combat_hud.tscn`

## Next Steps (Suggested Order)
1) Combat input polish
   - Add explicit grid or tile-based movement for combat.
   - Prevent sliding in combat; snap to grid per AP spend.

2) Enemy AI expansion
   - Add `Attack` state with simple range check.
   - Add `Reposition` state for flanking or hazard avoidance.

3) AP + Actions
   - Centralize AP costs for movement + abilities.
   - Add a basic "Attack" action with AP cost.

4) Combat UI
   - Add End Turn button / input hint.
   - Show AP max, health, strain.

5) World / Verticality
   - Add climbable links, elevation restrictions.
   - Expand elevation areas to 2-3 levels.

6) Progression systems
   - Create `Mutation` resource + slot UI.
   - Add one mutation that modifies stats or grants an ability.

## Notes
- Combat movement currently uses a cooldown to prevent AP burn when holding a key.
- The player is in the `player` group for AI targeting.
- All changes are committed and pushed to origin/main.
