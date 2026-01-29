extends Node

signal combat_started(actors: Array)
signal combat_ended()
signal turn_started(actor: Node)
signal turn_ended(actor: Node)
signal detection_clock_ticked(progress: int, segments: int)
signal toxicity_clock_ticked(progress: int, segments: int)

var active_combat: bool = false
var actors: Array = []
var current_actor_index: int = -1

@export var move_ap_cost: int = 1
@export var attack_ap_cost: int = 3
@export var ability_ap_cost: int = 2

const Clock = preload("res://scripts/systems/clock.gd")
var detection_clock: Clock
var toxicity_clock: Clock

func _ready() -> void:
	_initialize_clocks()

func start_combat(combat_actors: Array) -> void:
	if active_combat:
		return
	active_combat = true
	actors = combat_actors
	current_actor_index = -1
	GameMode.set_mode(GameMode.Mode.TURN_COMBAT)
	combat_started.emit(actors)
	tick_detection(1)
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
		"ability":
			return ability_ap_cost
		_:
			return 0

func tick_detection(steps: int = 1) -> void:
	if not detection_clock:
		return
	detection_clock.tick(steps)
	detection_clock_ticked.emit(detection_clock.progress, detection_clock.segments)

func tick_toxicity(steps: int = 1) -> void:
	if not toxicity_clock:
		return
	toxicity_clock.tick(steps)
	toxicity_clock_ticked.emit(toxicity_clock.progress, toxicity_clock.segments)
	print("ALARM: Toxicity clock %s/%s" % [toxicity_clock.progress, toxicity_clock.segments])

func _initialize_clocks() -> void:
	detection_clock = Clock.new()
	detection_clock.name = "Detection"
	detection_clock.segments = 6
	detection_clock.progress = 0
	toxicity_clock = Clock.new()
	toxicity_clock.name = "Toxicity"
	toxicity_clock.segments = 4
	toxicity_clock.progress = 0

func _next_turn() -> void:
	if actors.is_empty():
		end_combat()
		return
	current_actor_index = (current_actor_index + 1) % actors.size()
	var actor: Node = actors[current_actor_index] as Node
	turn_started.emit(actor)
