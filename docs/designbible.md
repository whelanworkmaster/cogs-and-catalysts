# Design Bible - Cogs & Catalyst

## Direction Shift (2026-02-06)
This project is no longer targeting a CRPG structure or any adaptation of existing tabletop RPG rule sets.

The game direction is now:
- A unique tactical roguelike with short, high-stakes operations.
- XCOM-like positional combat, but with original systems and terminology.
- Minimal narrative overhead during missions; strategy comes from terrain, hazards, and build choices.

## High-Level Vision
You command a small strike unit of modified operatives ("Vessels") in an alchemical-industrial city under authoritarian control. Each operation is a tactical incursion into hostile districts where survival, extraction, and adaptation matter more than linear story progression.

The identity is:
- System-first tactical gameplay.
- Deterministic and readable combat outcomes.
- Build expression through biotech loadouts, not class archetypes from existing games.

## Core Gameplay Pillars
### 1) Tactical Encounters First
- Turn-based, grid-based combat is the center of the experience.
- Encounters are compact and dangerous; positioning and AP efficiency decide outcomes.
- Environmental control is a primary strategy layer (steam, pressure lines, elevation, cover lanes).

### 2) Roguelike Campaign Structure
- Campaign is run-based: multiple tactical nodes per run, escalating pressure, then extraction or defeat.
- Persistent meta-unlocks provide new tools and options, not guaranteed power creep.
- Failure is expected and informative; runs should generate new tactical decisions rather than scripted repetition.

### 3) Biological Buildcraft
- Units equip mutagenic modules in limited organ slots.
- Modules alter actions, reactions, and turn economy.
- Toxicity/Strain is a core cost system that pushes risk-reward decisions every encounter.

### 4) Pressure Tracks and Response Timers
- Mission pressure systems (Alert Level, Enemy Response Timer, Objective Breach Timer, Toxicity Load) drive tempo.
- Player actions advance pressure tracks or timers; thresholds change enemy behavior and map conditions.
- Missions should end with urgent extraction decisions, not full-map cleanup.

## Design Principles (Non-Tabletop)
- No direct import of D20/FitD/PbtA or other tabletop mechanics/rule language.
- No "to-hit roll" dependency as baseline; prioritize deterministic resolution with explicit modifiers.
- Prefer bespoke mechanics built for digital clarity, fast turns, and strong UI readability.
- Every system must answer: "Does this create better tactical decisions in 1-3 turns?"

## World and Tone
- Alchemical noir + biopunk remains the aesthetic anchor.
- Factions exist to shape enemy behaviors, mission modifiers, and upgrade access.
- Narrative is delivered through mission context and post-run consequences, not long CRPG dialogue trees.

## Technical Approach (Godot 4.x)
- 3D grid combat spaces with orthographic tactical camera.
- Data-driven definitions for units, modules, abilities, hazards, and encounter templates.
- Role-based enemy AI with clear battlefield jobs (pressure, anchor, disruptor, support).
- UI emphasis on telegraphing AP costs, threat ranges, pressure state, and extraction state.

## Current Product Goals
### Immediate Goals
- Lock tactical-combat-first identity across code and docs.
- Build one fully playable run loop: deploy -> 2-3 encounters -> extraction -> results.
- Support a 2-4 Vessel squad baseline (not single-character CRPG flow).

### Mid-Term Goals
- Introduce distinct enemy roles and reinforcement behaviors.
- Expand hazard interactions into repeatable tactical verbs.
- Add progression that unlocks modules, squad options, and mission modifiers.

### MVP Goal ("Mercury Vault" Reframed)
Deliver a vertical slice proving the new direction:
- Squad deployment into one tactical district.
- Deterministic AP combat with hazards, pressure tracks/timers, and reinforcement pressure.
- Mid-mission objective pivot (vault breach or data steal) with extraction race.
- End-of-run resolution with unlock/progression choices for next run.
