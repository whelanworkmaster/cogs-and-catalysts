extends Node

signal combat_started(actors: Array)
signal combat_ended()
signal turn_started(actor: Node)
signal turn_ended(actor: Node)
signal alert_level_changed(progress: int, segments: int)
signal toxicity_load_changed(progress: int, segments: int)
signal alert_threshold_reached(progress: int, threshold: int)
signal toxicity_threshold_reached(progress: int, threshold: int)

var active_combat: bool = false
var actors: Array = []
var current_actor_index: int = -1
var _last_actor_switch_frame: int = -1

@export var move_ap_cost: int = 1
@export var attack_ap_cost: int = 3
@export var ranged_attack_ap_cost: int = 4
@export var ability_ap_cost: int = 2
@export var alert_thresholds: PackedInt32Array = PackedInt32Array([5, 8])
@export var toxicity_thresholds: PackedInt32Array = PackedInt32Array([2, 4])

const PressureSystem = preload("res://scripts/systems/pressure_system.gd")
var alert_level: PressureSystem
var toxicity_load: PressureSystem
var _triggered_alert_thresholds: Dictionary = {}
var _triggered_toxicity_thresholds: Dictionary = {}

func _ready() -> void:
	_initialize_pressure_systems()

func start_combat(combat_actors: Array) -> void:
	if active_combat:
		return
	active_combat = true
	actors.clear()
	for actor in combat_actors:
		if actor == null:
			continue
		if actors.has(actor):
			continue
		actors.append(actor)
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

func add_actor(actor: Node) -> void:
	if actor == null:
		return
	if actors.has(actor):
		return
	actors.append(actor)

func set_current_actor(actor: Node) -> bool:
	if not active_combat:
		return false
	if actor == null:
		return false
	var index := actors.find(actor)
	if index == -1:
		return false
	if actor.has_method("get_current_hp") and actor.get_current_hp() <= 0:
		return false
	current_actor_index = index
	return true

func can_process_actor_switch_input() -> bool:
	var frame: int = Engine.get_physics_frames()
	if _last_actor_switch_frame == frame:
		return false
	_last_actor_switch_frame = frame
	return true

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
	var removed_current := index == current_actor_index
	actors.remove_at(index)
	if not active_combat:
		return
	if _count_group_actors("player") == 0:
		end_combat()
		return
	if _count_group_actors("enemy") == 0:
		end_combat()
		return
	if actors.is_empty():
		end_combat()
		return
	if removed_current:
		current_actor_index -= 1
		_next_turn()
	elif index < current_actor_index:
		current_actor_index -= 1

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
	var previous_progress := alert_level.progress
	alert_level.tick(steps)
	alert_level_changed.emit(alert_level.progress, alert_level.segments)
	_emit_alert_thresholds(previous_progress, alert_level.progress)

func tick_toxicity_load(steps: int = 1) -> void:
	if not toxicity_load:
		return
	var previous_progress := toxicity_load.progress
	toxicity_load.tick(steps)
	toxicity_load_changed.emit(toxicity_load.progress, toxicity_load.segments)
	_emit_toxicity_thresholds(previous_progress, toxicity_load.progress)
	print("ALARM: Toxicity load %s/%s" % [toxicity_load.progress, toxicity_load.segments])

func reset_pressure_systems() -> void:
	_initialize_pressure_systems()

func get_next_alert_threshold() -> int:
	return _get_next_threshold(alert_level.progress, alert_thresholds, _triggered_alert_thresholds)

func get_next_toxicity_threshold() -> int:
	return _get_next_threshold(toxicity_load.progress, toxicity_thresholds, _triggered_toxicity_thresholds)

func describe_next_alert_effect() -> String:
	var threshold := get_next_alert_threshold()
	if threshold == 5:
		return "Next: Reinforcement wave (+1)"
	if threshold == 8:
		return "Next: Reinforcement wave (+1)"
	return "Next: Max pressure reached"

func describe_next_toxicity_effect() -> String:
	var threshold := get_next_toxicity_threshold()
	if threshold == 2:
		return "Next: Movement AP penalty"
	if threshold == 4:
		return "Next: Toxic burst damage"
	return "Next: Max toxicity reached"

func _initialize_pressure_systems() -> void:
	alert_level = PressureSystem.new()
	alert_level.name = "Alert Level"
	alert_level.segments = 8
	alert_level.progress = 0
	toxicity_load = PressureSystem.new()
	toxicity_load.name = "Toxicity Load"
	toxicity_load.segments = 4
	toxicity_load.progress = 0
	_triggered_alert_thresholds.clear()
	_triggered_toxicity_thresholds.clear()

func _next_turn() -> void:
	if actors.is_empty():
		end_combat()
		return
	var attempts := 0
	while attempts < actors.size():
		current_actor_index = (current_actor_index + 1) % actors.size()
		var actor: Node = actors[current_actor_index] as Node
		if _is_actor_turn_valid(actor):
			turn_started.emit(actor)
			return
		attempts += 1
	end_combat()

func _emit_alert_thresholds(previous_progress: int, new_progress: int) -> void:
	for threshold in alert_thresholds:
		if threshold <= previous_progress:
			continue
		if threshold > new_progress:
			continue
		if _triggered_alert_thresholds.has(threshold):
			continue
		_triggered_alert_thresholds[threshold] = true
		alert_threshold_reached.emit(new_progress, threshold)

func _emit_toxicity_thresholds(previous_progress: int, new_progress: int) -> void:
	for threshold in toxicity_thresholds:
		if threshold <= previous_progress:
			continue
		if threshold > new_progress:
			continue
		if _triggered_toxicity_thresholds.has(threshold):
			continue
		_triggered_toxicity_thresholds[threshold] = true
		toxicity_threshold_reached.emit(new_progress, threshold)

func _get_next_threshold(progress: int, thresholds: PackedInt32Array, triggered: Dictionary) -> int:
	for threshold in thresholds:
		if threshold <= progress:
			continue
		if triggered.has(threshold):
			continue
		return threshold
	return -1

func _count_group_actors(group_name: StringName) -> int:
	var count := 0
	for actor in actors:
		if actor == null:
			continue
		if not is_instance_valid(actor):
			continue
		if actor.is_queued_for_deletion():
			continue
		if not actor.is_in_group(group_name):
			continue
		if actor.has_method("get_current_hp") and actor.get_current_hp() <= 0:
			continue
		count += 1
	return count

func _is_actor_turn_valid(actor: Node) -> bool:
	if actor == null:
		return false
	if not is_instance_valid(actor):
		return false
	if actor.is_queued_for_deletion():
		return false
	if actor.has_method("get_current_hp") and actor.get_current_hp() <= 0:
		return false
	return true
