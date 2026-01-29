# Current Progress - Cogs & Catalyst

## Overall Plan (High Level)
1) Foundation (Godot 4.x)
   - Core scenes: Main, Player, World, Combat HUD.
   - Movement + elevation handling (isometric + fake Z).
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
- Deterministic combat MVP:
    - Player attack (overlap range) with AP cost and damage.
  - Enemy HP/damage/death with mutagenic cell drop + simple death tween.
    - Enemy attacks on its turn if in overlap range.
  - Combat auto-ends when only the player remains.
- Combat polish:
  - Player HP, damage feedback, and mutagenic cell pickup with UI readouts.
  - Stances (Neutral/Guard/Aggress/Evade), Disengage toggle, and reaction attacks on leaving threat range.
  - Hit feedback (flash + squash/stretch) and floating damage numbers.
- Visualized combat UI (in-world + HUD):
  - Stance ring, disengage ring, AP pips, and clocks above player.
  - Enemy threat zone ring.
  - HUD now shows player HP, last hit, stance/disengage, cells, and controls.
- FitD clocks (UI + logic):
  - Detection/Toxicity clocks displayed in HUD.
  - Detection ticks on combat start + player moves + player attacks.
  - Toxicity ticks when player takes damage and prints alarm.

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
- `scripts/ui/damage_popup.gd`
- `scripts/ui/combat_overlay.gd`
- `scripts/ui/enemy_threat_visual.gd`
- `scripts/systems/clock.gd`
- `scripts/world/mutagenic_cell.gd`
- `scenes/main.tscn`, `scenes/player.tscn`, `scenes/enemy.tscn`, `scenes/engagement_trigger.tscn`, `scenes/ui/combat_hud.tscn`

## Next Steps (Suggested Order)
1) Level challenge and encounter design (MVP)
   - Add a simple hazard tile (steam vent) that ticks Toxicity or deals damage.
   - Introduce a second enemy type or a ranged variant to force positioning.
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
- Combat movement currently uses a cooldown to prevent AP burn when holding a key.
- The player is in the `player` group for AI targeting.
- Changes since last push include combat stances, reaction attacks, overlap targeting, pickups, and in-world combat visuals.

