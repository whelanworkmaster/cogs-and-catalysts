extends Node

class_name EnemyAI

const IdleState = preload("res://scripts/ai/states/idle_state.gd")
const SeekState = preload("res://scripts/ai/states/seek_state.gd")

@export var step_distance: float = 32.0
@export var target_group: StringName = "player"
@export var start_state: StringName = "idle"

var _states: Dictionary = {}
var _current_state: AIState
@onready var _owner: Node = get_parent()

func _ready() -> void:
	_states = {
		"idle": IdleState.new(),
		"seek": SeekState.new()
	}
	set_state(start_state)
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_started)

func _process(delta: float) -> void:
	if not CombatManager:
		return
	if not CombatManager.active_combat:
		return
	if CombatManager.get_current_actor() != _owner:
		return
	if _current_state:
		_current_state.tick(_owner, delta)

func set_state(state_name: StringName) -> void:
	if _current_state:
		_current_state.exit(_owner)
	_current_state = _states.get(state_name)
	if _current_state:
		_current_state.enter(_owner)

func _on_turn_started(actor: Node) -> void:
	if actor != _owner:
		return
	if _current_state:
		_current_state.on_turn_started(_owner)

func has_player() -> bool:
	return get_player() != null

func get_player() -> Node:
	var best_target: Node = null
	var best_distance := INF
	var owner_pos := Vector3.ZERO
	if _owner and _owner is Node3D:
		owner_pos = (_owner as Node3D).global_position
	var candidates := get_players()
	for candidate in candidates:
		if candidate == null:
			continue
		if not (candidate is Node3D):
			continue
		var distance := owner_pos.distance_to((candidate as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func get_players() -> Array:
	var squad_manager := _get_squad_manager()
	if squad_manager:
		return squad_manager.get_living_vessels()
	var players: Array = []
	var group_nodes := get_tree().get_nodes_in_group(target_group)
	for node in group_nodes:
		if node == null:
			continue
		if node.has_method("get_current_hp") and node.get_current_hp() <= 0:
			continue
		players.append(node)
	return players

func _get_squad_manager() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	return tree.root.get_node_or_null("SquadManager")
