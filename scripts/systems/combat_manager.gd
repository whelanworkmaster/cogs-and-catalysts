extends Node

signal combat_started(actors: Array)
signal combat_ended()
signal turn_started(actor: Node)
signal turn_ended(actor: Node)
signal alert_level_changed(progress: int, segments: int)
signal toxicity_load_changed(progress: int, segments: int)

var active_combat: bool = false
var actors: Array = []
var current_actor_index: int = -1

@export var move_ap_cost: int = 1
@export var attack_ap_cost: int = 3
@export var ranged_attack_ap_cost: int = 4
@export var ability_ap_cost: int = 2

const PressureSystem = preload("res://scripts/systems/pressure_system.gd")
var alert_level: PressureSystem
var toxicity_load: PressureSystem

func _ready() -> void:
	_initialize_pressure_systems()

func start_combat(combat_actors: Array) -> void:
	if active_combat:
		return
	active_combat = true
	actors = combat_actors
	current_actor_index = -1
	GameMode.set_mode(GameMode.Mode.TURN_COMBAT)
	combat_started.emit(actors)
	tick_alert_level(1)
	_next_turn()

func end_combat() -> void:
	if not active_combat:
		return
	active_combat = false
	actors = []
	current_actor_index = -1
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	combat_ended.emit()

func end_turn() -> void:
	if not active_combat or current_actor_index < 0 or current_actor_index >= actors.size():
		return
	var actor: Node = actors[current_actor_index] as Node
	turn_ended.emit(actor)
	_next_turn()

func remove_actor(actor: Node) -> void:
	var index := actors.find(actor)
	if index == -1:
		return
	actors.remove_at(index)
	if not active_combat:
		return
	if actors.size() == 1 and actors[0].is_in_group("player"):
		end_combat()
		return
	if actors.is_empty():
		end_combat()
		return
	if index < current_actor_index:
		current_actor_index -= 1
	elif index == current_actor_index:
		current_actor_index -= 1
		_next_turn()

func get_current_actor() -> Node:
	if current_actor_index < 0 or current_actor_index >= actors.size():
		return null
	return actors[current_actor_index]

func get_ap_cost(action: StringName) -> int:
	match action:
		"move":
			return move_ap_cost
		"attack":
			return attack_ap_cost
		"ranged_attack":
			return ranged_attack_ap_cost
		"ability":
			return ability_ap_cost
		_:
			return 0

func tick_alert_level(steps: int = 1) -> void:
	if not alert_level:
		return
	alert_level.tick(steps)
	alert_level_changed.emit(alert_level.progress, alert_level.segments)

func tick_toxicity_load(steps: int = 1) -> void:
	if not toxicity_load:
		return
	toxicity_load.tick(steps)
	toxicity_load_changed.emit(toxicity_load.progress, toxicity_load.segments)
	print("ALARM: Toxicity load %s/%s" % [toxicity_load.progress, toxicity_load.segments])

func _initialize_pressure_systems() -> void:
	alert_level = PressureSystem.new()
	alert_level.name = "Alert Level"
	alert_level.segments = 6
	alert_level.progress = 0
	toxicity_load = PressureSystem.new()
	toxicity_load.name = "Toxicity Load"
	toxicity_load.segments = 4
	toxicity_load.progress = 0

func _next_turn() -> void:
	if actors.is_empty():
		end_combat()
		return
	current_actor_index = (current_actor_index + 1) % actors.size()
	var actor: Node = actors[current_actor_index] as Node
	turn_started.emit(actor)
