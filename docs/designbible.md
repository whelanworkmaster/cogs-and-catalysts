# ---

**📄 GDD One-Pager: *Project Cogs & Catalyst***

**Genre:** Single-Character Isometric CRPG

**Setting:** Alchemical Noir (Dark Fantasy / Biopunk)

**Core Loop:** Exploration Tactical Combat Biological Augmentation

## ---

**1\. High-Level Vision**

In a rain-slicked metropolis ruled by the **Iron Censorate** (a fascist alchemical state), you play a "Fixer" navigating a web of warring political factions. You are a "Vessel"—a mercenary who illegally modifies their own biology with volatile mutagens to survive impossible odds. The game eschews "trash mob" grinding and stealth-skipping in favor of high-impact, tactical combat encounters.

## **2\. Core Gameplay Pillars**

### **A. Narrative Exploration (Real-Time)**

* **The World:** A modular, "Z-axis" focused city built on Godot’s TileMap/GridMap system.  
* **Parkour Navigation:** Movement isn't flat. Players use biological upgrades (Hydraulic Legs, Grappling Tendrils) to find vertical shortcuts and hidden caches.  
* **Interaction:** A robust system for environmental storytelling (Data Slates, Alchemical Residue) and faction-based quest gating.

### **B. Tactical Combat (Turn-Based)**

* **The Combat Bubble:** Transitions from real-time exploration to a grid-based tactical layer upon engagement.  
* **Action Point (AP) Economy:** A deterministic system where every move—climbing, attacking, or venting toxicity—costs AP.  
* **Environmental Engineering:** Combat is won by manipulating the terrain (igniting oil spills, breaking steam pipes, knocking enemies off ledges).

### **C. Biological Architecture (Progression)**

* **The "Internal Rig":** Instead of traditional levels, players have limited "Organ Slots" (Nervous System, Ocular, Muscular, etc.).  
* **Mutagenic Heists:** Power is earned by stealing "Master Mutagens" from high-security labs.  
* **Toxicity Management:** A risk/reward system where over-using abilities builds "Body Strain," leading to unpredictable debuffs or "Glitch" turns.

## ---

**3\. The Political Landscape**

Players balance their reputation between three primary ideologies, affecting available upgrades and world state:

1. **The Iron Censorate (State):** The "Antagonistic Force." High-tech, armored, and oppressive.  
2. **The Commonweal (Leftist/Collectivist):** Focused on resilience and area-of-effect mutations.  
3. **The Free-Strider Syndicate (Libertarian):** Focused on high-damage, high-risk "glass cannon" upgrades.

## ---

**4\. Technical Stack (Godot Engine)**

* **Movement:** 8-way Isometric with a custom Z-axis handler for verticality.  
* **Data:** JSON or Custom Resources to define Mutations, Enemy Stats, and Item Attributes.  
* **AI:** Role-based State Machines (Strikers, Bulks, Alchemists) that prioritize environmental hazards.  
* **UI:** A modular bottom-row Hotbar that dynamically updates based on currently "installed" biological organs.

## ---

**5\. MVP (Minimum Viable Product) Goal**

**The "Mercury Vault" Heist:**

* Build one functional city block with verticality.  
* Implement the transition from Real-Time movement to Turn-Based combat.  
* Create one Boss Encounter (The Censor-Overseer) featuring environmental interactions.  
* Implement a basic "Inventory" UI where one Mutagen can be "slotted" to change player stats.
