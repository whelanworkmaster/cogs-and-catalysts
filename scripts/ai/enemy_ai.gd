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
	return get_tree().get_first_node_in_group(target_group)
